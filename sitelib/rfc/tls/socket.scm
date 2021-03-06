;;; -*- Scheme -*-
;;;
;;; rfc/tls/socket.scm - TLS 1.0 - 1.2 protocol library.
;;;  
;;;   Copyright (c) 2010-2013  Takashi Kato  <ktakashi@ymail.com>
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

;; Caution this library is not well tested and not well secure yet.
(library (rfc tls socket)
    (export make-client-tls-socket
	    make-server-tls-socket

	    tls-socket?
	    tls-socket-send
	    tls-socket-recv
	    tls-socket-recv!
	    tls-socket-shutdown
	    tls-socket-close
	    tls-socket-closed?
	    tls-socket-accept
	    tls-socket-peer
	    tls-socket-name
	    tls-socket-info
	    tls-socket-info-values
	    call-with-tls-socket
	    <tls-socket>
	    ;; blocking
	    tls-socket-nonblocking!
	    tls-socket-blocking!

	    ;; for the user who wants to specify TSL version
	    *tls-version-1.2*
	    *tls-version-1.1*
	    *tls-version-1.0*

	    socket-close
	    socket-closed?
	    socket-shutdown
	    socket-send
	    socket-recv
	    socket-recv!
	    socket-accept
	    call-with-socket
	    socket-peer
	    socket-name
	    socket-info
	    socket-info-values
	    socket-nonblocking!
	    socket-blocking!
	    socket-read-select
	    socket-write-select
	    socket-error-select
	    ;; to send handshake explicitly
	    tls-server-handshake
	    tls-client-handshake

	    ;; for testing
	    *cipher-suites*
	    ;; socket conversion
	    socket->tls-socket

	    ;; hello extension helper
	    make-hello-extension
	    make-server-name-indication
	    make-protocol-name-list
	    )
    (import (rnrs)
	    (core errors)
	    (sagittarius)
	    (sagittarius socket)
	    (sagittarius control)
	    (sagittarius object)
	    (prefix (only (sagittarius socket)
			  socket-read-select
			  socket-write-select
			  socket-error-select) socket:)
	    (rename (rfc tls types) (tls-alert? %tls-alert?))
	    (rfc tls constant)
	    (rfc x.509)
	    (except (rfc hmac) verify-mac)
	    (rename (asn.1) (encode asn.1:encode))
	    (util bytevector)
	    (except (math) lookup-hash)
	    (except (crypto) verify-mac)
	    (clos user)
	    (except (binary io) get-line)
	    (rsa pkcs :10)
	    (srfi :1 lists)
	    (srfi :19 time)
	    (srfi :26 cut)
	    (srfi :39 parameters))

  (define-class <session-key> ()
    ((write-mac-secret :init-keyword :write-mac-secret)
     (write-key  :init-keyword :write-key)
     (write-iv   :init-keyword :write-iv)
     ;; (final-write-key :init-value #f)
     (read-mac-secret :init-keyword :read-mac-secret)
     (read-key  :init-keyword :read-key)
     (read-iv   :init-keyword :read-iv)
     #;(final-read-key :init-value #f)))

  (define-class <dh-params> ()
    ;; The following url was comprehensive
    ;; http://en.wikipedia.org/wiki/Diffie%E2%80%93Hellman_key_exchange
    ((g :init-keyword :g)
     (p :init-keyword :p)
     (Ys :init-keyword :Ys)   ;; A
     (Yc :init-keyword :Yc))) ;; B

  (define-class <tls-session> ()
    ((session-id :init-keyword :session-id)
     ;; negotiated version
     (version :init-keyword :version :init-value #f)
     ;; for server-certificate
     (need-certificate? :init-value #f)
     ;; random data
     (client-random     :init-value #f)
     (server-random     :init-value #f)
     ;; compression methods 
     ;; XXX for now we don't check any where
     (methods     :init-keyword :methods)
     ;; this must be defined by server
     (cipher-suite :init-value #f)
     ;; public key. can be #f if server does not have certificate
     (public-key :init-value #f)
     ;; computed master secret
     (master-secret :init-value #f)
     ;; sequence number
     (read-sequence :init-value 0)
     (write-sequence :init-value 0)
     ;; session key (to avoid unnecessary caluculation)
     (session-key    :init-value #f)
     (decrypt-cipher :init-value #f)
     (encrypt-cipher :init-value #f)
     ;; RSA or DH parameters
     (params         :init-value #f)
     (closed?        :init-value #f)
     (session-encrypted? :init-value #f)
     ;; all handshake messages without record layer...
     (messages :init-form (open-output-bytevector))
     ;; for multiple messages in one record
     (buffer   :init-value #f)
     (last-record-type :init-value #f)
     ;; signature algorithms extension described in TLS 1.2 (RFC 5246)
     (signature-algorithms :init-value '())))

  (define-class <tls-client-session> (<tls-session>)
    ((signature-algorithm :init-value #f)
     (hash-algorithm :init-value #f)))

  (define-class <tls-server-session> (<tls-session>)
    ;; for DHE
    ((a :init-value #f)
     (authority :init-value '())
     ;; ugly ...
     ;; for certificate verify
     (verify-message :init-value #f)
     ;; to keep client-finish message ...
     (client-finished)))

  ;; abstract class for tls sockets
  (define-class <tls-socket> ()
    ((raw-socket :init-keyword :raw-socket)
     ;; should this be in session?
     (version    :init-keyword :version)
     (prng       :init-keyword :prng)
     (session    :init-keyword :session)
     ;; for tls-socket-recv, we need to store application data
     ;; in this buffer to be able to take size argument.
     (buffer     :init-value #f)
     ;; both server and client need these slots
     (certificates :init-value '() :init-keyword :certificates)
     (private-key  :init-value #f  :init-keyword :private-key)
     (sent-shutdown? :init-value #f)
     ;; root server socket doesn't have peer
     ;; this is for sending close notify
     (has-peer?    :init-keyword :has-peer? :init-value #t)
     (extensions :init-value '())))

  (define-class <tls-client-socket> (<tls-socket>)
    (;; for convenience to test.
     (cipher-suites :init-keyword :cipher-suites)))

  (define-class <tls-server-socket> (<tls-socket>) 
    ;; for certificate request and verify
    ((authorities :init-keyword :authorities)))

  (define-method write-object ((o <tls-socket>) out)
    (let1 session (~ o 'session)
      (format out "#<~a ~x~a~a>" 
	      (if (is-a? o <tls-server-socket>)
		  "tls-server-socket" "tls-client-socket") 
	      (~ session 'version)
	      (if (~ session 'closed?)
		  " session-closed"
		  "")
	      (or (~ o 'raw-socket)
		  " closed"))))
  (define (tls-socket? o) (is-a? o <tls-socket>))
  (define (tls-socket-closed? socket) (~ socket 'session 'closed?))

  (define-condition-type &tls-alert &condition %make-tls-alert tls-alert?
    (level alert-level)
    (message alert-message))

  (define (tls-alert level message) (%make-tls-alert level message))
  (define (tls-warning-alert message) (tls-alert *warning* message))
  (define (tls-fatal-alert message) (tls-alert *fatal* message))

  (define (tls-error who msg desc . irr)
    (raise (condition (tls-fatal-alert desc)
		      (and who (make-who-condition who))
		      (make-message-condition msg)
		      (make-irritants-condition irr))))

  (define (negotiated-version socket)
    (let1 session (~ socket 'session)
      (or (~ session 'version)
	  (~ socket 'version))))


  ;; helper
  (define (get-u24 in endianness) (get-u* in 3 endianness))

  (define (make-cipher-suites socket)
    (let* ((suites (~ socket 'cipher-suites))
	   (size (length suites))
	   (bv (make-bytevector (* size 2))))
      (do ((i 0 (+ i 2)) (ciphers suites (cdr ciphers)))
	  ((null? ciphers))
	(bytevector-u16-set! bv i (caar ciphers) 'big))
      bv))

  (define (make-client-hello socket :optional (extension '()) :rest ignore)
    (let* ((version (negotiated-version socket))
	   (session (~ socket 'session))
	   (random-bytes (read-random-bytes (~ socket 'prng) 28))
	   (random (make-tls-random random-bytes))
	   (session-id (make-variable-vector 1 (~ session 'session-id)))
	   (cipher-suite (make-variable-vector 2 (make-cipher-suites socket)))
	   (compression-methods (make-variable-vector 1 (~ session 'methods)))
	   (hello (make-tls-client-hello
		   :version version
		   :random random
		   :session-id session-id
		   :cipher-suites cipher-suite
		   :compression-methods compression-methods
		   :extensions extension)))
      (set! (~ session 'client-random) random)
      (make-tls-handshake *client-hello* hello)))

  (define (make-initial-session prng class)
    (make class
      :session-id (read-random-bytes prng 28)
      :methods #vu8(0)))

  (define *dh-prime-size* (make-parameter 1024))
  ;; is 2 ok?
  (define-constant +dh-g+ 2)

  (define (tls-packet->bytevector p)
    (call-with-bytevector-output-port (^o (write-tls-packet p o))))

  (define (%make-tls-server-socket raw-socket :key
				   (prng (secure-random RC4))
				   (private-key #f)
				   (version *tls-version-1.2*)
				   (certificates '())
				   (authorities '()))
    (make <tls-server-socket> :raw-socket raw-socket
	  :version version :prng prng
	  ;; so far we don't need this but for later
	  :private-key private-key
	  :certificates certificates
	  :authorities authorities
	  :session (make-initial-session prng <tls-server-session>)
	  :has-peer? #f))

  (define (make-server-tls-socket port certificates :key
				  (prng (secure-random RC4))
				  (private-key #f)
				  (version *tls-version-1.2*)
				  (authorities '())
				  :allow-other-keys opt)
    (let1 raw-socket (apply make-server-socket port opt)
      (%make-tls-server-socket raw-socket
			       :certificates certificates
			       :prng prng :private-key private-key
			       :version version :authorities authorities)))

  (define (tls-socket-accept socket :key (handshake #t) (raise-error #t))
    ;; socket-accept may return #f when thread is interrupted
    (and-let* ((raw-socket (socket-accept (~ socket 'raw-socket)))
	       (new-socket (make <tls-server-socket> :raw-socket raw-socket
				 :version (~ socket 'version)
				 :prng (~ socket 'prng)
				 :session (make-initial-session 
					   (~ socket 'prng)
					   <tls-server-session>)
				 :private-key (~ socket 'private-key)
				 :certificates (~ socket 'certificates)
				 :authorities (~ socket 'authorities))))
      (if handshake
	  (tls-server-handshake new-socket :raise-error raise-error)
	  new-socket)))

  (define (verify-mac socket finish label restore-message?)
    (let* ((session (~ socket 'session))
	   (messages ((if restore-message?
			  get-output-bytevector
			  extract-output-bytevector) (~ session 'messages)))
	   (session-verify (tls-finished-data finish))
	   (verify (finish-message-hash session label messages)))
      ;; verify message again
      ;;(display messages) (newline)
      ;;(dump-all-handshake-messages messages (is-dh? session) (~ session 'version))
      #;
      (when restore-message? 
	(put-bytevector (~ session 'messages) messages))
      (or (bytevector=? session-verify verify)
	  (tls-error 'tls-handshake "MAC verification failed"
		     *bad-record-mac*))))

  (define (handle-error socket e :key (raise-error #t))
    (define (finish socket e)
      (define (close socket)
	;; I have no idea which path this could happen
	;; but it happened...
	(when (~ socket 'raw-socket)
	  (socket-shutdown (~ socket 'raw-socket) SHUT_RDWR))
	(%tls-socket-close socket))
      (cond (raise-error (close socket) (raise e))
	    ;; if raise-error is #f, then don't close
	    ;; otherwise returning closed socket.
	    (else socket)))
    (cond ((tls-alert? e) (finish socket e))
	  (else
	   (when (~ socket 'raw-socket)
	     ;; don't raise an error here.
	     (guard (e (else #f))
	       (tls-socket-send-inner socket
		 (make-tls-alert *fatal* *internal-error*)
		 0 *alert* #f)))
	   (finish socket e))))

  (define (verify-message socket message signature)
    (let* ((session (~ socket 'session))
	   (key (if (is-a? session <tls-client-session>)
		    (~ session 'public-key)
		    (x509-certificate-get-public-key (~ session 'authority)))))
      (if (>= (~ session 'version) *tls-version-1.2*)
	  (or (and-let* ((s (assv (~ signature 'hash) *supported-hashes*))
			 (c (assv (~ signature 'algorithm)
				  *supported-signatures*))
			 (v-cipher (cipher (cdr c) key
					   :block-type PKCS-1-EMSA))
			 (msg (decrypt v-cipher (~ signature 'signature)))
			 (obj (read-asn.1-object
			       (open-bytevector-input-port msg))))
		(bytevector=? (hash (cdr s) message)
			      (~ (asn.1-sequence-get obj 1) 'string)))
	      (tls-error 'certificate-verify "verify failed"
			 *unsupported-certificate*))
	  (let1 rsa-cipher (cipher RSA key :block-type PKCS-1-EMSA)
	    (or (bytevector=? (bytevector-concat (hash MD5 message)
						 (hash SHA-1 message))
			      (decrypt rsa-cipher (~ signature 'signature)))
		(tls-error 'certificate-verify "verify failed"
			   *unsupported-certificate*))))))

  (define (tls-server-handshake socket :key (raise-error #t))
    (guard (e (else (handle-error socket e :raise-error raise-error)))
      (%tls-server-handshake socket)
      socket))

  (define (%tls-server-handshake socket)
    (define (process-client-hello! hello)
      (define (handle-signature-algorithm extension)
	(let* ((data (~ extension 'data 'value))
	       (size (+ (bytevector-u16-ref data 0 'big) 2)))
	  (let loop ((i 2) (r '()))
	    (if (= i size)
		(set! (~ socket 'session 'signature-algorithms) (reverse! r))
		(let ((hash (bytevector-u8-ref data i))
		      (sig  (bytevector-u8-ref data (+ i 1))))
		  (if (and (assv sig *supported-signatures*)
			   (assv hash *supported-hashes*))
		      (loop (+ i 2) (acons hash sig r))
		      (loop (+ i 2) r)))))))

      ;; if socket doesn't have private-key, then we need to remove
      ;; DHE protocols
      (define (adjust-suites socket suites)
	(if (~ socket 'private-key)
	    suites
	    (remp (lambda (s)
		    (memv (car s ) *dh-key-exchange-algorithms*)) suites)))

      ;;(display (tls-packet->bytevector hello)) (newline)
      (unless (<= *tls-version-1.0*  (~ hello 'version) *tls-version-1.2*)
	(tls-error 'tls-server-handshake
		   "non supported TLS version" *protocol-version*
		   (~ hello 'version)))
      (set! (~ socket 'session 'version) (~ hello 'version))
      (set! (~ socket 'session 'client-random) (~ hello 'random))
      ;; (display (~ hello 'extensions)) (newline)
      (cond ((find-tls-extension *signature-algorithms* (~ hello 'extensions))
	     => handle-signature-algorithm))
      (let* ((vv (~ hello 'cipher-suites))
	     (bv (~ vv 'value))
	     (len (bytevector-length bv))
	     (has-key? (~ socket 'private-key))
	     (supporting-suites (adjust-suites socket *cipher-suites*)))
	(let loop ((i 0))
	  (cond ((>= i len)
		 (tls-error 'tls-server-handshake "no cipher"
			    *handshake-failure*))
		((and-let* ((spec (bytevector-u16-ref bv i 'big))
			    ( (or has-key? 
				  (memv spec *dh-key-exchange-algorithms*)
				  (memv spec 
					*dh-anon-key-exchange-algorithms*)) ))
		   (assv spec supporting-suites))
		 => (^s
		     (set! (~ socket 'session 'cipher-suite) (car s))))
		(else (loop (+ i 2)))))))
    (define (send-server-hello)
      (let1 random (make-tls-random (read-random-bytes (~ socket 'prng) 28))
	(set! (~ socket 'session 'server-random) random)
	(tls-socket-send-inner socket
	 (make-tls-handshake *server-hello*
	  (make-tls-server-hello
	   :version (~ socket 'session 'version)
	   :random random
	   :session-id (make-variable-vector 1 (~ socket 'session 'session-id))
	   :cipher-suite (~ socket 'session 'cipher-suite)
	   ;; no compression
	   :compression-method 0))
	 0 *handshake* #f)))
    (define (send-certificate)
      (tls-socket-send-inner socket
       (make-tls-handshake *certificate*
	(make-tls-certificate (~ socket 'certificates)))
       0 *handshake* #f))
    (define (send-server-key-exchange)
      (define (sign-param socket params)
	(define (get-param s&a lists kar )
	  (let loop ((lists lists))
	    (cond ((null? lists) #f)
		  ((null? s&a) #f)
		  ((= (kar (car s&a)) (caar lists)) (car lists))
		  (else (loop (cdr lists))))))
	(let ((data (bytevector-append
		     (random->bytevector (~ socket 'session 'client-random)
					 (~ socket 'session 'server-random))
		     (tls-packet->bytevector params)))
	      (key (~ socket 'private-key)))
	  (if (= (~ socket 'session 'version) *tls-version-1.2*)
	      ;; use first one
	      (let* ((s&a (~ socket 'session 'signature-algorithms))
		     (h (or (get-param s&a *supported-hashes* car) 
			    (let ((h (lookup-hash (~ socket 'session))))
			      (let loop ((h* *supported-hashes*))
				(if (eq? (cdar h*) h)
				    (cons (caar h*) h)
				    (loop (cdr h*)))))))
		     (c (or (get-param s&a *supported-signatures* cdr) 
			    (cons 1 RSA)))
		     (s-cipher (cipher (cdr c) key :block-type PKCS-1-EMSA))
		     ;; TODO create DigestInfo
		     (data (make-der-sequence 
			    (make-algorithm-identifier
			     (make-der-object-identifier (hash-oid (cdr h))))
			    (make-der-octet-string 
			     (hash (cdr h) data)))))
		(make-tls-signature-with-algorhtm
		 (car h) (car c)
		 (encrypt s-cipher 
			  (call-with-bytevector-output-port
			   (lambda (out) (der-encode data out))))))
	      (let ((md5 (hash MD5 data))
		    (sha (hash SHA-1 data))
		    (s-cipher (cipher RSA key :block-type PKCS-1-EMSA)))
		(make-tls-signature 
		 (encrypt s-cipher (bytevector-append md5 sha)))))))

      (let* ((prime  (random-prime (div (*dh-prime-size*) 8) 
				   :prng (~ socket 'prng)))
	     (a (bytevector->integer
		 (read-random-bytes (~ socket 'prng)
				    (- (div (bitwise-length prime) 8) 1))))
	     (params (if (is-dh? (~ socket 'session))
			 (make-tls-server-dh-params 
			  ;; dh-g 2 is ok?
			  (integer->bytevector prime)
			  (integer->bytevector +dh-g+)
			  ;; A = g^a mod p
			  (integer->bytevector (mod-expt +dh-g+ a prime)))
			 (implementation-restriction-violation 
			  'send-server-key-exchange 
			  "DH_RSA is not supported yet")))
	     (signature (and (~ socket 'private-key)
			     (sign-param socket params))))
	(set! (~ socket 'session 'params) params)
	(set! (~ socket 'session 'a) a)
#;
	(display (tls-packet->bytevector 	 
		  (make-tls-handshake *server-key-echange*
		    (make-tls-server-key-exchange params signature))))
;;	(newline)
	(tls-socket-send-inner socket
	 (make-tls-handshake *server-key-echange*
	  (make-tls-server-key-exchange 
	   params 
	   (if signature (tls-packet->bytevector signature) #vu8())))
	 0 *handshake* #f)))
    
    (define (send-certificate-request)
      (define (make-supports)
	(let lp1 ((s *supported-signatures*) (r '()))
	  (if (null? s)
	      (u8-list->bytevector (reverse! r))
	      (let lp2 ((h *supported-hashes*) (r r))
		(if (null? h)
		    (lp1 (cdr s) r)
		    (lp2 (cdr h) (cons* (caar s) (caar h) r)))))))
      (set! (~ socket 'session 'need-certificate?) #t)
      (let ((types (u8-list->bytevector (map car *supported-signatures*)))
	    (algos (if (>= (~ socket 'session 'version) *tls-version-1.2*)
		       (make-supports)
		       #f))
	    ;; we don't support certificate_authorities
	    (auth  #vu8(0)))
	(tls-socket-send-inner socket
	 (make-tls-handshake *certificate-request*
	  (if algos
	      (make-tls-certificate-request
	       (make-variable-vector 1 types)
	       (make-variable-vector 2 algos)
	       (make-variable-vector 2 auth))
	      (make-tls-certificate-request
	       (make-variable-vector 1 types)
	       (make-variable-vector 2 auth))))
	 0 *handshake* #f)))

    (define (process-certificate socket o)
      (define (same-issuer? peer auth)
	;; TODO check signature
	(equal? (x509-certificate-get-issuer-dn peer)
		(x509-certificate-get-subject-dn auth)))
      ;; TODO verify the chain
      (when (null? (~ o 'certificates))
	(tls-error 'process-certificate "no certificate" *bad-certificate*))
      (let1 peer-cert (car (~ o 'certificates))
	;; check if the certificate is in server authorities
	(or (exists (cut same-issuer? peer-cert <>)
		    (~ socket 'authorities))
	    (tls-error 'process-certificate "No CA signer to verify with"
		       *unknown-ca*))
	(set! (~ socket 'session 'authority) peer-cert)))

    (define (process-verify socket o)
      (let* ((session (~ socket 'session))
	     (message (~ session 'verify-message))
	     (signature (~ o 'signature 'signature)))
	(verify-message socket message signature)))

    (define (send-server-hello-done)
      (tls-socket-send-inner socket
       (make-tls-handshake *server-hello-done*
	(make-tls-server-hello-done))
       0 *handshake* #f))

    (define (process-client-key-exchange socket o)
      (let ((session (~ socket 'session))
	    (dh (~ o 'exchange-keys)))
	;; store client verify message hash if needed
	(unless (null? (~ socket 'authorities))
	  (let1 message (get-output-bytevector (~ session 'messages))
	    ;; we need this later so restore it
	    ;;(put-bytevector (~ session 'messages) message)
	    (set! (~ session 'verify-message) message)))
	(if (is-dh? session)
	    ;; Diffie-Hellman key exchange
	    ;; Ka = B^a mod p
	    ;; calculate client Yc
	    (let* ((Yc (bytevector->integer (~ dh 'dh-public 'value)))
		   (a  (~ socket 'session 'a))
		   (p  (bytevector->integer (~ session 'params 'dh-p))))
	      (let1 K (mod-expt Yc a p)
		(set! (~ session 'master-secret) 
		      (compute-master-secret session (integer->bytevector K)))))
	    (let* ((encrypted-pre-master-secret 
		    (~ dh 'pre-master-secret 'value))
		   (rsa-cipher (cipher RSA (~ socket 'private-key)))
		   (pre-master-secret 
		    (decrypt rsa-cipher encrypted-pre-master-secret)))
	      (set! (~ session 'master-secret)
		    (compute-master-secret session pre-master-secret))))))
    (define (send-server-finished)
      ;; send change cipher spec first
      (tls-socket-send-inner socket (make-tls-change-cipher-spec #x01)
			     0 *change-cipher-spec* #f)
      (let* ((session (~ socket 'session))
	     (out (~ session 'messages))
	     (handshake-messages (extract-output-bytevector out))
	     (client-finished (~ session 'client-finished)))
	(set! (~ session 'client-finished) #f) ;; for GC
	(tls-socket-send-inner socket
	 (make-tls-handshake *finished*
	  (make-tls-finished 
	   (finish-message-hash session
	    *server-finished-label* 
	    (bytevector-concat handshake-messages client-finished))))
	 0 *handshake* #t)))
    (let ((hello (read-record socket 0)))
      (unless (tls-client-hello? hello)
	(tls-error 'tls-server-handshake
		   "unexpected packet was sent!" *unexpected-message* hello))
      (process-client-hello! hello)
      (send-server-hello)
      (send-certificate)
      (when (is-dh? (~ socket 'session))
	(send-server-key-exchange))
      (unless (null? (~ socket 'authorities))
	(send-certificate-request))
      ;; TODO send DH param if we need.
      (send-server-hello-done)
      ;; wait for client
      ;; TODO verify certificate if the client sends.
      (let1 need-certificate? (~ socket 'session 'need-certificate?)
	(let loop ((first #t) (after-key-exchange #f))
	  (let1 o (read-record socket 0)
	    (when (and first need-certificate? (not (tls-certificate? o)))
	      (tls-error 'tls-server-handshake "certificates are required"
			 *unexpected-message* o))
	    (if (tls-finished? o)
		(and (verify-mac socket o *client-finished-label* #t)
		     (send-server-finished))
		(cond ((tls-change-cipher-spec? o)
		       (calculate-session-key socket)
		       (set! (~ socket 'session 'session-encrypted?) #t)
		       (loop #f after-key-exchange))
		      ((tls-certificate? o)
		       (process-certificate socket o)
		       (loop #f after-key-exchange))
		      ((tls-client-veify? o)
		       (unless after-key-exchange
			 (tls-error 'tls-server-socket "invalid packet"
				    *unexpected-message* o))
		       (process-verify socket o)
		       (loop #f after-key-exchange))
		      ((tls-client-key-exchange? o)
		       (process-client-key-exchange socket o) 
		       (loop #f #t))
		      ;; ignore?
		      ((and (%tls-alert? o)
			    (= (~ o 'level) *warning*))
		       (loop #f after-key-exchange))
		      (else
		       (tls-error 'tls-server-handshake "unexpected object"
				  *unexpected-message* o)))))))))

  (define (%make-tls-client-socket raw-socket :key
				   (prng (secure-random RC4))
				   (version *tls-version-1.2*)
				   (session #f)
				   (cipher-suites *cipher-suites*)
				   (certificates '())
				   (private-key #f)
				   :allow-other-keys)
    (make <tls-client-socket> :raw-socket raw-socket
	  :version version :prng prng
	  :cipher-suites cipher-suites
	  :certificates certificates
	  :private-key private-key
	  :session (if session
		       session
		       (make-initial-session prng <tls-client-session>))))
  (define (make-client-tls-socket server service :key
				  (prng (secure-random RC4))
				  (version *tls-version-1.2*)
				  (session #f)
				  (handshake #t)
				  (cipher-suites *cipher-suites*)
				  (certificates '())
				  (private-key #f)
				  (hello-extensions '())
				  :allow-other-keys opt)
    (let* ((raw-socket (apply make-client-socket server service opt))
	   (socket (%make-tls-client-socket raw-socket
					    :prng prng
					    :version version
					    :session session
					    :cipher-suites cipher-suites
					    :certificates certificates
					    :private-key private-key)))
      (if handshake
	  (tls-client-handshake socket 
	   ;; user might want to use own SNI so do like this for now.
	   :hello-extensions (if (null? hello-extensions)
				 (list (make-server-name-indication 
					(list server)))
				 hello-extensions))
	  socket)))

  (define (make-hello-extension type data)
    (make-tls-extension type (make-variable-vector 2 data)))

  (define (make-server-name-indication names)
    (let1 names (map (^n (make-tls-server-name *host-name* n)) names)
      (make-tls-extension *server-name* (make-tls-server-name-list names))))
  (define (make-protocol-name-list names)
    (let1 names (map (^n (make-tls-protocol-name n)) names)
      (make-tls-extension *application-layer-protocol-negotiation*
			  (make-tls-protocol-name-list names))))

  (define (socket->tls-socket socket :key (client-socket #t)
			      :allow-other-keys opt)
    (if client-socket
	(apply %make-tls-client-socket socket opt)
	(apply %make-tls-server-socket socket opt)))

  (define (finish-message-hash session label handshake-messages)
    (PRF session 12 ;; For 1.2 check cipher
	 (~ session 'master-secret) label
	 (if (< (~ session 'version) *tls-version-1.2*)
	     ;; use md5 + sha1
	     (bytevector-concat (hash MD5 handshake-messages)
				(hash SHA-1 handshake-messages))
	     (let1 algo (session-signature-algorithm session #t)
	       ;; TODO I'm not sure this is correct or not
	       (hash algo handshake-messages)))))

  (define (tls-client-handshake socket :key (hello-extensions '()))
    (guard (e (else (handle-error socket e)))
      (%tls-client-handshake socket hello-extensions)
      socket))

  (define (%tls-client-handshake socket hello-extensions)
    (define (process-server-hello socket sh)
      (let1 session (~ socket 'session)
	(set! (~ session 'session-id) (~ sh 'session-id))
	(let1 version (~ sh 'version)
	  (when (or (< version *tls-version-1.0*)
		    (> version *tls-version-1.2*))
	    (tls-error 'tls-handshake "non supported TLS version" 
		       *protocol-version* version))
	  (set! (~ session 'version) version))
	(set! (~ session 'server-random) (~ sh 'random))
	(set! (~ session 'cipher-suite) (~ sh 'cipher-suite))
	(set! (~ session 'methods) (~ sh 'compression-method))
	;; should this be socket level?
	(set! (~ socket 'extensions) (~ sh 'extensions))))

    (define (process-server-key-exchange socket ske)
      (define (bytevector->signature socket bv)
	(if (= (~ socket 'session 'version) *tls-version-1.2*)
	    ;; with info
	    (let ((hash (bytevector-u8-ref bv 0))
		  (algo (bytevector-u8-ref bv 1)))
	      ;; now it's variable vector, length(2byte) + content
	      (make-tls-signature-with-algorhtm hash algo
						(bytevector-copy bv 4)))
	    (make-tls-signature (bytevector-copy bv 2))))
      ;; TODO check if client certificate has suitable key.
      (let1 session (~ socket 'session)
	(if (is-dh? session)
	    ;; Diffie-Hellman key exchange
	    ;; A = g^a mod p
	    ;; B = g^b mod p
	    ;; Ka = B^a mod p
	    ;; Kb = A^b mod p
	    ;; calculate client Yc
	    (let* ((dh (~ ske 'params))
		   (g (bytevector->integer (~ dh 'dh-g)))
		   (p (bytevector->integer (~ dh 'dh-p)))
		   ;; b must be 0 <= b <= p-2
		   ;; so let me take (- (div (bitwise-length p) 8) 1)
		   ;; ex) if 1024 bit p, then b will be 1016
		   (b (bytevector->integer
		       (read-random-bytes (~ socket 'prng) 
					  (- (div (bitwise-length p) 8) 1))))
		   ;; A
		   (Ys (bytevector->integer (~ dh 'dh-Ys)))
		   ;; B
		   (Yc (mod-expt g b p)))
	      ;; check signature
	      (unless (memv (~ session 'cipher-suite)
			    *dh-anon-key-exchange-algorithms*)
		;; construct message
		(let ((signature (~ ske 'signed-params))
		      (data (bytevector-append
			     (random->bytevector (~ session 'client-random)
						 (~ session 'server-random))
			     (tls-packet->bytevector dh))))
		  (verify-message socket data 
				  (bytevector->signature socket signature))))
		  
	      (set! (~ session 'params) 
		    (make <dh-params> :p p :g g :Ys Ys :Yc Yc))
	      ;; compute master secret
	      (let1 K (mod-expt Ys b p)
		(set! (~ session 'master-secret) 
		      (compute-master-secret session (integer->bytevector K)))))
	    ;; TODO RSA?
	    )))

    (define (process-certificate socke tls-certs)
      ;; the first certificate is the server certificate and the rest 
      ;; are chain.
      ;; TODO verify certificates and root CA
      (let ((session (~ socket 'session))
	    (cert (car (~ tls-certs 'certificates))))
	(set! (~ session 'public-key) (x509-certificate-get-public-key cert))))

    (define (make-rsa-key-exchange socket)
      (let* ((session (~ socket 'session))
	     (pre-master-secret (make-bytevector 48))
	     (key (~ session 'public-key)))
	(bytevector-u16-set! pre-master-secret 0 
			     ;; we need to use offered version
			     (~ socket 'version) 'big)
	(bytevector-copy! (read-random-bytes (~ socket 'prng) 46) 0
			  pre-master-secret 2 46)
	(let* ((rsa-cipher (cipher RSA key))
	       (encrypted (encrypt rsa-cipher pre-master-secret)))
	  ;; calculate client master_secret here to avoid unnecessary allocation
	  (set! (~ session 'master-secret) 
		(compute-master-secret session pre-master-secret))
	  (make-tls-handshake *client-key-exchange*
	   (make-tls-client-key-exchange 
	    (make-tls-encrypted-pre-master-secret 
	     (make-variable-vector 2 encrypted)))))))

    (define (make-dh-key-exchange socket)
      (let1 Yc (~ socket 'session 'params 'Yc)
	(make-tls-handshake *client-key-exchange*
	 (make-tls-client-key-exchange
	  (make-tls-client-diffie-hellman-public 
	   (make-variable-vector 2 (integer->bytevector Yc)))))))

    (define (make-client-certificate socket)
      (make-tls-handshake *certificate*
       (make-tls-certificate (~ socket 'certificates))))

    (define (make-client-verify socket)
      (let* ((session (~ socket 'session))
	     (in (~ session 'messages))
	     (position (port-position in))
	     (message (extract-output-bytevector in)))
	(define (handle-1.1 rsa-cipher message)
	  (make-tls-signature
	   (encrypt rsa-cipher
		    (bytevector-concat (hash MD5 message)
				       (hash SHA-1 message)))))
	(define (handle-1.2 rsa-cipher message)
	  (define (encode-signature signature oid)
	    (asn.1:encode
	     (make-der-sequence
	      (make-der-sequence
	       (make-der-object-identifier oid)
	       (make-der-null))
	      (make-der-octet-string signature))))
	  ;; For now only supports RSA and SHA-1
	  (let* ((hash-algo (~ session 'hash-algorithm))
		 (hash-name (cdr hash-algo))
		 (sign (~ session 'signature-algorithm)))
	    ;; We know we only support RSA so we don't check cipher.
	    (make-tls-signature-with-algorhtm
	     (car hash-algo) (car sign)
	     (encrypt rsa-cipher (encode-signature (hash hash-name message)
						   (hash-oid hash-name))))))
	;; restore
	(put-bytevector in message)
	(make-tls-handshake *certificate-verify*
	 (make-tls-client-verify
	  ;; TODO get it from cipher-suite
	  (let1 rsa-cipher (cipher RSA (~ socket 'private-key)
				   ;; block type 1
				   :block-type PKCS-1-EMSA)
	    ;; use encrypt not sign
	    (if (< (~ session 'version) *tls-version-1.2*)
		(handle-1.1 rsa-cipher message)
		(handle-1.2 rsa-cipher message)))))))

    (define (process-certificate-request socket o)
      (define-syntax u8-ref (identifier-syntax bytevector-u8-ref))
      (let1 session (~ socket 'session)
	(set! (~ session 'need-certificate?) #t)
	;; FIXME the code trusts server, assuming proper message was sent.
	(when (~ o 'supported-signature-algorithms)
	  (let* ((algos (~ o 'supported-signature-algorithms 'value))
		 (limit (bytevector-length algos)))
	    (let loop ((i 0))
	      (if (= i limit)
		  (tls-error 'process-certificate-request
			     "hash or signature algorithm are not supported"
			     *handshake-failure*)
		  (let ((hash (assv (u8-ref algos i) *supported-hashes*))
			(sign (assv (u8-ref algos (+ i 1))
				    *supported-signatures*)))
		    (if (and hash sign)
			(begin
			  (set! (~ session 'signature-algorithm) sign)
			  (set! (~ session 'hash-algorithm) hash))
			(loop (+ i 2))))))))))

    (define (wait-and-process-server socket)
      (let1 session (~ socket 'session)
	(let loop ((o (read-record socket 0)))
	  ;; finished or server-hello-done is the marker
	  (cond ((tls-server-hello-done? o) #t)
		((tls-finished? o)
		 (verify-mac socket o *server-finished-label* #f))
		(else
		 (cond ((tls-server-hello? o)
			(process-server-hello socket o))
		       ((tls-certificate? o)
			(process-certificate socket o))
		       ((tls-server-key-exchange? o)
			(process-server-key-exchange socket o))
		       ;; TODO
		       ((tls-certificate-request? o)
			(process-certificate-request socket o))
		       ((tls-change-cipher-spec? o)
			(set! (~ session 'session-encrypted?) #t))
		       ((and (%tls-alert? o)
			     (= (~ o 'level) *warning*)))
		       (else
			(tls-error 'tls-handshake "unexpected object"
				   *unexpected-message* o)))
		 (loop (read-record socket 0)))))))
    
    (let ((hello (make-client-hello socket hello-extensions))
	  (session (~ socket 'session)))
      (tls-socket-send-inner socket hello 0 *handshake* #f)
      (wait-and-process-server socket)
      ;; If server send CertificateRequest
      (when (~ session 'need-certificate?)
	(tls-socket-send-inner socket (make-client-certificate socket)
			       0 *handshake* #f))
      ;; client key exchange message
      (tls-socket-send-inner socket 
			     (if (is-dh? session)
				 (make-dh-key-exchange socket)
				 (make-rsa-key-exchange socket))
			     0 *handshake* #f)

      ;; send certificate verify.
      (when (and (~ session 'need-certificate?)
		 (~ socket 'private-key)
		 (not (null? (~ socket 'certificates))))
	(tls-socket-send-inner socket (make-client-verify socket)
			       0 *handshake* #f))

      ;; Change cipher spec
      ;; we need to change session state to *change-cipher-spec*
      (tls-socket-send-inner socket (make-tls-change-cipher-spec #x01)
			     0 *change-cipher-spec* #f)

      ;; finish
      (let* ((out (~ session 'messages))
	     (handshake-messages (get-output-bytevector out)))
	;;(display handshake-messages) (newline)
	;; add message again
	;;(put-bytevector out handshake-messages)
	(tls-socket-send-inner socket
	 (make-tls-handshake *finished*
	  (make-tls-finished (finish-message-hash session
						  *client-finished-label*
						  handshake-messages)))
	 0 *handshake* #t))
      (wait-and-process-server socket)))

  (define (dump-all-handshake-messages msg dh? v)
    (let1 in (open-bytevector-input-port msg)
      (let loop ()
	(let-values (((_ o) (read-handshake in dh? v)))
	  (when o
	    (display o) (newline)
	    (loop))))))

  ;; internals
  (define-constant *master-secret-label* (string->utf8 "master secret"))
  (define-constant *client-finished-label* (string->utf8 "client finished"))
  (define-constant *server-finished-label* (string->utf8 "server finished"))
  (define-constant *key-expansion-label* (string->utf8 "key expansion"))

  (define (session-signature-algorithm session consider-version?)
    (let ((version (~ session 'version))
	  (cipher-suite (~ session 'cipher-suite)))
      (or (and-let* ((algorithm (lookup-hash session)))
	    (if consider-version?
		;; we need to use SHA-256 if the version is 1.2
		(if (= version *tls-version-1.2*)
		    SHA-256
		    algorithm)
		algorithm))
	  (tls-error 'session-signature-algorithm
		     "non supported cipher suite detected"
		     *handshake-failure*
		     cipher-suite))))

  (define (bytevector-concat bv1 bv2)
    (let* ((len1 (bytevector-length bv1))
	   (len2 (bytevector-length bv2))
	   (r (make-bytevector (+ len1 len2))))
      (bytevector-copy! bv1 0 r 0 len1)
      (bytevector-copy! bv2 0 r len1 len2)
      r))
  (define (PRF session len secret label seed)
    (define (p-hash hmac seed)
      (let* ((r (make-bytevector len))
	     (size (hash-size hmac))
	     (buf  (make-bytevector size))
	     (count (ceiling (/ len size))))
	(let loop ((i 1) (offset 0) (A1 (hash hmac seed)))
	  (hash! hmac buf (bytevector-concat A1 seed))
	  (cond ((= i count)
		 (bytevector-copy! buf 0 r offset (- len offset))
		 r)
		(else
		 (bytevector-copy! buf 0 r offset size)
		 (loop (+ i 1) (+ offset size) (hash hmac A1)))))))

    (if (< (~ session 'version) *tls-version-1.2*)
	;; TODO for odd, must be one longer (S2)
	(let* ((len (ceiling (/ (bytevector-length secret) 2)))
	       (S1 (bytevector-copy secret 0 len))
	       (S2 (bytevector-copy secret len)))
	  (bytevector-xor
	   (p-hash (hash-algorithm HMAC :key S1 :hash MD5)
		   (bytevector-concat label seed))
	   (p-hash (hash-algorithm HMAC :key S2 :hash SHA-1)
		   (bytevector-concat label seed))))
	(let1 algo (session-signature-algorithm session #t)
	  (p-hash (hash-algorithm HMAC :key secret :hash algo)
		  (bytevector-concat label seed)))))
  
  ;; this can be used by both client and server, if we support server socket...
  (define (compute-master-secret session pre-master-secret)
    (PRF session
	 48
	 pre-master-secret
	 *master-secret-label*
	 (random->bytevector (~ session 'client-random)
			     (~ session 'server-random))))

  (define (read-record socket flags)
    (define (get-decrypt-cipher session)
      (cond ((~ session 'decrypt-cipher))
	    (else
	     (let* ((cipher&keysize (lookup-cipher&keysize session))
		    (session-key (~ session 'session-key))
		    (read-key (generate-secret-key (car cipher&keysize)
						   (~ session-key 'read-key)))
		    (iv (~ session-key 'read-iv))
		    (c (cipher (car cipher&keysize) read-key
			       ;; we can not use pkcs5padding
			       :padder #f
			       :iv iv :mode MODE_CBC)))
	       (slot-set! session 'decrypt-cipher c)
	       ;; reset some of data
	       (set! (~ session-key 'read-key) #f)
	       (set! (~ session-key 'read-iv) #f)
	       c))))
    (define (decrypt-data session em type)
      (let* ((decrypt-cipher (get-decrypt-cipher session))
	     (message (decrypt decrypt-cipher em))
	     (algo (lookup-hash session))
	     (size (hash-size algo))
	     (len  (bytevector-length message))
	     ;; this must have data, MAC and padding
	     (pad-len (bytevector-u8-ref message (- len 1)))
	     (mac-offset (- len pad-len size 1))
	     (mac  (bytevector-copy message mac-offset (- len pad-len 1)))
	     (data-offset (if (>= (~ session 'version) *tls-version-1.1*)
			      (cipher-blocksize decrypt-cipher)
			      0))
	     (data (bytevector-copy message data-offset mac-offset)))
	;; verify HMAC from server
	(unless (bytevector=? mac (calculate-read-mac
				   socket type
				   (~ session 'version) data))
	  ;; TODO should we send alert to the server?
	  (tls-error 'decrypt-data "MAC verification failed" *bad-record-mac*))
	;; TODO what should we do with iv?
	data))

    (define (recv-n size raw-socket)
      (call-with-bytevector-output-port
       (lambda (p)
	 (let loop ((read-length 0)
		    (diff size))
	   (unless (= read-length size)
	     (let* ((buf (socket-recv raw-socket diff flags))
		    (len (bytevector-length buf)))
	       (put-bytevector p buf)
	       (loop (+ read-length len) (- diff len))))))))

    ;; todo what if the record has more than 1 application data?
    (define (read-record-rec socket session type in)
      (set! (~ session 'last-record-type) type)
      (rlet1 record (cond ((= type *handshake*)
			   (let-values (((message record)
					 (read-handshake in (is-dh? session)
							 (~ session 'version))))
			     ;; for Finish message
			     (let1 type (bytevector-u8-ref message 0)
			       (when (and (not (= type *finished*))
					  (not (= type *hello-request*)))
				 (put-bytevector (~ session 'messages) message))
			       ;; save client finished
			       ;; FIXME this is really ugly ...
			       (when (and (is-a? session <tls-server-session>)
					  (= type *finished*))
				 (set! (~ session 'client-finished) message)))
			     record))
			  ((= type *alert*)
			   (let1 alert (read-alert in)
			     (cond ((= *close-notify* (~ alert 'description))
				    ;; session closed
				    ;;(set! (~ session 'closed?) #t)
				    ;; we don't support reconnect
				    ;; so just close socket.
				    (tls-socket-shutdown socket SHUT_RDWR)
				    (%tls-socket-close socket)
				    ;; user wants application data
				    #vu8())
				   (else alert))))
			  ((= type *change-cipher-spec*)
			   (read-change-cipher-spec in))
			  (else
			   (tls-error 'read-record "not supported yet" 
				      *unexpected-message* type)))
	(if (eof-object? (lookahead-u8 in))
	    (set! (~ session 'buffer) #f)
	    (set! (~ session 'buffer) in))))

    (let1 session (~ socket 'session)
      (if (~ session 'buffer)
	  ;; there are still something to read in the buffer
	  ;; TODO does this happen after handshake?
	  (read-record-rec socket session
			   (~ session 'last-record-type) 
			   (~ session 'buffer))
	  ;; analyse the record
	  ;; when the socket is nonblocking then socket-recv may return
	  ;; #f instead of empty bytevector. In that case we need to return
	  ;; #f as this procedure's result so that caller can know the
	  ;; socket isn't ready yet.
	  (and-let* ((raw-socket (~ socket 'raw-socket))
		     ;; the first 5 octets must be record header
		     (buf (socket-recv raw-socket 5 flags)))
	    (define (check-length buf)
	      (or (= (bytevector-length buf) 5)
		  (tls-error 'read-record "invalid record header"
			     *unexpected-message* buf)))
	    ;; socket-recv may return zero length bytevector
	    ;; to indicate end of stream. we need to check it
	    (or (and-let* (( (not (zero? (bytevector-length buf))) )
			   ( (check-length buf) )
			   (type (bytevector-u8-ref buf 0))
			   (version (bytevector-u16-ref buf 1 'big))
			   (size-bv (bytevector-copy buf 3))
			   (size    (bytevector->integer size-bv))
			   (message (recv-n size raw-socket)))
		  (unless (= size (bytevector-length message))
		    (tls-error 'read-record
			       "given size and actual data size is different"
			       *unexpected-message*
			       size (bytevector-length message)))
		  (when (~ session 'session-encrypted?)
		    ;; okey now we are in the secured session
		    (set! message (decrypt-data session message type))
		    ;; we finally read all message from the server now is the
		    ;; time to maintain read sequence number
		    (set! (~ session 'read-sequence)
			  (+ (~ session 'read-sequence) 1)))
		  (if (= type *application-data*)
		      message
		      (let1 in (open-bytevector-input-port message)
			(read-record-rec socket session type in))))
		#vu8())))))

  (define (read-variable-vector in n)
    (let* ((size (case n
		   ((1) (get-u8 in))
		   ((2) (get-u16 in (endianness big)))
		   ((4) (get-u32 in (endianness big)))
		   ;; should never reach
		   (else (bytevector->integer (get-bytevector-n in n)))))
	   (body (get-bytevector-n in size)))
      (make-variable-vector n (if (eof-object? body) #vu8() body))))

  (define (read-change-cipher-spec in)
    (let1 type (get-u8 in)
      (unless (= type 1)
	(tls-error 'read-change-cipher-spec
		   "invalid change cipher spec" *unexpected-message*))
      (make-tls-change-cipher-spec type)))

  (define (read-alert in)
    (let ((level (get-u8 in))
	  (description (get-u8 in)))
      (make-tls-alert level description)))

  ;; for now
  (define (check-key-exchange-algorithm suite set) (memv suite set))
  (define (is-dh? session)
    (or (check-key-exchange-algorithm (~ session 'cipher-suite)
				      *dh-key-exchange-algorithms*)
	(check-key-exchange-algorithm (~ session 'cipher-suite)
				      *dh-anon-key-exchange-algorithms*)))
  (define (read-handshake in dh? version)

    (define (read-random in)
      (let ((time (get-u32 in (endianness big)))
	    (bytes (get-bytevector-n in 28)))
	(make-tls-random bytes time)))

    (define (read-extensions in)
      (define (read-extension in)
	(let ((type (get-u16 in (endianness big)))
	      (data (read-variable-vector in 2)))
	  (make-tls-extension type data)))
      (and-let* (( (not (eof-object? (lookahead-u8 in))) )
		 (len (get-u16 in (endianness big))))
	(call-with-port (->size-limit-binary-input-port in len)
	  (lambda (in)
	    (let loop ((exts '()))
	      (if (eof-object? (lookahead-u8 in))
		  exts
		  (loop (cons (read-extension in) exts))))))))

    (define (read-client-hello in)
      (let* ((version (get-u16 in (endianness big)))
	     (random  (read-random in))
	     (session-id (read-variable-vector in 1))
	     (cipher-suites (read-variable-vector in 2))
	     (compression-methods (read-variable-vector in 1))
	     (extensions (read-extensions in)))
	(unless (eof-object? (lookahead-u8 in))
	  (tls-error 'read-client-hello
		     "could not read client-hello properly."
		     *unexpected-message*))
	(make-tls-client-hello :version version
			       :random random
			       :session-id session-id
			       :cipher-suites cipher-suites
			       :compression-methods compression-methods
			       :extensions extensions)))

    (define (read-server-key-exchange in)
      ;; check key algorithm
      (if dh?
	  (let ((p (read-variable-vector in 2))
		(g (read-variable-vector in 2))
		(ys (read-variable-vector in 2))
		;; the rest must be signature
		(signature (get-bytevector-all in)))
	    ;; TODO check signature if server sent certificate
	    (make-tls-server-key-exchange
	     (make-tls-server-dh-params 
	      (~ p 'value)  (~ g 'value) (~ ys 'value))
	     signature))
	  ;; must be RSA
      	  (let ((rsa-modulus (read-variable-vector in 2))
		(rsa-exponent (read-variable-vector in 2))
		;; the rest must be signature ...
		(signature (get-bytevector-all in)))
	    (make-tls-server-key-exchange
	     (make-tls-server-rsa-params rsa-modulus rsa-exponent)
	     signature))))

    (define (read-server-hello in)
      (let* ((version (get-u16 in (endianness big)))
	     (random  (read-random in))
	     (session-id (read-variable-vector in 1))
	     (cipher-suite (get-u16 in (endianness big)))
	     (compression-method (get-u8 in))
	     (extensions (read-extensions in)))
	(unless (eof-object? (lookahead-u8 in))
	  (tls-error 'read-server-hello
		     "could not read server-hello properly."
		     *unexpected-message*))
	(make-tls-server-hello :version version
			       :random random
			       :session-id session-id
			       :cipher-suite cipher-suite
			       :compression-method compression-method
			       :extensions extensions)))
    (define (read-client-key-exchange in)
      (let* ((body (get-bytevector-all in)))
	(make-tls-client-key-exchange
	 ((if dh? 
	      make-tls-client-diffie-hellman-public
	      make-tls-encrypted-pre-master-secret)
	  (read-variable-vector (open-bytevector-input-port body) 2)))))

    (define (read-certificate in)
      ;; we don't check the length, i trust you...
      (let1 total-length (get-u24 in (endianness big))
	(let loop ((i 0) (certs '()) (read-size 0))
	  (if (eof-object? (lookahead-u8 in))
	      (make-tls-certificate (reverse! certs))
	      (let* ((size (get-u24 in (endianness big)))
		     (body (get-bytevector-n in size))
		     (cert (make-x509-certificate body)))
		(loop (+ i 1) (cons cert certs) (+ read-size size)))))))

    (define (read-certificate-request in)
      (let ((types (read-variable-vector in 1))
	    (name-or-algo  (read-variable-vector in 2))
	    (maybe-name (and (not (eof-object? (lookahead-u8 in)))
			     (read-variable-vector in 2))))
	(if maybe-name
	    (make-tls-certificate-request types name-or-algo maybe-name)
	    (make-tls-certificate-request types name-or-algo))))

    (define (read-certificate-verify in)
      (if (>= version *tls-version-1.2*)
	  (let ((hash (get-u8 in))
		(sign (get-u8 in))
		(signature (read-variable-vector in 2)))
	    (make-tls-client-verify
	     (make-tls-signature-with-algorhtm hash sign 
					       (~ signature 'value))))
	  (make-tls-client-verify
	   (make-tls-signature
	    (~ (read-variable-vector in 2) 'value)))))

    (define (read-finished in) (make-tls-finished (get-bytevector-all in)))

    (or
     (and-let* ((type (get-u8 in))
		( (integer? type) )
		(size (get-u24 in (endianness big)))
		(body (get-bytevector-n in size)))
       (unless (or (zero? size) (= size (bytevector-length body)))
	 (tls-error 'read-handshake
		    "given size and actual data size is different"
		    *unexpected-message* size))
       (let1 record
	   (cond ((= type *hello-request*) (make-tls-hello-request))
		 ((= type *client-hello*)
		  (read-client-hello (open-bytevector-input-port body)))
		 ((= type *server-hello*)
		  (read-server-hello (open-bytevector-input-port body)))
		 ((= type *certificate*)
		  (read-certificate (open-bytevector-input-port body)))
		 ((= type *server-key-echange*)
		  (read-server-key-exchange (open-bytevector-input-port body)))
		 ((= type *server-hello-done*)
		  (make-tls-server-hello-done))
		 ((= type *client-key-exchange*)
		  (read-client-key-exchange (open-bytevector-input-port body)))
		 ((= type *certificate-request*)
		  (read-certificate-request (open-bytevector-input-port body)))
		 ((= type *certificate-verify*)
		  (read-certificate-verify (open-bytevector-input-port body)))
		 ((= type *finished*)
		  (read-finished (open-bytevector-input-port body)))
		 (else
		  (tls-error 'read-handshake
			     "not supported" *unexpected-message* type)))
	 (let1 bv (make-bytevector 4)
	   (bytevector-u32-set! bv 0 size (endianness big))
	   (bytevector-u8-set! bv 0 type)
	   (values (bytevector-append bv body) record))))
     (values #vu8() #f)))

  (define (lookup-cipher&keysize session)
    (and-let* ((suite (assv (~ session 'cipher-suite) *cipher-suites*)))
      (caddr suite)))
  (define (lookup-hash session)
    (and-let* ((suite (assv (~ session 'cipher-suite) *cipher-suites*)))
      (cadddr suite)))

  (define (random->bytevector random1 random2)
    (call-with-bytevector-output-port 
      (lambda (p) (write-tls-packet random1 p) (write-tls-packet random2 p))))
  ;; dummy
  (define (exportable? session) #f)

  (define (dump-hex bv :optional (title #f))
    (when title (display title)(newline))
    (let1 len (bytevector-length bv)
      (format #t "length ~d~%" len)
      (dotimes (i len)
	(format #t "~2,'0X " (bytevector-u8-ref bv i))
	(when (zero? (mod (+ i 1) 16))
	  (newline)))
      (newline)))

  (define (calculate-session-key socket)
    (define (process-key-block! key-block session-key
				keysize blocksize hashsize
				client?)
      #|
       client_write_MAC_secret[SecurityParameters.hash_size]
       server_write_MAC_secret[SecurityParameters.hash_size]
       client_write_key[SecurityParameters.key_material_length]
       server_write_key[SecurityParameters.key_material_length]
       client_write_IV[SecurityParameters.IV_size]
       server_write_IV[SecurityParameters.IV_size]
      |#
      (let1 slot-set (if client?
			 `((write-mac-secret . ,hashsize)
			   (read-mac-secret . ,hashsize)
			   (write-key . ,keysize)
			   (read-key . ,keysize)
			   (write-iv . ,blocksize)
			   (read-iv . ,blocksize))
			 `((read-mac-secret . ,hashsize)
			   (write-mac-secret . ,hashsize)
			   (read-key . ,keysize)
			   (write-key . ,keysize)
			   (read-iv . ,blocksize)
			   (write-iv . ,blocksize)))
	(let loop ((offset 0) (set slot-set))
	  (unless (null? set)
	    (let1 end (+ offset (cdar set))
	      (set! (~ session-key (caar set))
		    (bytevector-copy key-block offset end))
	      (loop end (cdr set)))))))

    (let* ((session        (~ socket 'session))
	   (cipher&keysize (lookup-cipher&keysize session))
	   (keysize        (cdr cipher&keysize))
	   (dummy (cipher (car cipher&keysize)
			  (generate-secret-key
			   (car cipher&keysize)
			   (make-bytevector keysize))))
	   (blocksize      (cipher-blocksize dummy)) ;; iv-size
	   (hash           (lookup-hash session))
	   (hashsize       (hash-size hash))
	   (block-size     (* 2 (+ keysize hashsize blocksize)))
	   (key-block      (PRF session block-size
				(~ session 'master-secret)
				*key-expansion-label*
				(random->bytevector
				 (~ session 'server-random)
				 (~ session 'client-random))))
	   (session-key    (make <session-key>)))
      (process-key-block! key-block session-key keysize blocksize hashsize
			  (not (is-a? socket <tls-server-socket>)))
      (set! (~ session 'session-key) session-key)
      session-key))

  (define (calculate-mac session type version seq secret-deriver body)
    (let* ((algo (hash-algorithm HMAC :key (secret-deriver session)
				 :hash (lookup-hash session)))
	   (bv (make-bytevector (hash-size algo))))
      (hash! algo bv 
	     (let1 data
		 (call-with-bytevector-output-port
		  (lambda (p)
		    (put-u64 p (~ session seq) (endianness big))
		    (put-u8 p type)
		    (put-u16 p version (endianness big))
		    (put-u16 p (bytevector-length body) (endianness big))
		    (put-bytevector p body)))
	       data))
      bv))

  (define (calculate-write-mac socket type version body)
    (define (derive-write-mac-secret session)
      (let1 session-key (~ session 'session-key)
	(unless session-key
	  (calculate-session-key socket)
	  (set! session-key (~ session 'session-key)))
	(~ session-key 'write-mac-secret)))
    (calculate-mac (~ socket 'session) type version 'write-sequence
		   derive-write-mac-secret body))

  (define (calculate-read-mac socket type version body)
    (define (derive-read-mac-secret session)
      (let1 session-key (~ session 'session-key)
	;; if we reach here, means we must have session key
	(~ session-key 'read-mac-secret)))
    (calculate-mac (~ socket 'session) type version 'read-sequence
		   derive-read-mac-secret body))

  ;; until here the key-block must be calculated
;; these are not used...
;;   (define (derive-final-write-key session label)
;;     (let1 session-key (~ session 'session-key)
;;       (if (exportable? session)
;; 	  (or (and-let* ((key (~ session-key 'final-wirte-key)))
;; 		key)
;; 	      (let* ((keysize (lookup-cipher&keysize session))
;; 		     (key (PRF session (cdr keysize)
;; 			       (~ session-key 'write-key)
;; 			       label 
;; 			       (random->bytevector
;; 				(~ session 'client-random)
;; 				(~ session 'server-random)))))
;; 		(set! (~ session-key 'final-wirte-key) key)
;; 		key)))))
;; 
;;   (define (derive-final-read-key session label)
;;     (let1 session-key (~ session 'session-key)
;;       (if (exportable? session)
;; 	  (or (and-let* ((key (~ session-key 'final-read-key)))
;; 		key)
;; 	      (let* ((keysize (lookup-cipher&keysize session))
;; 		     (key (PRF session (cdr keysize)
;; 			       (~ session-key 'read-key)
;; 			       label 
;; 			       (random->bytevector
;; 				(~ session 'client-random)
;; 				(~ session 'server-random)))))
;; 		(set! (~ session-key 'final-read-key) key)
;; 		key))
;; 	  (~ session-key 'read-key))))
  
  ;; SSL/TLS send packet on record layer protocl
  (define (tls-socket-send socket data :optional (flags 0))
    (when (tls-socket-closed? socket)
      (assertion-violation 'tls-socket-send "tls socket is alredy closed"
			   socket))
    (tls-socket-send-inner socket data flags *application-data* #t)
    (bytevector-length data))

  (define (tls-socket-send-inner socket data flags type encrypt?)
    (define (calculate-padding cipher len)
      (let* ((block-size (cipher-blocksize cipher))
	     (size (- block-size (mod len block-size))))
	(make-bytevector size size)))

    (define (encrypt-data session version data)
      (define (get-encrypt-cipher)
	(cond ((~ session 'encrypt-cipher))
	      (else
	       (let* ((cipher&keysize (lookup-cipher&keysize session))
		      (session-key (~ session 'session-key))
		      (write-key (generate-secret-key 
				  (car cipher&keysize)
				  (~ session-key 'write-key)))
		      (iv (~ session-key 'write-iv))
		      (c (cipher (car cipher&keysize) write-key
				 ;; we need to pad by our self ... hmm
				 :padder #f
				 :iv iv :mode MODE_CBC)))
		 (slot-set! session 'encrypt-cipher c)
		 ;; reset some of data
		 (set! (~ session-key 'write-key) #f)
		 (set! (~ session-key 'write-iv) #f)
		 c))))
      ;; all toplevel data structures have the same slots.
      (let* ((body (if (= type *application-data*)
		       data
		       (call-with-bytevector-output-port
			(lambda (p)
			  (write-tls-packet data p)))))
	     (version (~ session 'version))
	     (hash-algo (lookup-hash session))
	     (mac (calculate-write-mac socket type version body))
	     (encrypt-cipher (get-encrypt-cipher))
	     (padding (calculate-padding encrypt-cipher
					 (+ (bytevector-length body)
					    (bytevector-length mac) 1)))
	     (em (encrypt encrypt-cipher
			  (call-with-bytevector-output-port
			   (lambda (p)
			     (when (>= (~ session 'version) *tls-version-1.1*)
			       ;; add IV
			       (put-bytevector p (cipher-iv encrypt-cipher)))
			     (put-bytevector p body)
			     (put-bytevector p mac)
			     (put-bytevector p padding)
			     (put-u8 p (bytevector-length padding)))))))
	(make-tls-ciphered-data em)))
    
    (let* ((session (~ socket 'session))
	   (version (negotiated-version socket))
	   (record (make-tls-record-layer type version
					  (if encrypt?
					      (encrypt-data session version
							    data)
					      data)))
	   (packet (call-with-bytevector-output-port
		    (lambda (p) (write-tls-packet record p)))))
      (when encrypt?
	(set! (~ session 'write-sequence) (+ (~ session 'write-sequence) 1)))
      (when (and (tls-handshake? data)
		 (not (tls-hello-request? (tls-handshake-body data))))
	(write-tls-packet data (~ session 'messages)))
      (let1 raw-socket (~ socket 'raw-socket)
	(socket-send raw-socket packet flags))))

  ;; this is only used from out side of the world, means the received message
  ;; is always application data.
  (define (tls-socket-recv socket size :optional (flags 0))
    (let* ((bv (make-bytevector size))
	   (r (tls-socket-recv! socket bv 0 size flags)))
      (cond ((not r) r) ;; non blocking socket
	    ((= r size) bv)
	    ((< r 0) #f) ;; non blocking?
	    (else (bytevector-copy bv 0 r)))))

  (define (tls-socket-recv! socket bv start len :optional (flags 0))
    (when (tls-socket-closed? socket)
      (assertion-violation 'tls-socket-recv! "tls socket is alredy closed"
			   socket))
    (with-exception-handler
     (lambda (e) (handle-error socket e))
     (lambda () (%tls-socket-recv socket bv start len flags))))

  (define (%tls-socket-recv socket bv start len flags)
    (or (and-let* ((in (~ socket 'buffer))
		   (r  (get-bytevector-n! in bv start len))
		   ( (not (eof-object? r)) ))
	  ;; if the actual read size was equal or less than the
	  ;; requires size the buffer is now empty so, we need 
	  ;;to set the slot #f
	  (when (< r len) (set! (~ socket 'buffer) #f))
	  r)
	(and-let* ((record (read-record socket flags))
		   ( (bytevector? record) )
		   (in (open-bytevector-input-port record)))
	  (set! (~ socket 'buffer) in)
	  (let ((r (get-bytevector-n! in bv start len)))
	    (if (eof-object? r) 0 r)))
	;; TODO check if the raw socket is nonblocking mode or not.
	;; (tls-error 'tls-socket-recv "invalid socket state" *internal-error*)
	))

  (define (%tls-socket-close socket)
    (when (~ socket 'raw-socket) (socket-close (~ socket 'raw-socket)))
    ;; if we don't have any socket, we can't reconnect
    (set! (~ socket 'raw-socket) #f)
    (set! (~ socket 'session 'closed?) #t))

  (define (tls-socket-close socket)
    ;; the combination of socket conversion and call-with-tls-socket
    ;; calls this twice and raises an error. so if the socket is
    ;; already closed, then we need not to do twice.
    (unless (tls-socket-closed? socket)
      (%tls-socket-close socket)))

  (define (tls-socket-shutdown socket how)
    (define (send-alert socket level description)
      (when (and (~ socket 'has-peer?)
		 (~ socket 'raw-socket)
		 (not (~ socket 'sent-shutdown?)))
	;; yet still this would happen, so ignore
	(guard (e (else #t))
	  (let1 alert (make-tls-alert level description)
	    (tls-socket-send-inner socket alert 0 *alert*
				   (~ socket 'session 'session-encrypted?))))))
    (when (~ socket 'raw-socket) ;; may already be handled
      (when (or (eqv? how SHUT_WR) (eqv? how SHUT_RDWR))
	;; close_notify
	;;    This message notifies the recipient that the sender will not send
	;;    any more messages on this connection.  Note that as of TLS 1.1,
	;;    failure to properly close a connection no longer requires that a
	;;    session not be resumed.  This is a change from TLS 1.0 to conform
	;;    with widespread implementation practice.
	;; so we send close_notify if the write side of socket is requested to
	;; shut down.
	(send-alert socket *warning* *close-notify*)
	(set! (~ socket 'sent-shutdown?) #t))
      (socket-shutdown (~ socket 'raw-socket) how)))

  ;; utilities
  (define (find-tls-extension type extensions)
    (let loop ((extensions extensions))
      (cond ((null? extensions) #f)
	    ((= type (~ (car extensions) 'type)) (car extensions))
	    (else (loop (cdr extensions))))))

  (define (call-with-tls-socket socket proc)
    (receive args (proc socket)
      (tls-socket-close socket)
      (apply values args)))

  (define (tls-socket-peer socket)
    (socket-peer (~ socket 'raw-socket)))
  (define (tls-socket-name socket)
    (socket-name (~ socket 'raw-socket)))
  (define (tls-socket-info socket)
    (socket-info (~ socket 'raw-socket)))
  (define (tls-socket-info-values socket :key (type 'peer))
    (socket-info-values (~ socket 'raw-socket) :type type))

  (define (tls-socket-nonblocking! socket) 
    (socket-nonblocking! (~ socket 'raw-socket)))
  (define (tls-socket-blocking! socket) 
    (socket-blocking! (~ socket 'raw-socket)))

  ;; to make call-with-socket available for tls-socket
  (define-method socket-close ((o <tls-socket>))
    (tls-socket-close o))
  (define-method socket-closed? ((o <tls-socket>))
    (tls-socket-closed? o))
  (define-method socket-shutdown ((o <tls-socket>) how)
    (tls-socket-shutdown o how))
  (define-method socket-send ((o <tls-socket>) data :optional (flags 0))
    (tls-socket-send o data flags))
  (define-method socket-recv ((o <tls-socket>) size :optional (flags 0))
    (tls-socket-recv o size flags))
  (define-method socket-recv! ((o <tls-socket>) bv start len
			       :optional (flags 0))
    (tls-socket-recv! o bv start len flags))
  (define-method socket-accept ((o <tls-socket>) . opt)
    (apply tls-socket-accept o opt))
  ;; To avoid no-next-method error
  (define-method socket-accept ((o <socket>) (key <keyword>) . dummy)
    (socket-accept o))

  (define-method call-with-socket ((o <tls-socket>) proc)
    (call-with-tls-socket o proc))

  (define-method socket-peer ((o <tls-socket>))
    (tls-socket-peer o))
  (define-method socket-name ((o <tls-socket>))
    (tls-socket-name o))
  (define-method socket-info ((o <tls-socket>))
    (tls-socket-info o))
  (define-method socket-info-values ((o <tls-socket>) . opt)
    (apply tls-socket-info-values o opt))

  (define-method socket-nonblocking! ((o <tls-socket>))
    (tls-socket-nonblocking! o))
  (define-method socket-blocking! ((o <tls-socket>))
    (tls-socket-blocking! o))

  (define (select-sockets selector timeout sockets)
    (define mapping (make-eq-hashtable))
    (for-each (lambda (s)
		(hashtable-set! mapping
		  (if (tls-socket? s) (slot-ref s 'raw-socket) s) s)) sockets)
    (let ((raw-sockets (apply selector timeout
			      (hashtable-keys-list mapping))))
      (filter-map (lambda (s) (hashtable-ref mapping s #f)) raw-sockets)))
  (define-method socket-read-select (timeout . rest)
    (select-sockets socket:socket-read-select timeout rest))
  (define-method socket-write-select (timeout . rest)
    (select-sockets socket:socket-write-select timeout rest))
  (define-method socket-error-select (timeout . rest)
    (select-sockets socket:socket-error-select timeout rest))

  )
