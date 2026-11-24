# sexp-edit.zkcl

A library for structural editing of Lisp source, using zkcl's `zk-syntax` parser.

## Try it

Start a zkcl REPL from this checkout.

```lisp
(require :asdf)
(asdf:load-asd (truename "zk-sexp-edit.asd"))
(asdf:load-system "zk-sexp-edit")

(multiple-value-list
 (zk-sexp-edit:edit-text #'zk-sexp-edit:slurp "(a b) c" 3))
;; => ("(a b c)" 3 3)
```

`edit-text` accepts a string or a parsed source snapshot, calls an editing
command, and returns the new text, anchor, and head as three values. Pass a
snapshot to reuse its parse and initial readtable across commands.

## Project dependency

Add this to `zkcl.sexp`, then run `zkcl lock`.

```lisp
(dependency "sexp-edit" (module "zk/sexp-edit")
  (git "https://github.com/zkcl-dev/sexp-edit.zkcl.git")
  (rev "<commit>"))
```

For a local checkout, replace the `git` and `rev` forms with `(path "../sexp-edit.zkcl")`.

## Commands

| Task | Functions in `zk-sexp-edit` |
| --- | --- |
| Change forms | `wrap`, `splice`, `raise`, `slurp`, `barf`, `split`, `join`, `transpose` |
| Type or delete | `insert-delimiter`, `delete-forward`, `delete-backward`, `delete-form` |
| Move | `forward-form`, `backward-form`, `up-list`, `down-list` |
| Find or select | `form-at`, `select-form`, `expand-selection` |
| Fix layout | `indent` adjusts indentation; `infer-parens` uses indentation to set closing parens |

For example, `(zk-sexp-edit:slurp source anchor :head head)` returns an edit.
`anchor` is the fixed end of the selection and `head` is the moving end. Omit
`:head` for a caret. `slurp`, `barf`, `join`, `transpose`, and `up-list` accept
`:direction :backward` and default to `:forward`.

Positions are zero-based **UTF-8 byte offsets**. Convert Lisp string indices
with `zk-syntax:byte-offset` and `zk-syntax:character-index`.

`delete-form` takes a source and caret offset. It removes the same local form
that `form-at` identifies, including immediate reader prefixes. Use
`delete-forward` with `:head` to delete an explicit selection.

```lisp
(zk-sexp-edit:edit-text #'zk-sexp-edit:delete-form "'雪 tail" 1)
;; returns " tail", 0, 0
```

## Editor integration

Call `zk-syntax:parse-source` on the current buffer and reuse the resulting
source for commands and queries. Pass `:readtable` there if you need to set the
initial readtable.

- `edit-changes` gives `(start end replacement)` triples in the original source.
  Check the buffer revision and apply the half-open ranges as one undo step.
  Apply them from right to left if your buffer takes one range at a time.
- `edit-selection` gives the new anchor and head. An edit can move the caret
  with an empty change list.
- `apply-edit` returns the new string, anchor, and head. Pass the current
  snapshot as its second argument to reject edits from a different revision.
  For a `zk-syntax` workspace, `apply-edit-to-document` checks the source
  identity and returns the updated source, anchor, and head.
- Use `edit-error-reason` and `edit-error-message` to report a refused edit.
  A snapshot identity check can signal `:stale-snapshot`, even if two separate
  snapshots contain the same text.

Use `make-edit` to build the same kind of edit from a custom command. Supply
changes in source order and the selection in the resulting text.

## Tests

Run `zkcl test` from this checkout.
