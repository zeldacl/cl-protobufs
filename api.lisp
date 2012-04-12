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


;;; A Protobufs2-compatible API, whose names are taken from the Python API

(defgeneric clear (object)
  (:documentation
   "Initialize all of the fields of 'object' to their default values.")
  (:method ((object standard-object))
    (let* ((class   (class-of object))
           (message (find-message-for-class class)))
      (assert message ()
              "There is no Protobufs message for the class ~S" class)
      ;;--- Do this: set everything either to the default value or "unbound"
      message)))

(defgeneric is-initialized (object)
  (:documentation
   "Returns true iff all of the fields of 'object' are initialized.")
  (:method ((object standard-object))
    (let* ((class   (class-of object))
           (message (find-message-for-class class)))
      (assert message ()
              "There is no Protobufs message for the class ~S" class)
      ;;--- Do this: check that there are no "unbound" slots
      message)))

;; This is simpler than 'object-size', but doesn't fully support aliasing
(defgeneric octet-size (object)
  (:documentation
   "Returns the number of octets required to encode 'object' using the wire format.
    'object' is an object whose Lisp class corresponds to a Protobufs message.")
  (:method ((object standard-object))
    (let* ((class   (class-of object))
           (message (find-message-for-class class))
           (type    (and message (proto-class message))))
      (assert message ()
              "There is no Protobufs message for the class ~S" class)
      (let ((visited (make-hash-table)))
        (object-size object type visited)))))

;; This is simpler than 'serialize-object', but doesn't fully support aliasing
(defgeneric serialize (object &optional buffer start end)
  (:documentation
   "Serialize 'object' into 'buffer' using the wire format, starting at the index
   'start' and going no farther than 'end'. 'object' is an object whose Lisp class
   corresponds to a Protobufs message.")
  (:method ((object standard-object) &optional buffer (start 0) end)
    (declare (ignore end))
    (let* ((class   (class-of object))
           (message (find-message-for-class class))
           (type    (and message (proto-class message))))
      (assert message ()
              "There is no Protobufs message for the class ~S" class)
      (let* ((visited (make-hash-table))
             (size    (object-size object type visited))
             (start   (or start 0))
             (buffer  (or buffer (make-array size :element-type '(unsigned-byte 8)))))
        (assert (>= (length buffer) size) ()
                "The buffer ~S is not large enough to hold ~S" buffer object)
        (serialize-object object type buffer start visited)
        buffer))))

;; This is simpler than 'deserialize-object', but doesn't fully support aliasing
(defgeneric merge-from-array (object buffer &optional start end)
  (:documentation
   "Deserialize the object encoded in 'buffer' into 'object', starting at the index
    'start' and ending at 'end'. 'object' is an object whose Lisp class corresponds
    to a Protobufs message.")
  (:method ((object standard-object) buffer &optional (start 0) (end (length buffer)))
    (let* ((class   (class-of object))
           (message (find-message-for-class class))
           (type    (and message (proto-class message))))
      (assert message ()
              "There is no Protobufs message for the class ~S" class)
      (let* ((start  (or start 0))
             (end    (or end (length buffer))))
        (deserialize-object type buffer start end)))))

(defgeneric merge-from-message (object source-object)
  (:documentation
   "")
  (:method ((object standard-object) (source-object standard-object))
    (let* ((class   (class-of object))
           (message (find-message-for-class class))
           (type    (and message (proto-class message))))
      (assert (eq class (class-of source-object)) ()
              "The objects ~S and ~S are of not of the same class" object source-object)
      (assert message ()
              "There is no Protobufs message for the class ~S" class)
      ;;--- Do this
      type)))
