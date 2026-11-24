(asdf:defsystem "zk-sexp-edit"
  :description "Structural editing for Lisp source"
  :version "0.1.0"
  :license "Apache-2.0"
  :depends-on ("zk-syntax")
  :serial t
  :components ((:file "src/package") (:file "src/edit"))
  :in-order-to ((asdf:test-op (asdf:test-op "zk-sexp-edit/tests"))))

(asdf:defsystem "zk-sexp-edit/tests"
  :depends-on ("zk-sexp-edit" "zk-test")
  :components ((:file "tests/suite"))
  :perform (asdf:test-op (operation component)
             (declare (ignore operation component))
             (uiop:symbol-call :zk-test :check
                               (uiop:find-symbol* :all :zk-sexp-edit.tests))))
