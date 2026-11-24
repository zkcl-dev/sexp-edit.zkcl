(project "zk/sexp-edit"
  (version "0.1.0")
  (license "Apache-2.0")
  (packages "ZK-SEXP-EDIT")
  (library (files "src/package.lisp" "src/edit.lisp"))
  (test (files "tests/suite.lisp") (suite "ZK-SEXP-EDIT.TESTS:ALL"))
  (asdf-alias "zk-sexp-edit" (version "0.1.0"))
  (include "LICENSE" "README.md" "zk-sexp-edit.asd" "src/package.lisp" "src/edit.lisp"
           "tests/suite.lisp"))
