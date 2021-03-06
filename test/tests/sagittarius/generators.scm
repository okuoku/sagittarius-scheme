(import (rnrs)
	(sagittarius generators)
	(sagittarius control)
	(util list)
	(srfi :1)
	(srfi :26)
	(srfi :60) ;; for integer->list
	(srfi :64))

(test-begin "Generators")

;; test cases are from Gauche
;; first, let's test the stuff used by the following tests.
(test-equal "giota + generator->list" '(0 1 2 3 4)
       (generator->list (giota 5)))
(test-equal "giota(start) + generator->list" '(10 11 12 13 14)
       (generator->list (giota 5 10)))
(test-equal "giota(start,step) + generator->list" '(10 12 14 16 18)
       (generator->list (giota 5 10 2)))
(test-equal "giota + generator->list(n)" '(0 1 2)
       (generator->list (giota 5) 3))
(test-equal "giota + generator->list(n)" '(0 1 2 3 4)
       (generator->list (giota 5) 10))
(test-equal "giota + generator->list(+inf.0)" '(0 1 2 3 4 5 6 7 8 9)
       (generator->list (giota) 10))
(test-equal "giota + generator->list(+inf.0)" '(5 6 7 8 9 10 11 12 13 14)
       (generator->list (giota +inf.0 5) 10))
(test-equal "giota + generator->list(-1)" '(5 6 7 8 9 10 11 12 13 14)
       (generator->list (giota -1 5) 10))
(test-equal "giota + generator->list(step 1/2)" '(1 3/2 2 5/2 3)
       (generator->list (giota +inf.0 1 1/2) 5))
(test-equal "giota + generator->list(step 1/2, inexact)" '(1.0 1.5 2.0 2.5 3.0)
       (generator->list (giota +inf.0 1.0 1/2) 5))

(test-equal "grange + generator->list" '(0 1 2 3 4)
       (generator->list (grange 0 5)))
(test-equal "grange + generator->list" '(2 3 4 5)
       (generator->list (grange 2 6)))
(test-equal "grange + generator->list" '(2 5 8 11)
       (generator->list (grange 2 14 3)))
(test-equal "grange + generator->list" '(1 3/2 2 5/2)
       (generator->list (grange 1 3 1/2)))
(test-equal "grange + generator->list" '(1.0 1.5 2.0 2.5)
       (generator->list (grange 1.0 3 1/2)))

;; converters

