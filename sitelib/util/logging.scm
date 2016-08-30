;;; -*- mode:scheme; coding:utf-8 -*-
;;;
;;; util/logging.scm - Logging utilities
;;;  
;;;   Copyright (c) 2010-2016  Takashi Kato  <ktakashi@ymail.com>
;;;   
;;;   Redistribution and use in source and binary forms, with or without
;;;   modification, are permitted provided that the following conditions
;;;   are met:
;;;   
;;;   1. Redistributions of source code must retain the above copyright
;;;      notice, this list of conditions and the following disclaimer.
;;;  
;;;   2. Redistributions in binary form must reproduce the above copyright
;;;      notice, this list of conditions and the following disclaimer in the
;;;      documentation and/or other materials provided with the distribution.
;;;  
;;;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;;;   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;;;   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;;;   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;;;   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;;;   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
;;;   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;;;   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;;;   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;;   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;;   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;;  

(library (util logging)
  (export ;; Loggers
	  make-logger        logger?
	  make-async-logger  async-logger?
	  ;; Logger APIs
	  +trace-level+ trace-log logger-trace?
	  +debug-level+ debug-log logger-debug?
	  +info-level+  info-log  logger-info?
	  +warn-level+  warn-log  logger-warn?
	  +error-level+ error-log logger-error?
	  +fatal-level+ fatal-log logger-fatal?

	  ;; Appenders
	  <appender> make-appender appender?
	  <file-appender> make-file-appender file-appender? 
	  
	  ;; For extension
	  push-log
	  terminate-logger!
	  append-log
	  appender-finish
	  
	  format-log
	  <log> make-log log? ;; for push-log
	  )
  (import (rnrs)
	(sagittarius)
	(sagittarius control)
	(util concurrent)
	(clos user)
	(srfi :18)
	(srfi :19))

;; Log object.
(define-record-type (<log> make-log log?)
  (fields (immutable when log-when)
	  (immutable level log-level)
	  (immutable message log-message)))

;; Log formatter. It handles log object
(define (builtin-format-log log format)
  (define when (time-utc->date (log-when log)))
  (define level (log-level log))
  (define message (log-message log))
  (define in (open-string-input-port format))
  (let-values (((out extract) (open-string-output-port)))
    (do ((c (get-char in) (get-char in)))
	((eof-object? c) (extract))
      (case c
	((#\~)
	 (case (get-char in)
	   ((#\w)
	    ;; TODO long format
	    (let ((c2  (get-char in)))
	      (put-string out (date->string when (string #\~ c2)))))
	   ((#\l)
	    (put-string out (symbol->string level)))
	   ((#\m)
	    (put-string out message))
	   (else => (lambda (c2)
		      (put-char out #\~)
		      (put-char out c2)))))
	 (else (put-char out c))))))

;; Appender APIs
(define-generic append-log)
(define-generic appender-finish)
(define-generic format-log)

;; abstract appender
;; all appenders must inherit <appender>
(define-record-type (<appender> make-appender appender?)
  (fields (immutable log-format appender-format)))

(define-method format-log ((a <appender>) log)
  (builtin-format-log log (appender-format a)))

;; but you can use it for traial
;; default just print
(define-method append-log ((appender <appender>) log)
  (display (format-log appender log)) (newline))
(define-method appender-finish ((appender <appender>)) #t) ;; do nothing


;; file appender
(define-record-type (<file-appender> make-file-appender file-appender?)
  (fields (immutable filename file-appender-filename)
	  sink)
  (parent <appender>)
  (protocol (lambda (p)
	      (lambda (format filename)
		(let ((out (open-file-output-port filename
			    (file-options no-fail)
			    (buffer-mode block) (native-transcoder))))
		  ((p format) filename out))))))
(define-method append-log ((appender <file-appender>) log)
  (let ((out (<file-appender>-sink appender)))
    (display (format-log appender log) out)
    (newline out)))
(define-method appender-finish ((appender <file-appender>))
  (close-port (<file-appender>-sink appender)))

;; loggers
(define-generic push-log)
(define-generic terminate-logger!)
(define-record-type (<logger> make-logger logger?)
  (fields (immutable threashold logger-threashold)
	  (immutable appenders  logger-appenders))
  (protocol (lambda (p)
	      (lambda (threashold . appenders)
		(unless (for-all appender? appenders)
		  (assertion-violation 'make-logger "appender required"
				       appenders))
		(p threashold appenders)))))
(define-method push-log ((l <logger>) log)
  (for-each (lambda (appender) (append-log appender log))
	    (logger-appenders l)))
(define-method terminate-logger! ((l <logger>))
  (for-each appender-finish (logger-appenders l)))

(define (make-logger-deamon logger sq eq)
  (define (deamon-task)
    (define appenders (logger-appenders logger))
    (define (do-append log)
      (for-each (lambda (appender) (append-log appender log)) appenders))
    (define (do-finish) (for-each appender-finish appenders))
    (guard (e (else (shared-queue-put! eq e)))
      (let loop ()
	(let ((log (shared-queue-get! sq)))
	  (cond ((log? log) (do-append log) (loop))
		(else (do-finish) (shared-queue-put! eq #t)))))))
  (thread-start! (make-thread deamon-task)))

(define-record-type (<async-logger> make-async-logger async-logger?)
  (fields (immutable buffer logger-buffer)
	  (immutable end-buffer logger-end-buffer)
	  (mutable   deamon logger-deamon logger-deamon-set!))
  (parent <logger>)
  (protocol (lambda (p)
	      (lambda args
		(let* ((sq (make-shared-queue))
		       (eq (make-shared-queue))
		       (l ((apply p args) sq eq #f)))
		  (logger-deamon-set! l (make-logger-deamon l sq eq))
		  l)))))
(define-method push-log ((l <async-logger>) log)
  (shared-queue-put! (logger-buffer l) log))
;; maybe logger should not raise an error, but for my convenience
(define-method terminate-logger! ((l <async-logger>))
  (shared-queue-put! (logger-buffer l) #f)
  (let ((e (shared-queue-get! (logger-end-buffer l))))
    (unless (boolean? e) (raise e))))

(define-constant +trace-level+ 0)
(define-constant +debug-level+ 1)
(define-constant +info-level+  2)
(define-constant +warn-level+  3)
(define-constant +error-level+ 4)
(define-constant +fatal-level+ 5)

(define-syntax define-logging-api
  (lambda (x)
    (define ->s datum->syntax)
    (define (->level-constant k level)
      (->s k (string->symbol (format "+~a-level+" (syntax->datum level)))))
    (define (make-names k level)
      (let ((n (syntax->datum level)))
	(->s k (list (string->symbol (format "logger-~a" n))
		     (string->symbol (format "~a-log" n))))))
    (syntax-case x ()
      ((k level)
       (with-syntax ((c (->level-constant #'k #'level))
		     ((check logging) (make-names #'k #'level)))
		      
	 #'(begin
	     (define (check logger) (>= c (logger-threashold logger)))
	     (define (logging logger msg)
	       (when (check logger)
		 (push-log logger (make-log (current-time) 'level msg))))))))))
;; per level APIs
(define-logging-api trace)
(define-logging-api debug)
(define-logging-api info)
(define-logging-api warn)
(define-logging-api error)
(define-logging-api fatal)
)