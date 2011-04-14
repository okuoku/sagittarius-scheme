;; -*- scheme -*-
;; This file is a part of Sagittarius Scheme system.
(library (core syntax-case)
    (export syntax-case syntax datum->syntax
	    identifier? syntax-violation with-syntax
	    quasisyntax unsyntax unsyntax-splicing)
    (import (core)
	    (pp)
	    (sagittarius)
	    (sagittarius vm)
	    (core base)
	    (core errors)
	    (core syntax expander))
	    ;;(core syntax pattern)
	    ;;(core syntax template)
	    ;;(core syntax helper))

  (define-syntax syntax-case
    (lambda (x)
      (let ((expr (car x))
	    (env  (cdr x))
	    (dict (make-eq-hashtable)))
	(define (rename s) (er-rename s env dict))
	(define (compare a b)
	  (or (eq? a b)
	      (and (variable? a)
		   (variable? b)
		   (eq? (rename a) (rename b)))
	      #f))
	(let ((r
	       (expand-syntax-case expr env '() rename compare #t #f)))
	  ;;(pretty-print (unwrap-syntax r))
	  r))))

  (define-syntax syntax
    (er-macro-transformer
     (lambda (form rename compare)
       (unless (= (length form) 2)
	 (syntax-violation 'syntax
			   "expected exactly one datum"
			   form))
       (make-syntax-object (cadr form)))))

  (define datum->syntax
    (lambda (id datum)
      (unless (identifier? id)
	(assertion-violation 'datum->syntax
			     (wrong-type-argument-message
			      "syntax object" id 1)
			     id))
      (cons (make-identifier datum '() (vm-current-library))
	    `#(,(vm-current-library) () #f #f))))

  (define-syntax unsyntax
    (lambda (x)
      (syntax-violation (and (pair? x) (car x)) "misplaced auxiliary syntactic keyword" x)))

  (define-syntax unsyntax-splicing
    (lambda (x)
      (syntax-violation (and (pair? x) (car x)) "misplaced auxiliary syntactic keyword" x)))

  #;(define-syntax datum
    (syntax-rules ()
      ((_ x) (syntax->datum (syntax x)))))


  (define-syntax with-syntax
    (lambda (x)
      (syntax-case x ()
        ((_ () e1 e2 ...)
	 (syntax (begin e1 e2 ...)))
        ((_ ((out in)) e1 e2 ...)
	 (syntax (syntax-case in ()
		   (out (begin e1 e2 ...)))))
        ((_ ((out in) ...) e1 e2 ...)
	 (syntax (syntax-case (list in ...) ()
		   ((out ...) (begin e1 e2 ...))))))))


  ;; quasisyntax from

  ;;; Portable implementation of syntax-case
  ;;; Extracted from Chez Scheme Version 7.3 (Feb 26, 2007)
  ;;; Authors: R. Kent Dybvig, Oscar Waddell, Bob Hieb, Carl Bruggeman
  ;;; Copyright (c) 1992-2002 Cadence Research Systems
  ;;; Permission to copy this software, in whole or in part, to use this
  ;;; software for any lawful purpose, and to redistribute this software
  ;;; is granted subject to the restriction that all copies made of this
  ;;; software must include this copyright notice in full.  This software
  ;;; is provided AS IS, with NO WARRANTY, EITHER EXPRESS OR IMPLIED,
  ;;; INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES OF MERCHANTABILITY
  ;;; OR FITNESS FOR ANY PARTICULAR PURPOSE.  IN NO EVENT SHALL THE
  ;;; AUTHORS BE LIABLE FOR CONSEQUENTIAL OR INCIDENTAL DAMAGES OF ANY
  ;;; NATURE WHATSOEVER.

  (define-syntax quasisyntax
    (lambda (x)
      (define (qs q n b* k)
	(syntax-case q (quasisyntax unsyntax unsyntax-splicing)
	  ((quasisyntax . d)
	   (qs #'d (+ n 1) b*
	       (lambda (b* dnew)
		 (k b*
		    (if (eq? dnew #'d)
			q
			(with-syntax ((d dnew)) #'(quasisyntax . d)))))))
	  ((unsyntax . d)
	   (not (= n 0))
	   (qs #'d (- n 1) b*
	       (lambda (b* dnew)
		 (k b*
		    (if (eq? dnew #'d)
			q
			(with-syntax ((d dnew)) #'(unsyntax . d)))))))
	  ((unsyntax-splicing . d)
	   (not (= n 0))
	   (qs #'d (- n 1) b*
	       (lambda (b* dnew)
		 (k b*
		    (if (eq? dnew #'d)
			q
			(with-syntax ((d dnew)) #'(unsyntax-splicing . d)))))))
	  ((unsyntax q)
	   (= n 0)
	   (with-syntax (((t) (generate-temporaries #'(q))))
			(k (cons #'(t q) b*) #'t)))
	  (((unsyntax q ...) . d)
	   (= n 0)
	   (qs #'d n b*
	       (lambda (b* dnew)
		 (with-syntax (((t ...) (generate-temporaries #'(q ...))))
			      (k (append #'((t q) ...) b*)
				 (with-syntax ((d dnew)) #'(t ... . d)))))))
	  (((unsyntax-splicing q ...) . d)
	   (= n 0)
	   (qs #'d n b*
	       (lambda (b* dnew)
		 (with-syntax (((t ...) (generate-temporaries #'(q ...))))
			      (k (append #'(((t (... ...)) q) ...) b*)
				 (with-syntax ((((m ...) ...) #'((t (... ...)) ...)))
					      (with-syntax ((d dnew)) #'(m ... ... . d))))))))
	  ((a . d)
	   (qs #'a n b*
	       (lambda (b* anew)
		 (qs #'d n b*
		     (lambda (b* dnew)
		       (k b*
			  (if (and (eq? anew #'a) (eq? dnew #'d))
			      q
			      (with-syntax ((a anew) (d dnew)) #'(a . d)))))))))
	  (#(x ...)
	   (vqs #'(x ...) n b*
		(lambda (b* xnew*)
		  (k b*
		     (if (let same? ((x* #'(x ...)) (xnew* xnew*))
			   (if (null? x*)
			       (null? xnew*)
			       (and (not (null? xnew*))
				    (eq? (car x*) (car xnew*))
				    (same? (cdr x*) (cdr xnew*)))))
			 q
			 (with-syntax (((x ...) xnew*)) #'#(x ...)))))))
	  (_ (k b* q))))
      (define (vqs x* n b* k)
	(if (null? x*)
	    (k b* '())
	    (vqs (cdr x*) n b*
		 (lambda (b* xnew*)
		   (syntax-case (car x*) (unsyntax unsyntax-splicing)
		     ((unsyntax q ...)
		      (= n 0)
		      (with-syntax (((t ...) (generate-temporaries #'(q ...))))
				   (k (append #'((t q) ...) b*)
				      (append #'(t ...) xnew*))))
		     ((unsyntax-splicing q ...)
		      (= n 0)
		      (with-syntax (((t ...) (generate-temporaries #'(q ...))))
				   (k (append #'(((t (... ...)) q) ...) b*)
				      (with-syntax ((((m ...) ...) #'((t (... ...)) ...)))
						   (append #'(m ... ...) xnew*)))))
		     (_ (qs (car x*) n b*
			    (lambda (b* xnew)
			      (k b* (cons xnew xnew*))))))))))

      (syntax-case x ()
        ((_ x)
         (qs #'x 0 '()
             (lambda (b* xnew)
               (if (eq? xnew #'x)
                   #'(syntax x)
                   (with-syntax (((b ...) b*) (x xnew))
                     #'(with-syntax (b ...) (syntax x))))))))))
  )
;; end of file
;; Local Variables:
;; coding: utf-8-unix
;; End: