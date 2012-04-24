;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;                                                                  ;;;
;;; Confidential and proprietary information of ITA Software, Inc.   ;;;
;;;                                                                  ;;;
;;; Copyright (c) 2012 ITA Software, Inc.  All rights reserved.      ;;;
;;;                                                                  ;;;
;;; Original author: Scott McKay                                     ;;;
;;;                                                                  ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package "PROTO-IMPL")


;;; Can a version of a Protobufs schema be upgraded to a new version

(defgeneric protobuf-upgradable (old new &optional old-parent new-parent)
  (:documentation
   "Returns true if and only if the old protobuf schema can be upgraded to
    the new schema.
    'old' is the old object (schema, enum, message, etc), 'new' is the new one.
    'old-parent' is the \"parent\" of 'old', 'new-parent' is the parent of 'new'.
    If the schema is not upgradable, the second value is a list of warnings."))

(defvar *upgrade-warnings*)
(defmacro upgrade-warn ((predicate old new) format-string &optional name)
  "Collect an upgrade warning into *upgrade-warnings*."
  (with-gensyms (vold vnew)
    `(let* ((,vold ,old)
            (,vnew ,new))
       (cond ((,predicate ,vold ,vnew)
              t)
             (t
              ;; Note that this returns the non-NIL value of *upgrade-warnings*,
              ;; so the upgradable check will continue to collect warnings
              (push (format nil ,format-string
                            ,@(if name (list name vold vnew) (list vold vnew)))
                    *upgrade-warnings*))))))

(defmethod protobuf-upgradable ((old protobuf) (new protobuf)
                                &optional old-parent new-parent)
  (declare (ignore old-parent new-parent))
  (let ((*upgrade-warnings* ()))
    (and
     ;; Are they named the same?
     (upgrade-warn (string= (proto-name old) (proto-name new))
                   "Protobuf schema name changed from '~A' to '~A'")
     (upgrade-warn (string= (proto-package old) (proto-package new))
                   "Protobuf schema package changed from '~A' to '~A'")
     ;; Is every enum in 'old' upgradable to an enum in 'new'?
     (loop for old-enum in (proto-enums old)
           as new-enum = (find (proto-name old-enum) (proto-enums new)
                               :key #'proto-name :test #'string=)
           always (and new-enum (protobuf-upgradable old-enum new-enum old new)))
     ;; Is every message in 'old' upgradable to a message in 'new'?
     (loop for old-msg in (proto-messages old)
           as new-msg = (find (proto-name old-msg) (proto-messages new)
                              :key #'proto-name :test #'string=)
           always (and new-msg (protobuf-upgradable old-msg new-msg old new)))
     ;; Is every service in 'old' upgradable to a service in 'new'?
     (loop for old-svc in (proto-services old)
           as new-svc = (find (proto-name old-svc) (proto-services new)
                              :key #'proto-name :test #'string=)
           always (and new-svc (protobuf-upgradable old-svc new-svc old new))))
    (values (null *upgrade-warnings*) (nreverse *upgrade-warnings*))))


(defmethod protobuf-upgradable ((old protobuf-enum) (new protobuf-enum)
                                &optional old-parent new-parent)
  (declare (ignore old-parent new-parent))
  ;; No need to check that the names are equal, our caller did that already
  (loop for old-val in (proto-values old)
        as new-val = (find (proto-name old-val) (proto-values new)
                           :key #'proto-name :test #'string=)
        always (and new-val (protobuf-upgradable old-val new-val old new))))

(defmethod protobuf-upgradable ((old protobuf-enum-value) (new protobuf-enum-value)
                                &optional old-enum new-enum)
  (declare (ignore new-enum))
  ;; No need to check that the names are equal, our caller did that already
  ;; Do they have the same index?
  (upgrade-warn (= (proto-index old) (proto-index new))
                "Enum index for '~A' changed from ~D to ~D"
                (format nil "~A.~A" (proto-name old-enum) (proto-name old))))


(defmethod protobuf-upgradable ((old protobuf-message) (new protobuf-message)
                                &optional old-parent new-parent)
  (declare (ignore old-parent new-parent))
  ;; No need to check that the names are equal, our caller did that already
  (and
   ;; Is every enum in 'old' upgradable to an enum in 'new'?
   (loop for old-enum in (proto-enums old)
         as new-enum = (find (proto-name old-enum) (proto-enums new)
                             :key #'proto-name :test #'string=)
         always (and new-enum (protobuf-upgradable old-enum new-enum old new)))
   ;; Is every message in 'old' upgradable to a message in 'new'?
   (loop for old-msg in (proto-messages old)
         as new-msg = (find (proto-name old-msg) (proto-messages new)
                            :key #'proto-name :test #'string=)
         always (and new-msg (protobuf-upgradable old-msg new-msg old new)))
   ;; Is every required field in 'old' upgradable to a field in 'new'?
   ;; (Optional fields are safe to remove)
   (loop for old-fld in (proto-fields old)
         as new-fld = (find (proto-name old-fld) (proto-fields new)
                            :key #'proto-name :test #'string=)
         always (if new-fld
                  (protobuf-upgradable old-fld new-fld old new)
                  ;; If there's no new field, the old one must not be required
                  (or (member (proto-required old-fld) '(:optional :repeated))
                      (push (format nil "Old field '~A.~A' was required, and is now missing"
                                    (proto-name old) (proto-name old-fld))
                            *upgrade-warnings*))))))

(defmethod protobuf-upgradable ((old protobuf-field) (new protobuf-field)
                                &optional old-message new-message)
  (flet ((arity-upgradable (old-arity new-arity)
           (or (eq old-arity new-arity)
               (not (eq new-arity :required))
               ;; Optional fields and extensions are compatible
               (and (eq old-arity :optional)
                    (index-within-extensions-p (proto-index new) new-message))
               (and (eq new-arity :optional)
                    (index-within-extensions-p (proto-index old) old-message))))
         (type-upgradable (old-type new-type)
           ;;--- Handle conversions between embedded messages and bytes
           (or
            (string= old-type new-type)
            ;; These varint types are all compatible
            (and (member old-type '("int32" "uint32" "int64" "uint64" "bool") :test #'string=)
                 (member new-type '("int32" "uint32" "int64" "uint64" "bool") :test #'string=))
            ;; The two signed integer types are compatible
            (and (member old-type '("sint32" "sint64") :test #'string=)
                 (member new-type '("sint32" "sint64") :test #'string=))
            ;; Fixed integers are compatible with each other
            (and (member old-type '("fixed32" "sfixed32") :test #'string=)
                 (member new-type '("fixed32" "sfixed32") :test #'string=))
            (and (member old-type '("fixed64" "sfixed64") :test #'string=)
                 (member new-type '("fixed64" "sfixed64") :test #'string=))
            ;; Strings and bytes are compatible, assuming UTF-8 encoding
            (and (member old-type '("string" "bytes") :test #'string=)
                 (member new-type '("string" "bytes") :test #'string=))))
         (default-upgradable (old-default new-default)
           (declare (ignore old-default new-default))
           t))
    ;; No need to check that the names are equal, our caller did that already
    (and
     ;; Do they have the same index?
     (upgrade-warn (= (proto-index old) (proto-index new))
                   "Field index for '~A' changed from ~D to ~D"
                   (format nil "~A.~A" (proto-name old-message) (proto-name old)))
     ;; Are the arity and type upgradable?
     (upgrade-warn (arity-upgradable (proto-required old) (proto-required new))
                   "Arity of ~A, ~S, is not upgradable to ~S"
                   (format nil  "~A.~A" (proto-name old-message) (proto-name old)))
     (upgrade-warn (type-upgradable (proto-type old) (proto-type new))
                   "Type of '~A', ~A, is not upgradable to ~A"
                   (format nil  "~A.~A" (proto-name old-message) (proto-name old))))))


(defmethod protobuf-upgradable ((old protobuf-service) (new protobuf-service)
                                &optional old-parent new-parent)
  (declare (ignore old-parent new-parent))
  ;; No need to check that the names are equal, our caller did that already
  ;; Is every method in 'old' upgradable to a method in 'new'?
  (loop for old-method in (proto-methods old)
        as new-method = (find (proto-name old-method) (proto-methods new)
                              :key #'proto-name :test #'string=)
        always (and new-method (protobuf-upgradable old-method new-method old new))))

(defmethod protobuf-upgradable ((old protobuf-method) (new protobuf-method)
                                &optional old-service new-service)
  (declare (ignore new-service))
  ;; No need to check that the names are equal, our caller did that already
  (and
   ;; Are their inputs and outputs the same?
   (upgrade-warn (string= (proto-input-name old) (proto-input-name new))
                 "Input type for ~A, ~A, is not upgradable to ~A"
                 (format nil  "~A.~A" (proto-name old-service) (proto-name old)))
   (upgrade-warn (string= (proto-output-name old) (proto-output-name new))
                 "Output type for ~A, ~A, is not upgradable to ~A"
                 (format nil  "~A.~A" (proto-name old-service) (proto-name old)))))
