(eval-when (:compile-toplevel :load-toplevel :execute)
  (require :zk-syntax))

(defpackage #:zk-sexp-edit
  (:use #:cl)
  (:import-from #:zk-syntax #:make-edit #:editp #:edit-source #:edit-changes #:edit-selection
                #:edit-error #:edit-error-reason #:edit-error-message)
  (:export #:wrap #:splice #:raise #:slurp #:barf #:split #:join #:transpose
           #:delete-forward #:delete-backward #:delete-form #:insert-delimiter #:indent #:infer-parens
           #:forward-form #:backward-form #:up-list #:down-list
           #:make-edit #:editp #:edit-source #:edit-changes #:edit-selection
           #:edit-error #:edit-error-reason #:edit-error-message
           #:edit-text #:apply-edit #:apply-edit-to-document
           #:form-at #:select-form #:expand-selection))
