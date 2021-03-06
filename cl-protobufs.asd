;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;                                                                  ;;;
;;; Free Software published under an MIT-like license. See LICENSE   ;;;
;;;                                                                  ;;;
;;; Copyright (c) 2012 Google, Inc.  All rights reserved.            ;;;
;;;                                                                  ;;;
;;; Original author: Scott McKay                                     ;;;
;;;                                                                  ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :asdf)

(asdf:defsystem "cl-protobufs"
  :name "CL Protobufs"
  :author "Scott McKay"
  :version "1.0"
  :licence "MIT-style"
  :maintainer ("Scott McKay")
  :description "Protobufs for Common Lisp"
  :long-description "Protobufs for Common Lisp"
  :depends-on ("closer-mop" "babel" "trivial-garbage" (:version "asdf" "3.0.1"))
  :serial t
  :components
    ((:module "packages"
              :serial t
              :pathname #p""
              :components
               ((:file "pkgdcl")))
     (:module "models"
              :serial t
              :pathname #p""
              :depends-on ("packages")
              :components
                ((:file "utilities")
                 (:file "model-classes")
                 (:file "conditions")))
     (:module "parsing"
              :serial t
              :pathname #p""
              :depends-on ("models")
              :components
                ((:file "parser")
                 (:file "printer")))
     (:module "schema"
              :serial t
              :pathname #p""
              :depends-on ("models")
              :components
                ((:file "define-proto")
                 (:file "upgradable")
                 (:file "clos-transform")))
     (:module "serialization"
              :serial t
              :pathname #p""
              :depends-on ("models")
              :components
                ((:file "text-format")
                 (:file "wire-format")
                 (:file "serialize")))
     (:module "misc"
              :serial t
              :pathname #p""
              :depends-on ("models" "parsing" "schema" "serialization")
              :components
                ((:file "api")
                 (:file "asdf-support")
                 (:file "examples"))))
    :in-order-to ((test-op (test-op "cl-protobufs-tests"))))
