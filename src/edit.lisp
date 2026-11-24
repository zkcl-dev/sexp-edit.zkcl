(in-package #:zk-sexp-edit)

(defun directional-edit (source anchor head direction forward backward)
  (zk-syntax:structural-edit
   source anchor head
   (ecase direction (:forward forward) (:backward backward))))

(defun wrap (source anchor &key (head anchor))
  "Create an edit surrounding whole forms selected by ANCHOR and HEAD with a list."
  (zk-syntax:structural-edit source anchor head :wrap))

(defun splice (source anchor &key (head anchor))
  "Create an edit removing the selected enclosing group's delimiters."
  (zk-syntax:structural-edit source anchor head :splice))

(defun raise (source anchor &key (head anchor))
  "Create an edit replacing the enclosing form with the selected whole forms."
  (zk-syntax:structural-edit source anchor head :raise))

(defun slurp (source anchor &key (head anchor) (direction :forward))
  "Return an edit pulling the next form into the group, or the previous form with :BACKWARD."
  (directional-edit source anchor head direction :slurp-forward :slurp-backward))

(defun barf (source anchor &key (head anchor) (direction :forward))
  "Return an edit moving the last form out of the group, or the first with :BACKWARD."
  (directional-edit source anchor head direction :barf-forward :barf-backward))

(defun split (source anchor &key (head anchor))
  "Create an edit splitting a group at a caret between its elements."
  (zk-syntax:structural-edit source anchor head :split))

(defun join (source anchor &key (head anchor) (direction :forward))
  "Create an edit joining adjacent compatible groups in DIRECTION."
  (directional-edit source anchor head direction :join-forward :join-backward))

(defun transpose (source anchor &key (head anchor) (direction :forward))
  "Create an edit swapping selected whole forms with their adjacent sibling."
  (directional-edit source anchor head direction :transpose-forward :transpose-backward))

(defun delete-forward (source anchor &key (head anchor))
  "Create an edit deleting the selected text or the next safe source unit."
  (zk-syntax:structural-edit source anchor head :delete-forward))

(defun delete-backward (source anchor &key (head anchor))
  "Create an edit deleting the selected text or the previous safe source unit."
  (zk-syntax:structural-edit source anchor head :delete-backward))

(defun insert-delimiter (source anchor delimiter &key (head anchor))
  "Return an edit for typing a parenthesis or double quote at ANCHOR.
This can insert a pair, wrap a selection, or move past a closing delimiter."
  (zk-syntax:insert-delimiter source anchor head delimiter))

(defun indent (source anchor &key (head anchor))
  "Indent the lines touched by the selection without changing their contents.
At a caret, indent just that line. Return an edit with the mapped selection."
  (zk-syntax:structural-edit source anchor head :indent))

(defun infer-parens (source anchor &key (head anchor))
  "Recompute end-of-line closing parentheses from SOURCE's indentation.
Return one edit for the whole document, with ANCHOR and HEAD mapped through it."
  (zk-syntax:structural-edit source anchor head :infer-parens))

(defun forward-form (source offset)
  "Return the end of the current or next form on this level, or NIL."
  (zk-syntax:move-cursor source offset :forward-form))

(defun backward-form (source offset)
  "Return the start of the current or previous form on this level, or NIL."
  (zk-syntax:move-cursor source offset :backward-form))

(defun up-list (source offset &key (direction :forward))
  "Return the position just outside the enclosing list or vector, or NIL."
  (zk-syntax:move-cursor source offset
                        (ecase direction
                          (:forward :up-list)
                          (:backward :backward-up-list))))

(defun down-list (source offset)
  "Return the position just inside the next opener on this level, or NIL."
  (zk-syntax:move-cursor source offset :down-list))

(defun apply-edit (edit &optional (current-source nil source-p))
  "Return the edited text, anchor, and head from EDIT.
When CURRENT-SOURCE is supplied, require it to be the edit's original snapshot."
  (when (and source-p (not (zk-syntax:snapshot-equal-p current-source (edit-source edit))))
    (error 'edit-error :reason :stale-snapshot
           :message "The edit belongs to a different source snapshot."))
  (let ((text (zk-syntax:apply-edit edit)))
    (multiple-value-bind (anchor head) (edit-selection edit)
      (values text anchor head))))

(defun edit-text (command text-or-source anchor &rest arguments)
  "Pass a snapshot, ANCHOR, and ARGUMENTS to COMMAND.
TEXT-OR-SOURCE may be a string or an existing source snapshot. COMMAND must
return an edit of that snapshot. Return the edited text, anchor, and head.
Positions are zero-based UTF-8 byte offsets."
  (let ((source (etypecase text-or-source
                  (string (zk-syntax:parse-source text-or-source))
                  ((satisfies zk-syntax:snapshotp) text-or-source))))
    (apply-edit (apply command source anchor arguments) source)))

(defun apply-edit-to-document (workspace name edit)
  "Apply EDIT to document NAME and return the updated source, anchor, and head.
Signal EDIT-ERROR if the document is missing or its source differs from EDIT's."
  (let ((source (zk-syntax:apply-edit-to-document workspace name edit)))
    (multiple-value-bind (anchor head) (edit-selection edit)
      (values source anchor head))))

(defun source-form-p (node)
  (member (zk-syntax:kind node)
          '(:list :vector :reader-form :atom :string :raw-string :character)))

(defun promote-reader-prefixes (node)
  (loop for enclosing = (zk-syntax:parent node)
        while (and enclosing
                   (eq :reader-form (zk-syntax:kind enclosing))
                   (zk-syntax:node-equal-p
                    node (car (last (zk-syntax:forms enclosing)))))
        do (setq node enclosing)
        finally (return node)))

(defun form-from-node (node)
  (when node
    (case (zk-syntax:kind node)
      ((:whitespace :line-comment :block-comment :dot :error :unknown-dispatch)
       nil)
      (otherwise
       (loop for candidate = node then (zk-syntax:parent candidate)
             while candidate
             when (source-form-p candidate)
               return (promote-reader-prefixes candidate))))))

(defun form-at (source offset)
  "Return the local form at UTF-8 byte OFFSET, or NIL in trivia or errors.
At token boundaries the token on the right wins; EOF uses the last token.
A delimiter identifies its own group. Immediate reader wrappers belong to
that form; promotion stops at a list or vector."
  (form-from-node (zk-syntax:node-at source offset)))

(defun delete-form (source offset)
  "Create an edit deleting the entire local form at OFFSET, as chosen by FORM-AT.
Includes immediate reader prefixes and leaves adjacent trivia in place.
Signal EDIT-ERROR if there is no local form or the deletion is unsafe."
  (let ((form (or (form-at source offset)
                  (error 'edit-error :reason :no-form
                         :message "There is no source form at this position."))))
    (multiple-value-bind (start end) (zk-syntax:range form)
      (delete-forward source start :head end))))

(defun directed-range (start end anchor head)
  (if (> anchor head) (values end start) (values start end)))

(defun selection-start (source anchor head)
  (let* ((low (min anchor head))
         (high (max anchor head))
         (node (zk-syntax:node-at source low)))
    (unless (= low high) (zk-syntax:node-at source high))
    (values node low high)))

(defun select-form (source anchor &key (head anchor))
  "Return the directed selection of the smallest form enclosing both endpoints.
Return NIL, NIL if the lower endpoint has no local form or no form encloses both."
  (multiple-value-bind (token low high) (selection-start source anchor head)
    (loop for node = (form-from-node token) then (zk-syntax:parent node)
          while node do
            (multiple-value-bind (start end) (zk-syntax:range node)
              (when (and (source-form-p node) (<= start low) (<= high end))
                (return-from select-form (directed-range start end anchor head))))))
  (values nil nil))

(defun expand-selection (source anchor &key (head anchor))
  "Grow the selection to the next enclosing syntax range, preserving direction.
At a caret select the local form or token. The outermost range is the whole source."
  (multiple-value-bind (token low high) (selection-start source anchor head)
    (let ((form (when (= low high) (form-from-node token))))
      (when form (return-from expand-selection (zk-syntax:range form))))
    (loop for node = token then (zk-syntax:parent node)
          while node do
            (multiple-value-bind (start end) (zk-syntax:range node)
              (when (and (<= start low) (<= high end)
                         (or (< start low) (< high end)))
                (return-from expand-selection (directed-range start end anchor head))))))
  (values anchor head))
