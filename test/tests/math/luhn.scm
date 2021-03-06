(import (rnrs)
	(math luhn)
	(sagittarius) ;; for digit-value
	(srfi :64)
	(srfi :39 parameters))

(test-begin "Luhn algorithm")

;; calculation
(test-equal "luhn calc( 1)" 5 (luhn-calculate "12"))
(test-equal "luhn calc( 2)" 0 (luhn-calculate "123"))
(test-equal "luhn calc( 3)" 3 (luhn-calculate "1245496594"))
(test-equal "luhn calc( 4)" 4 (luhn-calculate "TEST"))
(test-equal "luhn calc( 5)" 7 (luhn-calculate "Test123"))
(test-equal "luhn calc( 6)" 5 (luhn-calculate "00012"))
(test-equal "luhn calc( 7)" 1 (luhn-calculate "9"))
(test-equal "luhn calc( 8)" 3 (luhn-calculate "999"))
(test-equal "luhn calc( 9)" 6 (luhn-calculate "999999"))
(test-equal "luhn calc(10)" 7 (luhn-calculate "CHECKDIGIT"))
(test-equal "luhn calc(11)" 2 (luhn-calculate "EK8XO5V9T8"))
(test-equal "luhn calc(12)" 1 (luhn-calculate "Y9IDV90NVK"))
(test-equal "luhn calc(13)" 5 (luhn-calculate "RWRGBM8C5S"))
(test-equal "luhn calc(14)" 5 (luhn-calculate "OBYY3LXR79"))
(test-equal "luhn calc(15)" 2 (luhn-calculate "Z2N9Z3F0K3"))
(test-equal "luhn calc(16)" 9 (luhn-calculate "ROBL3MPLSE"))
(test-equal "luhn calc(17)" 9 (luhn-calculate "VQWEWFNY8U"))
(test-equal "luhn calc(18)" 1 (luhn-calculate "45TPECUWKJ"))
(test-equal "luhn calc(19)" 8 (luhn-calculate "6KWKDFD79A"))
(test-equal "luhn calc(20)" 3 (luhn-calculate "HXNPKGY4EX"))
(test-equal "luhn calc(21)" 2 (luhn-calculate "91BT"))

(test-error "invalid char" assertion-violation? (luhn-calculate "12/9"))

;; validation
(test-assert "luhn valid( 1)"  (luhn-valid? "125"))
(test-assert "luhn valid( 2)"  (luhn-valid? "1230"))
(test-assert "luhn valid( 3)"  (luhn-valid? "12454965943"))
(test-assert "luhn valid( 4)"  (luhn-valid? "TEST4"))
(test-assert "luhn valid( 5)"  (luhn-valid? "Test1237"))
(test-assert "luhn valid( 6)"  (luhn-valid? "000125"))
(test-assert "luhn valid( 7)"  (luhn-valid? "91"))
(test-assert "luhn valid( 8)"  (luhn-valid? "9993"))
(test-assert "luhn valid( 9)"  (luhn-valid? "9999996"))
(test-assert "luhn valid(10)"  (luhn-valid? "CHECKDIGIT7"))
(test-assert "luhn valid(11)"  (luhn-valid? "EK8XO5V9T82"))
(test-assert "luhn valid(12)"  (luhn-valid? "Y9IDV90NVK1"))
(test-assert "luhn valid(13)"  (luhn-valid? "RWRGBM8C5S5"))
(test-assert "luhn valid(14)"  (luhn-valid? "OBYY3LXR795"))
(test-assert "luhn valid(15)"  (luhn-valid? "Z2N9Z3F0K32"))
(test-assert "luhn valid(16)"  (luhn-valid? "ROBL3MPLSE9"))
(test-assert "luhn valid(17)"  (luhn-valid? "VQWEWFNY8U9"))
(test-assert "luhn valid(18)"  (luhn-valid? "45TPECUWKJ1"))
(test-assert "luhn valid(19)"  (luhn-valid? "6KWKDFD79A8"))
(test-assert "luhn valid(20)"  (luhn-valid? "HXNPKGY4EX3"))
(test-assert "luhn valid(21)"  (luhn-valid? "91BT2"))

(test-error "invalid char" assertion-violation? (luhn-valid? "12/9"))

;; custom converter
(define (custom-converter s)
  (string-for-each
   (lambda (c) (unless (digit-value c) 
		 (assertion-violation 'luhn-checksum "invalid char" c))) s)
  (map digit-value (string->list s)))

(parameterize ((*luhn-converter* custom-converter))
  (test-error "invalid char" assertion-violation? (luhn-valid? "TEST4"))
  (test-assert "luhn valid custom"  (luhn-valid? "9993")))

(test-end)
