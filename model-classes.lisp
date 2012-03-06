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


;;; Protol buffers model classes

;; The protobuf, corresponds to one .proto file
(defclass protobuf ()
  ((name :type (or null string)                 ;the name of this .proto file
         :reader proto-name
         :initarg :name
         :initform nil)
   (package :type (or null string)              ;the package
            :reader proto-package
            :initarg :package
            :initform nil)
   (imports :type (list-of string)              ;any imports
            :reader proto-imports
            :initarg :imports
            :initform ())
   (syntax :type (or null string)               ;syntax, passed on but otherwise ignored
           :reader proto-syntax
           :initarg :syntax
           :initform nil)
   (options :type (list-of string)              ;options, passed on but otherwise ignored
           :reader proto-options
           :initarg :options
           :initform ())
   (messages :type (list-of protobuf-message)   ;the set of messages
             :accessor proto-messages
             :initarg :messages
             :initform ())
   (enums :type (list-of protobuf-enum)         ;the set of enum types
          :accessor proto-enums
          :initarg :enums
          :initform ())
   (services :type (list-of protobuf-service)
             :accessor proto-services
             :initarg :services
             :initform ())))

(defmethod print-object ((p protobuf) stream)
  (print-unprintable-object (p stream :type t :identity t)
    (format stream "~@[~A~]~@[ (package ~A)~]"
            (proto-name p) (proto-package p))))

(defmethod find-message-for-class ((protobuf protobuf) (class symbol))
  (or (find class (proto-messages protobuf) :key #'proto-class)
      (some #'(lambda (msg) (find-message-for-class msg class)) (proto-messages protobuf))))

(defmethod find-message-for-class ((protobuf protobuf) (class class))
  (find-message-for-class protobuf (class-name class)))

(defmethod find-enum-for-type ((protobuf protobuf) type)
  (or (find type (proto-enums protobuf) :key #'proto-class)
      (some #'(lambda (msg) (find-enum-for-type msg type)) (proto-messages protobuf))))


;; A protobuf message
(defclass protobuf-message ()
  ((name :type string                           ;the Protobuf name for the message
         :reader proto-name
         :initarg :name)
   (class :type (or null symbol)                ;the Lisp class it represents
          :accessor proto-class
          :initarg :class
          :initform nil)
   (fields :type (list-of protobuf-field)       ;the fields
           :accessor proto-fields
           :initarg :fields
           :initform ())
   (messages :type (list-of protobuf-message)   ;the embedded messages
             :accessor proto-messages
             :initarg :messages
             :initform ())
   (enums :type (list-of protobuf-enum)         ;the embedded enum types
          :accessor proto-enums
          :initarg :enums
          :initform ())
   (comment :type (or null string)
            :accessor proto-comment
            :initarg :comment
            :initform nil)))

(defmethod print-object ((m protobuf-message) stream)
  (print-unprintable-object (m stream :type t :identity t)
    (format stream "~A~@[ (~S)~]"
            (proto-name m) (proto-class m))))

(defmethod find-message-for-class ((message protobuf-message) (class symbol))
  (find class (proto-messages message) :key #'proto-class))

(defmethod find-message-for-class ((message protobuf-message) (class class))
  (find-message-for-class message (class-name class)))

(defmethod find-enum-for-type ((message protobuf-message) type)
  (find type (proto-enums message) :key #'proto-class))


;; A protobuf field within a message
(defclass protobuf-field ()
  ((name :type string                           ;the Protobuf name for the field
         :accessor proto-name
         :initarg :name)
   (type :type string                           ;the name of the Protobuf type for the field
         :accessor proto-type
         :initarg :type)
   (class :type (or null symbol)                ;the Lisp class (or a keyword such as :fixed64)
          :accessor proto-class
          :initarg :class
          :initform nil)
   (required :type (member :required :optional :repeated)
             :accessor proto-required
             :initarg :required)
   (index :type (integer 1 #.(1- (ash 1 32)))   ;the index number for this field
          :accessor proto-index
          :initarg :index)
   (value :type (or null symbol)                ;the Lisp slot holding the value within an object
          :accessor proto-value
          :initarg :value
          :initform nil)
   (default :type (or null string)
            :accessor proto-default
            :initarg :default
            :initform nil)
   (packed :type (member t nil)
           :accessor proto-packed
           :initarg :packed
           :initform nil)
   (comment :type (or null string)
            :accessor proto-comment
            :initarg :comment
            :initform nil)))

(defmethod print-object ((f protobuf-field) stream)
  (print-unprintable-object (f stream :type t :identity t)
    (format stream "~A ~A~:[~*~*~; (~S~@[ :: ~S~])~] = ~D"
            (proto-type f) (proto-name f)
            (or (proto-value f) (proto-class f)) (proto-value f) (proto-class f)
            (proto-index f))))


;; A protobuf enumeration
(defclass protobuf-enum ()
  ((name :type string                           ;the Protobuf name for the enum type
         :reader proto-name
         :initarg :name)
   (class :type (or null symbol)                ;the Lisp type it represents
          :accessor proto-class
          :initarg :class
          :initform nil)
   (values :type (list-of protobuf-enum-value)  ;all the values for this enum type
           :accessor proto-values
           :initarg :values
           :initform ())
   (comment :type (or null string)
            :accessor proto-comment
            :initarg :comment
            :initform nil)))

(defmethod print-object ((e protobuf-enum) stream)
  (print-unprintable-object (e stream :type t :identity t)
    (format stream "~A~@[ (~S)~]"
            (proto-name e) (proto-class e))))


;; A protobuf value within an enumeration
(defclass protobuf-enum-value ()
  ((name :type string                           ;the name of the enum value
         :reader proto-name
         :initarg :name)
   (index :type (integer 1 #.(1- (ash 1 32)))   ;the index of the enum value
          :accessor proto-index
          :initarg :index)
   (value :type (or null symbol)
          :accessor proto-value                 ;the Lisp value of the enum
          :initarg :value
          :initform nil)))

(defmethod print-object ((v protobuf-enum-value) stream)
  (print-unprintable-object (v stream :type t :identity t)
    (format stream "~A = ~D~@[ (~S)~]"
            (proto-name v) (proto-index v) (proto-value v))))


;; A protobuf service
(defclass protobuf-service ()
  ((name :type string                           ;the Protobuf name for the service
         :reader proto-name
         :initarg :name)
   (rpcs :type (list-of protobuf-rpc)           ;the RPCs in the service
         :accessor proto-rpcs
         :initarg :rpcs
         :initform ())
   (comment :type (or null string)
            :accessor proto-comment
            :initarg :comment
            :initform nil)))

(defmethod print-object ((s protobuf-service) stream)
  (print-unprintable-object (s stream :type t :identity t)
    (format stream "~A"
            (proto-name s))))


;; A protobuf RPC within a service
(defclass protobuf-rpc ()
  ((name :type string                           ;the Protobuf name for the RPC
         :reader proto-name
         :initarg :name)
   (input :type (or null string)                ;the name of the input message type
          :accessor proto-input-type
          :initarg :input-type)
   (output :type (or null string)               ;the name of the output message type
           :accessor proto-output-type
           :initarg :output-type)
   (comment :type (or null string)
            :accessor proto-comment
            :initarg :comment
            :initform nil)))

(defmethod print-object ((r protobuf-rpc) stream)
  (print-unprintable-object (r stream :type t :identity t)
    (format stream "~A (~@[~A~]) => (~@[~A~])"
            (proto-name r) (proto-input-type r) (proto-output-type r))))
