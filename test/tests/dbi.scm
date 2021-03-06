;; -*- scheme -*-
#!compatible
(library (dbd test)
    (export make-test-driver)
    (import (rnrs)
	    (dbi)
	    (clos user)
	    (clos core))
  (define-class <dbi-test-driver> (<dbi-driver>)
    ())

  (define-class <dbi-test-connection> (<dbi-connection>)
    ())

  ;; to make method more specifig
  (define-class <dbi-test-query> (<dbi-query>)
    ()) ;; no slot

  (define-method dbi-make-connection ((driver <dbi-test-driver>)
				      (options <string>)
				      (option-alist <list>) . auth)
    (make <dbi-test-connection>))

  (define-method dbi-open? ((conn <dbi-test-connection>))
    #t)

  (define-method dbi-close ((conn <dbi-test-connection>))
    #t)

  (define-method dbi-prepare ((conn <dbi-test-connection>)
			      (sql <string>) . args)
      (make <dbi-test-query>
	:connection conn
	:prepared "prepared statement"))

  (define-method dbi-commit! ((conn <dbi-test-connection>))
    #t)

  (define-method dbi-rollback! ((conn <dbi-test-connection>))
    #t)

  (define-method dbi-bind-parameter! ((query <dbi-test-query>)
				      (index <integer>) value . args)
    #t)

  (define-method dbi-execute! ((query <dbi-test-query>) . args)
    #t)

  (define-method dbi-fetch! ((query <dbi-test-query>))
    (vector 1))

  (define-method dbi-fetch-all! ((query <dbi-test-query>))
    (list (vector 1)
	  (vector 2)))

  (define-method dbi-commit! ((query <dbi-test-query>))
    'query-commit)

  (define-method dbi-rollback! ((query <dbi-test-query>))
    'query-rollback)

  (define-method dbi-columns ((query <dbi-test-query>))
    (vector 'ID))

  (define (make-test-driver)
    (make <dbi-test-driver>))
)


(import (rnrs)
	(dbi)
	(clos user)
	(srfi :64 testing))

(define conn (dbi-connect "dbi:test"))

(test-begin "DBI test")
(test-assert (dbi-open? conn))
(let ((query (dbi-prepare conn "select id from dummy")))
  (test-assert (dbi-execute! query))
  (test-equal '#(ID) (dbi-columns query))
  (test-equal '#(1) (dbi-fetch! query))
  ;; it's just a test
  (test-equal '(#(1) #(2)) (dbi-fetch-all! query))
  ;; query level commit and rollback
  (test-assert (dbi-commit! query))
  (test-assert (dbi-rollback! query))
  (test-assert (dbi-bind-parameter! query 0 "value"))

  ;; default implementation return the same statement
  (test-equal "dbi-execute-query!" query (dbi-execute-query! query))
  )
(let ((q (dbi-execute-query-using-connection! conn "select id from dummy")))
  (test-assert "query?" (is-a? q <dbi-query>))
  (test-equal '#(ID) (dbi-columns q))
  (test-equal '#(1) (dbi-fetch! q))
  ;; it's just a test
  (test-equal '(#(1) #(2)) (dbi-fetch-all! q))
  
  )

;; connection level commit and rollback
(test-assert (dbi-commit! conn))
(test-assert (dbi-rollback! conn))

;; condition tests
(test-assert (dbi-error? (make-dbi-sql-error 200)))
(test-assert (dbi-sql-error? (make-dbi-sql-error 200)))
(test-equal 200 (dbi-sql-error-code (make-dbi-sql-error 200)))

(test-end)
