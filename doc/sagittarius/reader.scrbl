@; -*- coding: utf-8; -*-
@subsection[:tag "lib.sagittarius.reader"]{(sagittarius reader) - reader macro library}

Unlikely, Sagittarius provides functionalities to modify its reader like Common
Lisp. It makes Sagittarius programable. However it has some restriction to use.
The following examples explain it.

Using reader macro
@codeblock{
;;#<(sagittarius regex)>       ;; this imports only reader macros
                               ;; This form is only for backward compatibility
;; portable way for other R6RS implementation's reader.
#!read-macro=sagittarius/regex
(import (sagittarius regex)) ;; usual import for procedures
#/regex/i                    ;; (sagittarius regex) defines #/regex/ form
                             ;; reader macro in it. it converts it
                             ;; (comple-regex "regex" CASE-INSENSITIVE)
}

Writing reader macro on toplevel
@codeblock{
(import (rnrs) (sagittarius reader))
(set-macro-character #\$
 (lambda (port c) (error '$-reader "invliad close paren appeared")))
(set-macro-character #\! (lambda (port c) (read-delimited-list #\$ port)))
!define test !lambda !$ !display "hello reader macro"$$$
!test$ ;; prints "hello reader macro"
}

Writing reader macro in library and export it
@codeblock{
#!compatible ;; make sure Sagittarius can read keyword
(library (reader macro test)
    ;; :export-reader-macro keyword must be in export clause
    (export :export-reader-macro)
    (import (rnrs) (sagittarius reader))

  (define-reader-macro $-reader #\$
    (lambda (port c)
      (error '$-reader "unexpected close paren appeared")))

  (define-reader-macro !-reader #\!
    (lambda (port c)
      (read-delimited-list #\$ port)))
)

#!read-macro=reader/macro/test  ;; imports reader macro
!define test !lambda !$ !display "hello reader macro"$$$
!test$    ;; prints "hello reader macro"
}

If you need to use reader macro in your library code, you need to define it
outside of the library. The library syntax is just one huge list so Sagittarius
can not execute the definition of reader macro inside during reading it.

@define[Library]{@name{(sagittarius reader)}}
@desc{This library provides reader macro procedures and macros.}

@define[Macro]{@name{define-reader-macro} 
  @args{char (name args @dots{}) body @dots{}}}
@define[Macro]{@name{define-reader-macro} @args{name char proc}}
@define[Macro]{@name{define-reader-macro} @args{name char proc non-term?}}

@desc{@var{Name} must be self evaluated expression. @var{Proc} must accept 2 or
3 arguments, the first one is a port, the second one is a character which is
defined as reader macro character, and the third one which is an optional
argument is a read context.

@code{define-reader-macro} macro associates @var{char} and @var{proc} as a
reader macro. Once it is associated and Sagittarius' reader reads it, then
dispatches to the @var{proc} with 2 arguments.

If @var{non-term?} argument is given and not #f, the @var{char} is marked as
non terminated character. So reader reads as one identifier even it it contains
the given @var{char} in it.

The first form is a convenient form. Users can write a reader macro without
explicitly writing @code{lambda}. The form is expanded to like this:
@codeblock{
(define-reader-macro #\$ ($-reader args @dots{}) body @dots{})
;; -> (define-reader-macro $-reader #\$ (lambda (args @dots{}) body @dots{}))
}

Note: the @var{name} is only for error message. It does not affect anything.
}

@define[Macro]{@name{define-dispatch-macro} @args{name char subchar proc}}
@define[Macro]{@name{define-dispatch-macro}
 @args{name char proc subchar non-term?}}
@desc{@var{Name} must be self evaluated expression.
@var{Proc} must accept three arguments, the first one is a port, the second one 
is a character which is defined as reader macro character and the third one is
a macro parameter.

@code{define-dispatch-macro} creates macro dispatch macro character @var{char}
if there is not dispatch macro yet, and associates @var{subchar} and @var{proc}
as a reader macro.

If @var{non-term?} argument is given and not #f, the @var{char} is marked as non
terminated character. So reader reads as one identifier even it it contains the 
given @var{char} in it.

Note: the @var{name} is only for error message. It does not affect anything.
}

@define[Function]{@name{get-macro-character} @args{char}}
@desc{Returns 2 values if @var{char} is macro character; one is associated
procedure other one is boolean if the @var{char} is terminated character or not.
Otherwise returns 2 #f.
}

@define[Function]{@name{set-macro-character}
 @args{char proc :optional non-term?}}
@desc{Mark given @var{char} as macro character and sets the @var{proc} as its
reader.
If @var{non-term?} is given and not #f, the @var{char} will be marked as non
terminated macro character.
}

@define[Function]{@name{make-dispatch-macro-character}
 @args{char :optional non-term?}}
@desc{Creates a new dispatch macro character with given @var{char} if it is not
a dispatch macro character yet.
If @var{non-term?} is given and not #f, the @var{char} will be marked as non
terminated macro character.
}

@define[Function]{@name{get-dispatch-macro-character} @args{char subchar}}
@desc{Returns a procedure which is associated with @var{char} and @var{subchar}
as a reader macro. If nothing is associated, it returns #f.
}

@define[Function]{@name{set-dispatch-macro-character}
 @args{char subchar proc}}
@desc{Sets @var{proc} as a reader of @var{subchar} under the dispatch macro 
character of @var{char}.
}

@define[Function]{@name{read-delimited-list}
 @args{char :optional (port (current-input-port))}}
@desc{Reads a list until given @var{char} appears.}

@subsubsection[:tag "lib.sagittarius.reader.predefined"]{Predefined reader macros}

The following table explains predefined reader macros.
@table[:title "Reader macros"]{
@tr{@th{Macro character} @th{Terminated} @th{Explanation}}
@tr{@td{#\(} @td{#t}
 @td{Reads a list until reader reads #\).}}
@tr{@td{#\[} @td{#t}
 @td{Reads a list until reader reads #\].}}
@tr{@td{#\)} @td{#t}
 @td{Raises read error.}}
@tr{@td{#\]} @td{#t}
 @td{Raises read error.}}
@tr{@td{#\|} @td{#t}
 @td{Reads an escaped symbol until reader reads #\|.}}
@tr{@td{#\"} @td{#t}
 @td{Reads a string until reader reads #\".}}
@tr{@td{#\'} @td{#t}
 @td{Reads a symbol until reader reads delimited character.}}
@tr{@td{#\;} @td{#t}
 @td{Discards read characters until reader reads a linefeed.}}
@tr{@td{#\`} @td{#t}
 @td{Reads a next expression and returns @code{(quasiquote @var{expr})}}}
@tr{@td{#\,} @td{#t}
 @td{Check next character if it is @code{@atmark{}} and reads a next expression.

     Returns @code{(unquote-splicing @var{expr})} if next character was
     @code{@atmark{}}, otherwise @code{(unquote @var{expr})}}}
@tr{@td{#\:} @td{#f}
 @td{Only compatible mode. Reads a next expression and returns a keyword.}}
@tr{@td{#\#} @td{#t(R6RS mode)}
 @td{Dispatch macro character.}}
}

@table[:title "Sub characters of '#' reader macro"]{
@tr{@th{Sub character} @th{Explanation}}
@tr{@td{#\'}
 @td{Reads a next expression and returns @code{(syntax @var{expr})}.}}
@tr{@td{#\`}
 @td{Reads a next expression and returns @code{(quasisyntax @var{expr})}}}
@tr{@td{#\,}
 @td{Check next character if it is @code{@atmark{}} and reads a next expression.

     Returns @code{(unsyntax-splicing @var{expr})} if next character was
     @code{@atmark{}}, otherwise @code{(unsyntax @var{expr})}}}
@tr{@td{#\!}
 @td{Reads next expression and set flags described below.
  @dl-list{
    @dl-item["#!r6rs"]{Switches to R6RS mode}
    @dl-item["#!r7rs"]{Switches to R7RS mode}
    @dl-item["#!compatible"]{Switches to compatible mode}
    @dl-item["#!no-overwrite"]{Sets no-overwrite flag that does not allow user
    to overwrite exported variables.}
    @dl-item["#!nocache"]{Sets disable cache flag on the current loading file}
    @dl-item["#!deprecated"]{Display warning message of deprecated library.}
    @dl-item["#!reader=name"]{
	Replace reader with library @var{name}. The @var{name} must be converted
	with the naming convention described below. For more details, see
	@secref["sagittarius.name.convention"]{Naming convention}}
    @dl-item["#!read-macro=name"]{
	The same as @code{#< @var{name} >} but this is more for compatibility.
	@var{name} must be converted with the naming convention described below.
	For more details, see	
	@secref["sagittarius.name.convention"]{Naming convention}}
  }}}
@tr{@td{#\v}
 @td{Checks if the next 2 characters are @code{u} and @code{8} and reads
 a bytevector.}}
@tr{@td{#\u}
 @td{Only compatible mode. Checks if the next character is @code{8} and reads
 a bytevector.}}
@tr{@td{#\t and #\T} @td{Returns #t.}}
@tr{@td{#\f and #\F} @td{Returns #f.}}
@tr{@td{#\b and #\B} @td{Reads a binary number.}}
@tr{@td{#\o and #\O} @td{Reads a octet number.}}
@tr{@td{#\d and #\D} @td{Reads a decimal number.}}
@tr{@td{#\x and #\X} @td{Reads a hex number.}}
@tr{@td{#\i and #\I} @td{Reads a inexact number.}}
@tr{@td{#\e and #\E} @td{Reads a exact number.}}
@tr{@td{#\(} @td{Reads a next list and convert it to a vector.}}
@tr{@td{#\;} @td{Reads a next expression and discards it.}}
@tr{@td{#\|}
 @td{Discards the following characters until reader reads @code{|#}}}
@tr{@td{#\\} @td{Reads a character.}}
@tr{@td{#\=} @td{Starts reading SRFI-38 style shared object.}}
@tr{@td{#\#} @td{Refers SRFI-38 style shared object.}}
@tr{@td{#\<} @td{Reads expressions until '>' and imports reader macro from it.
Note: if expressions contains symbol, which is illegal library name, at the end
#<-reader can not detect the '>' because '>' can be symbol. So the error message
might be a strange one.}}
}

@sub*section{#! - Switching mode}

Sagittarius has multiple reader and VM modes and users can switch these modes
with @code{#!}. Following describes details of those modes;

@dl-list{
  @dl-item["R6RS mode"]{Symbols are read according to R6RS specification and VM
  sets the @code{no-overwrite} flag. With this mode, keywords are read as
  symbols; for example, @code{:key} is just a symbol and users can not use
  extended @code{lambda} syntax.
  }
  @dl-item["R7RS mode"]{The mode for new specification of Scheme. This mode is
  less strict than R6RS mode described above. The reader can read keyword and VM
  sets the @code{no-overwrite} flag.
  }
  @dl-item["Compatible mode"]{This mode is least strict mode. In other words, it
  does not have any restrictions such as described above.
  }
}

NOTE: If you import reader macro with @code{#< (@dots{}) >} form and let reader
read above hash-bang, the read table will be reset. So following code will raise
a read error;

@codeblock{
#!read-macro=sagittarius/regex
#!r6rs
#/regular expression/ ;; <- &lexical
}

@subsubsection{Replacing reader}

Since 0.3.7, users can replace default reader. Following example describes how
to replace reader.

@codeblock{
#!reader=srfi/:49
define
  fac n
  if (zero? n) 1
    * n
      fac (- n 1)

(print (fac 10))
}

@code{#!reader=} specifies which reader will be used. For this example, it will
use the one defined in @code{(srfi :49)} library. For compatibility of the other
Scheme implementation, we chose not to use the library name itself but a bit
converted name.

@sub*section[:tag "sagittarius.name.convention"]{Naming convention}

The naming convention is really easy. For example, replacing with
@code{(srfi :49)}, first remove all parentheses or brackets then replace spaces
to @code{/}.

@define[Macro]{@name{define-reader} @args{name expr}}
@define[Macro]{@name{define-reader} @args{(name port) expr @dots{}}}
@desc{This macro defines replaceable reader.

The forms are similar with @code{define}. However if you use the first form
then @var{expr} must be @code{lambda} and it accept one argument.

The defined reader will be used on read time, so it needs to return valid
expression as a return value of the reader.

NOTE: Only one reader can be defined in one library. If you define more than
once the later one will be used.
}

NOTE: If you want to export user defined reader to other library, you need to
put @code{:export-reader} keyword to the library export clause.