(letrec ((subseq (lambda (data :optional (start 0) (end -1))
		   (define len (length data))
		   (let loop ((i 0) (r '()) (data data))
		     (cond ((or (= i len) (= i end)) (reverse! r))
			   ((>= i start) 
			    (loop (+ i 1) (cons (car data) r) (cdr data)))
			   (else 
			    (loop (+ i 1) r (cdr data)))))))
	 (identity (lambda (x) x)))
  (let-syntax ((t (syntax-rules ()
		    [(t dir fn cv data)
		     (let1 expect (^ args
				     (if (eq? 'dir 'r)
					 (reverse (apply subseq (cv data) args))
					 (apply subseq (cv data) args)))
		       (test-equal (format "~a" 'fn) (expect)
				   (generator->list (fn data)))
		       (test-equal (format "~a (1,_)" 'fn) (expect 1)
				   (generator->list (fn data 1)))
		       (test-equal (format "~a (1,3)" 'fn) (expect 1 3)
				   (generator->list (fn data 1 3)))
		       )])))
    (t f list->generator identity '(a b c d e))
    (t f vector->generator vector->list '#(a b c d e))
    (t r reverse-vector->generator vector->list '#(a b c d e))
    (t f string->generator string->list "abcde")
    ))

;; should we?
;; (let ()
;;   (define (fill-take lis right left)
;;     (if (> left (length lis))
;;       (take (append (make-list (- left (length lis)) #f) lis) (- left right))
;;       (take (drop lis (- (length lis) left)) (- left right))))
;;   (define (identity x) x)
;;   (let-syntax ((t (syntax-rules ()
;;                     [(t dir fn data)
;;                      (let ([expect (integer->list data)]
;;                            [cv (if (eq? 'dir 'r) reverse identity )])
;;                        (begin (test-equal (format "~a ~a" 'fn data) expect
;;                                      (cv (generator->list (fn data))))
;;                               (test-equal (format "~a (0,8) ~a" 'fn data)
;;                                      (cv (fill-take expect 0 8))
;;                                      (generator->list (fn data 0 8)))
;;                               (test-equal (format "~a (8,16) ~a" 'fn data)
;;                                      (cv (fill-take expect 8 16))
;;                                      (generator->list (fn data 8 16)))))])))
;;     (t r bits->generator #x36)
;;     (t f reverse-bits->generator #x36)
;;     (t r bits->generator #xcafebabe)
;;     (t f reverse-bits->generator #xcafebabe)
;;     ))
                                 
(test-equal "do-generator" '(4 4 3 3 2 2 1 1 0 0)
       (rlet1 p '()
         (do-generator [v (giota 5)]
           (push! p v)
           (push! p v))))

(let ()
  (define (test-gcons xs tail)
    (test-equal (format "gcons* ~s + ~s" xs tail)
           (apply cons* (append xs `(,tail)))
           (generator->list (apply gcons*
                                   (append xs `(,(list->generator tail)))))))
  (test-gcons '() '(x y z))
  (test-gcons '(a) '(x y z))
  (test-gcons '(a b) '(x y z))
  (test-gcons '(a b c) '(x y z)))

(let ()
  (define (test-generate expect gen)
    (test-equal "generate" expect (generator->list gen 10)))

  (test-generate '() (generate (^[yield] #f)))
  (test-generate '(0) (generate (^[yield] (yield 0) 3)))
  (test-generate '(0 1) (generate (^[yield] (yield 0) (yield 1))))

  (test-generate '(0 1 2 3 4 5 6 7 8 9)
                 (generate
                  (^[yield] (let loop ([i 0]) (yield i) (loop (+ i 1))))))
  )

(test-equal "gappend" '(0 1 2 3 a b c d A B C D)
       (generator->list (gappend (giota 4)
                                 (->generator '(a b c d))
                                 (->generator '(A B C D)))))

(test-equal "gflatten" '(0 1 2 3 a b c d A B C D)
       (generator->list (gflatten (->generator (list (iota 4)
                                                      '(a b c d)
                                                      '(A B C D))))))

(test-equal "gconcatenate" '(0 1 2 3 0 1 2 3 0 1)
       (generator->list (gconcatenate (gunfold (^v #f)
                                               (^_ (giota 4))
                                               (^_ #f)
                                               0))
                        10))

(let ([exp '(0 1 2 3 4 5 6 7 8 9)])
  (define (t-gmerge2 a b)
    (test-equal (format "gmerge ~s ~s" a b) exp
           (generator->list (gmerge < (->generator a) (->generator b))))
    (test-equal (format "gmerge ~s ~s" b a) exp
           (generator->list (gmerge < (->generator b) (->generator a)))))
  (t-gmerge2 '(1 4 5 7 8) '(0 2 3 6 9))
  (t-gmerge2 '(1 2 3) '(0 4 5 6 7 8 9))
  (t-gmerge2 '() '(0 1 2 3 4 5 6 7 8 9)))

(test-equal "gmerge () ()" '()
       (generator->list (gmerge < null-generator null-generator)))

(test-equal "gmerge (0 1 2 3)" '(0 1 2 3)
       (generator->list (gmerge < '(0 1 2 3))))

(test-equal "gmerge multi-way" '(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16)
       (generator->list (gmerge <
                                '(0 15) '(11) '(3 7 14) '(4 10) '() '(16)
                                '(1 5) '(6 8 9) '(2) '(12) '(13))))

(test-equal "gconcatenate" '(0 1 2 3 a b c d A B C D)
       (generator->list (gconcatenate (->generator
                                       (list (->generator '(0 1 2 3))
                                             (->generator '(a b c d))
                                             (->generator '(A B C D)))))))

(test-equal "gunfold" (unfold (^s (>= s 10))
                         (^s (* s 2))
                         (^s (+ s 1))
                         0
                         (^s (iota 10)))
       (generator->list (gunfold (^s (>= s 10))
                                 (^s (* s 2))
                                 (^s (+ s 1))
                                 0
                                 (^s (giota 10)))))

(test-equal '(1 2 3 1 2 3 1 2 3 1)
	    (generator->list (circular-generator 1 2 3) 10))
(test-equal '(1 3 2 1 3 2 1 3 2 1)
	    (generator->reverse-list (circular-generator 1 2 3) 10))
(test-error assertion-violation?  (circular-generator))

(define-syntax test-list-like
  (syntax-rules ()
    [(_  gfn lfn src ...)
     (dolist [s (list src ...)]
       (test-equal (format "~s" 'gfn) (lfn s)
              (generator->list (gfn (->generator s))))
       (test-equal (format "~s (autoconvert)" 'gfn) (lfn s)
              (generator->list (gfn s))))]))

(define-syntax test-list-like*
  (syntax-rules ()
    [(_  gfn lfn src ...)
     (dolist [s (list src ...)]
       (test-equal (format "~s" 'gfn) (apply lfn s)
              (generator->list (apply gfn (map ->generator s))))
       (test-equal (format "~s (autoconvert)" 'gfn) (apply lfn s)
              (generator->list (apply gfn s))))]))

(test-list-like (cut gmap (^x (* x 2)) <>)
                (cut map (^x (* x 2)) <>)
                '(1 2 3 4 5) '())

(test-list-like* (cut gmap (^[x y] (* x y)) <...>)
                 (cut map (^[x y] (* x y)) <...>)
                 '((1 2 3 4 5) (2 3 4 5)) '(() ()))

(let ((input1 '(1 2 3 4 5))
      (input2 '(2 3 4 5)))
  (test-equal "generator-map"
	      (map (lambda (x) (* x 2)) input1)
	      (generator-map (lambda (x) (* x 2)) (list->generator input1)))
  (test-equal "generator-map"
	      (map (lambda (x y) (* x y)) input1 input2)
	      (generator-map (lambda (x y) (* x y))
			     (list->generator input1)
			     (list->generator input2))))
		 
(define-syntax values-ref
  (syntax-rules ()
    ((_ expr n)
     (let-values ((res expr))
       (list-ref res n)))))

(test-list-like (cut gcombine (^[x s] (values (+ x s) x)) 0 <>)
                (^[l]
                  (values-ref (combine (^[x s] (values (+ x s) x)) 0 l) 0))
                '(1 2 3 4 5) '())

(test-list-like* (cut gcombine (^[x y s] (values (+ x y s) x)) 0 <...>)
                 (^[l m]
                   (values-ref (combine (^[x y s] (values (+ x y s) x)) 0 l m)
                               0))
                '((1 2 3 4) (8 9 0 1 2)) '(() ()))

(test-list-like (cut gfilter odd? <>)
                (cut filter odd? <>)
                '(1 2 3 4 5) '())

(test-list-like (cut gfilter-map (^[n] (and (odd? n) (* n 2))) <>)
                (cut filter-map (^[n] (and (odd? n) (* n 2))) <>)
                '(1 2 3 4 5) '())

(test-list-like (cut gtake <> 3)
                (cut take* <> 3)
                '(1 2 3 4 5 6) '(1 2))

(test-list-like (cut gtake <> 3 'a)
                (cut take* <> 3 #t 'a)
                '(1 2 3 4 5 6) '(1 2))

(test-list-like (cut gdrop <> 3)
                (cut drop* <> 3)
                '(1 2 3 4 5 6) '(1 2))

(test-list-like (cut gtake-while even? <>)
                (cut take-while even? <>)
                '(2 4 0 1 3) '(1 2 4 4 8) '() '(2 2) '(3 5))

(test-list-like (cut gdrop-while even? <>)
                (cut drop-while even? <>)
                '(2 4 0 1 3) '(1 2 4 4 8) '() '(2 2) '(3 5))

;; maybe for future?
;; (test-list-like (cut gslices <> 3)
;;                 (cut slices <> 3)
;;                 '(1 2 3 4 5 6 7 8 9) '(1 2 3 4) '(1)  '())
;; (test-list-like (cut gslices <> 3 #t)
;;                 (cut slices <> 3 #t)
;;                 '(1 2 3 4 5 6 7 8 9) '(1 2 3 4) '(1)  '())
;; (test-list-like (cut gslices <> 3 #t 'z)
;;                 (cut slices <> 3 #t 'z)
;;                 '(1 2 3 4 5 6 7 8 9) '(1 2 3 4) '(1)  '())

(test-equal "gdelete-neighbor-dups"
       "Misisipi"
       (list->string (generator->list (gdelete-neighbor-dups "Mississippi"))))
(test-equal "gdelete-neighbor-dups"
       '()
       (generator->list (gdelete-neighbor-dups '())))

(let ()
  (define g (list->generator '(1 2 3)))
  (test-equal "glet* (1)" 1 (glet* ((a (g))) a))
  (test-equal "glet* (2)" 4 (glet* ((a (g))) (define b 2) (+ a b)))
  (test-assert "glet* (3)" (eof-object? (glet* ((a (g)) (b (g))) (+ a b)))))

(test-end)
