;; -*- mode: scheme; coding: utf-8; -*-
(library (issue helper)
    (export loop-10 define-something symbol bar foo)
    (import (rnrs))
  (define-syntax loop-10
    (lambda (x)
      (syntax-case x ()
        [(k e ...)
         (with-syntax
             ([break (datum->syntax #'k 'break)])
           #'(call-with-current-continuation
              (lambda (break)
                (let f () e ... (f)))))])))

  (define-syntax define-something
    (lambda (x)
      (syntax-case x (lambda)
	((_ (name . formals) body ...)
	 #'(define-something name (lambda formals body ...)))
	((_ name (lambda formals body ...))
	 #'(define name (lambda formals body ...))))))

  (define (something) (display 'hoge) (newline))
  (define symbol 'symbol)


  (define (problem) 'ok)

  (define-syntax bar
    (lambda (x)
      (define (dummy)
	`(,(datum->syntax #'bar 'problem)))
      (syntax-case x ()
	((k) (dummy)))))
  
  (define-syntax foo
    (lambda (x)
      (define (dummy)
	`(,(datum->syntax #'brrr 'problem)))
      (syntax-case x ()
	((k) (dummy)))))
)

(library (issue :84)
    (export doit1 doit2)
    (import (rnrs) (issue helper))

  (define-syntax doit1
    (lambda (stx)
      (define (return)
    	#'symbol)
      (return)))

  (define-syntax doit2
    (lambda (stx)
      #'symbol))
  )

(import (rnrs)
	(issue helper)
	(issue :84)
	(srfi :64 testing))

;; from mosh issue 138
(define-syntax doit
  (lambda (stx)
    (syntax-case stx ()
      ((_ a b c)
       (for-all identifier? #'(a b c))
       #'(begin 'yes))
      (_
       #'(begin 'no)))))

;; issue 7
;; the same as r6rs test suites' syntax-case.sls 
(define-syntax loop
  (lambda (x)
    (syntax-case x ()
      [(k e ...)
       (with-syntax
	   ([break (datum->syntax #'k 'break)])
	 #'(call-with-current-continuation
	    (lambda (break)
	      (let f () e ... (f)))))])))
;; because of the defferent behaviour of macro expander
;; when the expression is in macro such as test-equal,
;; we can not test properly. so put it outside of macro
;; and check the return value.
(define (loop-test)
  (let ((n 3) (ls '()))
    (loop
     (if (= n 0) (break ls))
     (set! ls (cons 'a ls))
     (set! n (- n 1)))))

(test-begin "syntax-case issues")
(test-equal "doit yes"
	    'yes
	    (doit x y z))
(test-equal "doit no"
	    'no
	    (doit x 1 z))

(test-equal "loop"
	    '(a a a)
	    (loop-test))

(test-equal "loop-10" '(a a a)
	    (let ((n 3) (ls '()))
	      (loop-10
	       (if (= n 0) (break ls))
	       (set! ls (cons 'a ls))
	       (set! n (- n 1)))))

;; some more syntax-case related tests
(let ()
  (define-syntax loop2
    (lambda (x)
      (syntax-case x ()
	[(k e ...)
	 (with-syntax
	     ([?break (datum->syntax #'k 'break)])
	   #'(call-with-current-continuation
	      (lambda (?break)
		(let f () e ... (f)))))])))
  (test-equal "loop2" '(a a a)
	      (let ((n 3) (ls '()))
		(loop
		 (if (= n 0) (break ls))
		 (set! ls (cons 'a ls))
		 (set! n (- n 1))))))

;; issue 25 and 86
(test-equal "issue 25" 'ok (bar))
(test-equal "issue 25" 'ok (foo))

;; issue 84
(test-equal "doit1" 'symbol (doit1))
(test-equal "doit2" 'symbol (doit2))
;; issue 85
(let ()
  (define-something (bar) (something))
  (test-error "Issue 85" (lambda (e) e) (bar)))

;; issue 87
(let ()
  (define-syntax foo
    (lambda (x)
      (syntax-case x ()
	((_)
	 (let ((ok #''ok))
	   (define-syntax prob
	     (syntax-rules ()
	       ((_) ok)))
	   (prob))))))
  (test-equal "issue 87" 'ok (foo))
  )

;; issue 117
(let ()
  (define-syntax include
    (lambda (x)
      (syntax-case x ()
	((k)
	 (datum->syntax #'k '(+ a 1))))))
  (define-syntax m
    (syntax-rules ()
      ((_) (lambda (a) (include)))))
  (test-equal "issue 117" 3 ((m) 2)))

;; issue 128
(library (A)
    (export def)
    (import (rnrs))
  (define-syntax def
    (lambda (x)
      (syntax-case x ()
	((_ name)
	 #'(define-syntax name
	     (lambda (z)
	       (syntax-case z ()
		 ((_ a b)
		  #'(name a))
		 ((_ a)
		  #'a))))))))
)
(library (B)
    (export foo)
    (import (A) 
	    (only (sagittarius) %macroexpand)
	    (sagittarius compiler)
	    (pp))
  (def foo)
)
(import (B))
(test-equal "issue 128" 1 (foo 1))

(let ()
  (define-syntax wrap-let
    (lambda (x)
      (syntax-case x ()
	((_ expr)
	 #'(let-syntax ((foo (lambda (x) (syntax-case x () ((_) #'expr)))))
	     (foo))))))
  
  (define-syntax wrap
    (lambda (x)
      (syntax-case x ()
	((_ expr)
	 #'(let ((temp expr))
	     (wrap-let (car temp)))))))
  
  ;; Call #7
  (test-equal "let-syntax wrap" 'a (wrap '(a b c))))

(test-equal "pattern variable locally bounded(1)" 'bar
	    (let-syntax ((_ (syntax-rules ())))
	      (let-syntax ((foo (syntax-rules () ((_ _) _))))
		(foo 'bar))))

(let-syntax ((_ (syntax-rules ())))
  (let-syntax ((foo (syntax-rules () ((_ _) _))))
    (test-equal "pattern variable locally bounded(2)" 'bar
		(foo 'bar))))

;; Call #48
(let ()
  (define-syntax move-vars
    (lambda (x)
      (syntax-case x ()
	((_ (ids ...) (vs ...))
	 #''((vs ids ...) ...)))))
  (test-equal "ellipsis adjustment"
	      '((v1 id1 id2) (v2 id1 id2))
	      (move-vars (id1 id2) (v1 v2))))

;; call #61
(let ()
  (define-syntax extract
    (syntax-rules ()
      ((_ symb body _cont)
       (letrec-syntax
	   ((tr
	     (syntax-rules (symb)
	       ((_ x symb tail (cont-head symb-l . cont-args))
		(cont-head (x . symb-l) . cont-args))
	       ((_ d (x . y) tail cont)
		(tr x x (y . tail) cont))
	       ((_ d1 d2 () (cont-head  symb-l . cont-args))
		(cont-head (symb . symb-l) . cont-args))
	       ((_ d1 d2 (x . y) cont)
		(tr x x y cont)))))
	 (tr body body () _cont)))))

  (define-syntax aif
    (syntax-rules ()
      ((_ ?c ?t ?e)
       (let-syntax ((cont
		     (syntax-rules ()
		       ((cont (??it) ??c ??t ??e)
			(let ((??it ??c))
			  (if ??it ??t ??e))))))
	 (extract it (?t . ?e) (cont () ?c ?t ?e))))))

  (let ((it 0))
    (aif (assoc 'a '((a . 1) (b . 2) (c . 3)))
	 (test-equal "hygienic aif (0)" 0 it)
	 #f))
  (test-equal "hygienic aif" 0
	      (let ((it 0))
		(aif (assoc 'a '((a . 1) (b . 2) (c . 3)))
		     it
		     #f))))

;; call #88

;; global
(define-syntax let-it
  (lambda (x)
    (define (bind-it k binding)
      (syntax-case binding ()
    ((var . val) 
     (let ((n (syntax->datum #'var)))
       #`(#,(datum->syntax k n) val)))
    (_ (error 'let-it "invalid form"))))
    (syntax-case x ()
      ((k ((var . val) rest ...) body ...)
       (with-syntax (((var1 val1) (bind-it #'k #'(var . val))))
     #'(let ((var1 val1))
         (let-it (rest ...) body ...))))
      ((_ () body ...)
       #'(begin body ...)))))

(let-it ((name . 'name)) (test-equal "datum->syntax(1)" 'name name))

;; local
;; disables this test for now.
;; To resolve this issue, we need to compare identifier environment
;; in sence of eq? (or equal?). However, doing it introduces other
;; issue, bending scope. We most likely need to rewrite macro expander
;; and compiler to resolve both issues. Following is probably one of
;; the ways
;;  - Modifies compiler to rewrite bound identifier with proper env frames
;;  - Modifies variable lookup to compare identifier envs in sence of eq?
(let ()  
  (define-syntax let-it
    (lambda (x)
      (define (bind-it k binding)
	(syntax-case binding ()
	  ((var . val) 
	   (let ((n (syntax->datum #'var)))
	     #`(#,(datum->syntax k n) val)))
	  (_ (error 'let-it "invalid form"))))
      (syntax-case x ()
	((k ((var . val) rest ...) body ...)
	 (with-syntax (((var1 val1) (bind-it #'k #'(var . val))))
	   #'(let ((var1 val1))
	       (let-it (rest ...) body ...))))
	((_ () body ...)
	 #'(begin body ...)))))

  (let-it ((name . 'name)) (test-equal "datum->syntax(2)" 'name name))
  )

(let ()
  (define-syntax aif
    (lambda (x)
      (syntax-case x ()
	((ng test then)
	 #'(aif test then #f))
	((aif test then else)
	 (with-syntax ((it (datum->syntax #'aif 'it)))
	   #'(let ((it test))
	       (if it then else)))))))
  (test-assert "normal" (aif (assq 'a '((a . 0))) it #f))
  (test-error  "not the same bound id" (aif (assq 'a '((a . 0))) it)))

(library (foo)
  (export foo)
  (import (rnrs))

  (define bar 123)
  (define-syntax foo
    (let ()
      (define $bar #'bar)
      (lambda (x)
	(syntax-case x ()
	  ((_) $bar)))))
  )
(import (foo))
(test-equal "refering internal library definition" 123 (foo))

;; call #106
;; make reader R6RS strict mode
#!r6rs
(let ()
  (define-syntax foo
    (lambda (x)
      (syntax-case x ()
	((k name)
	 #'(begin
	     (define the-name 'foo)
	     (define-syntax name
	       (lambda (xx)
		 (syntax-case xx (:foo)
		   ((_ :foo) #'the-name)))))))))

  (define-syntax bar
    (lambda (x)
      (syntax-case x ()
	((k name foo?)
	 #'(begin
	     (define the-name 'bar)
	     (define-syntax name
	       (lambda (xx)
		 (syntax-case xx (:foo :bar)
		   ((_ :foo) #'(foo? :foo))
		   ((_ :bar) #'the-name)))))))))

  (let ()
    (foo foo1)
    (bar bar1 foo1)

    (test-equal "variable visibility(1)" 'foo (bar1 :foo))
    (test-equal "variable visibility(2)" 'bar (bar1 :bar))
    )
  )

;; back to compatible for my convenience
#!compatible

;; this must be top level otherwise worked fine..
(define-syntax define/datum->syntax
  (lambda (x)
    (define (concat n1 n2)
      (string->symbol
       (string-append (symbol->string (syntax->datum n1))
              "-"
              (symbol->string (syntax->datum n2)))))
    (syntax-case x ()
      ((k name1 name2 var)
       (with-syntax ((name (datum->syntax #'k (concat #'name1 #'name2))))
     #'(define name var))))))

(define-syntax define/wrap
  (syntax-rules ()
    ((_ name1 name2 var)
     (define/datum->syntax name1 name2 var))))

(define/wrap n1 n2 'hoge)

(test-error "datum->syntax refered incorrectly" undefined-violation?  n1-n2)

;; call #154
(let ()
  (define-syntax bar
    (lambda (x)
      (syntax-case x ()
	((_ (ts ...) (b ...))
	 #'(let-syntax ((buz (lambda (x)
			       (syntax-case x ()
				 ((_ ts ...) #'(list ts ...))))))
	     (buz b ...)))
	((_ (t* ...) (b ...) a as ...)
	 #'(bar (t* ... t) (b ...) as ...)))))
  (test-equal "template variable expand (1)" '(1 2 3)
	      (bar () (1 2 3) 1 2 3)))

(let ()
  (define-syntax bar
    (syntax-rules ()
      ((_ (ts ...) (b ...))
       (let-syntax ((buz (syntax-rules ()
			   ((_ ts ...) (list ts ...)))))
	 (buz b ...)))
      ((_ (ts ...) (b ...) a as ...)
       (bar (ts ... t) (b ...) as ...))))
  (test-equal "template variable expand (2)" '(1 2 3)
	      (bar () (1 2 3) 1 2 3)))

;; this is extra
(let ()
  (let-syntax ((... (syntax-rules ())))
    (let-syntax ((foo (syntax-rules ()
			((_ a ...) 'ng)
			((_ a b c) 'ok))))
      (test-equal "locally bound ellipsis" 'ok (foo 1 2 3)))))


;; there's a simplar test in R6RS test suite but adding one more
;; wouldn't hurt me.
(let ()
  (define-syntax foo
    (lambda (x)
      (syntax-case x ()
	((_ (t1 t2))
	 #`(list #,(free-identifier=? #'t1 #'t2)
		 #,(bound-identifier=? #'t1 #'t2)))
	((_ (t* ...) a b ...)
	 #'(foo (t* ... t) b ...))
	((_ a ...)
	 #'(foo () a ...)))))
  (test-equal "free or bound" '(#t #f) (foo 1 2)))

;; reported by @SaitoAtsushi
;; call #155
(let ()
  (define-syntax foo
    (syntax-rules ()
      ((_ a b)
       (let-syntax ((bar (syntax-rules (a)
                           ((_ b) 'ok)
                           ((_ d) 'ng))))
         (bar d)))
      ((_ x ...)
       (foo x ... t))))
  (test-equal "pattern variable in literal" 'ok (foo)))

(let ()
  ;; syntax-case version
  (define-syntax foo*
    (lambda (x)
      (syntax-case x ()
	((_ a b)
	 #'(let-syntax ((bar (lambda (x)
			       (syntax-case x (a)
				 ((_ b) #''ok)
				 ((_ d) #''ng)))))
	     (bar d)))
	((_ x ...)
	 #'(foo* x ... tt*)))))
  (test-equal "pattern variable in literal" 'ok (foo*)))

(let ()
  (define (match lis)
    (syntax-case lis ()
      ((a b c) #'a)
      (_ 'ng)))
  (test-assert "syntax-case returned identifier" (symbol? (match '(a b c)))))

(let ()
  
  (define-syntax foo
    (lambda (x)
      (define (derive-it k s)
	(let loop ((r '()) (s s))
	  (syntax-case s ()
	    (() (datum->syntax k r))
	    (((f a b) rest ...)
	     (loop (cons #'(f a b) (cons #'(f a b) r)) #'(rest ...))))))
      (syntax-case x ()
	((k (foo . bar) ...)
	 (with-syntax ((((foo a b) ...)
			(derive-it #'k #'((foo . bar) ...))))
	   #''((foo a b)  ...))))))

  (test-equal '((f a b) (f a b)) (foo (f a b))))

(test-end)
