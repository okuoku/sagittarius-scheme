@; -*- mode:scribble; coding: utf-8 -*-
@title{Sagittarius Users' Reference}

This document is a manual for Sagittarius, an R6RS/R7RS Scheme implementation.
This is for version @eval{(sagittarius-version)}.

@table-of-contents[:id "table-of-contents"]

@section{Introduction}

This is a users' guide and reference manual of Sagittarius Scheme system. Here
I tried to describe the points which are not conformed to R6RS.

The target readers are those who already know Scheme and want to write useful
programs in Sagittarius.

@; -- for now, forget this.
@; This manual only deals with Scheme side of things. Sagittarius has another
@; face, a C interface. Details of it will be discussed in a separate document
@; yet to be written. Those who wants to use Sagittarius as an embedded language,
@; or wants to write an extension, need that volume.

@subsection{Overview of Sagittarius}

Sagittarius is a Scheme script engine; it reads Scheme programs, compiles it
on-the-fly and executes it on a virtual machine. Sagittarius conforms the
language standard "Revised^6 Report on the Algorithmic Language Scheme" (R6RS),
"Revised^7 Report on the Algorithmic Language Scheme" (R7RS), and supports
various common libraries defined in "Scheme Requests for Implementation"
(SRFI)s.

There are a lot of Scheme implementations and they have different strong and
weak points. Sagittarius focuses on "Flexibility" and "Easy to Use". R6RS
specifies strict requirements, but sometimes you may think this is too
much. For that purpose, Sagittarius has less strictness. There are invocation
options that make Sagittarius run on strict RnRS mode.

To avoid to lose portability or write miss-working code, you may want to know
what are the non conformed points.

@dl-list[]{
@dl-item["Reader"]{
 Basically reader has 3 modes. One is R6RS mode, one is R7RS mode and the 
 last one is compatible mode. Although, user can modify reader with reader
 macro. These modes can be switched via @code{#!r6rs}, @code{#!r7rs} or
 @code{#!compatible}. For more details, see
 @secref["lib.sagittarius.reader.predefined"]{Predefined reader macros}.
}
@dl-item["Miscellaneous"]{
 Redefinition of exported values are allowed on script file. This can be
 restricted by @code{-r6} option to run the script strict R6RS mode.

 Multiple import of the same identifier is allowed. The value which 
 imported at the last will be used.}
}

@subsection{Notations}

In this manual, each entry is represented like this.

@define[Category]{@name{foo} @args{arg1 arg2}}
@desc{[spec] Description foo @dots{}}

@var{Category} denotes category of the entry @b{foo}. The following category
will appear in this manual.

@dl-list[
@dl-item["Program"]{A command line program}
@dl-item["Function"]{A Scheme function}
@dl-item["Syntax"]{A syntax}
@dl-item["Auxiliary Syntax"]{A auxiliary syntax}
@dl-item["Macro"]{A macro}
@dl-item["Auxiliary Macro"]{A auxiliary macro}
@dl-item["Library"]{A library}
@dl-item["Condition Type"]{A condition type}
@dl-item["Reader Macro"]{A reader macro}
@dl-item["Class"]{A CLOS class}
@dl-item["Generic"]{A generic function}
@dl-item["Method"]{A method}
]

For functions, syntaxes, or macros, the the entry may be followed by one or more
arguments. In the arguments list, following notations may appear.

@dl-list[
@dl-item[@var{arg @dots{}}]{Indicates zero or more arguments}
@dl-itemx[2 @var{:optional x y z} 
	    @var{:optional (x x-default) (y y-default) (z z-default)}]{
Indicates is may take up to three optional arguments. The second form specifies
default values for x, y and z.}
]

The description of the entry follows the entry line. If the specification of the
entry comes from some standard or implementation, its origin is noted in the
bracket at the beginning of the description. The following origins are noted:

@dl-list[
@dl-itemx[2 "[R6RS]" "[R6RS+]"]{
The entry works as specified in "Revised^6 Report on the Algorithmic Language
Scheme.". If it is marked as "[R6RS+]", the entry has additional functionality.}
@dl-item["[R7RS]"]{
The entry works as specified in "Revised^7 Report on the Algorithmic Language
Scheme.".}
@dl-itemx[2 "[SRFI-n]" "[SRFI-n+]"]{The entry works as specified in SRFI-n. If
it is marked as "[SRFI-n+]", the entry has additional functionality.}
]

@section{Programming in Sagittarius}

@subsection{Invoking Sagittarius}

Sagittarius can be used as an independent Schame interpreter. The interpreter
which comes with Sagittarius distribution is a program named @code{sagittarius}
on Unix like environment and @code{sash} on Windows environment.

@define[Program]{@name{sagittarius} @args{[options] scheme-file arg @dots{}}}
@desc{Invoking sagittarius. If @var{scheme-file} is not given, it runs with
interactive mode.

Specifying @code{-r} option with Scheme standard number, currently @code{6}
and @code{7} are supported, forces to run Sagittarius on strict standard
mode. For example, entire script is read then evaluated on R6RS 
(@code{-r6} option) mode. Thus macros can be located below the main script.

Detail options are given with option @code{"-h"}.}

For backward compatibility, symbolic link @code{sash} is also provided
on Unix like environment. However this may not exist if Sagittarius is built
with disabling symbolic link option.

@subsection{Writing Scheme scripts}

When a Scheme file is given to @code{sagittarius}, it bounds an internal
variable to list of the remaining command-line arguments which you can get with
the @code{command-line} procedure, then loads the Scheme program. If the first
line of scheme-file begins with @code{"#!"}, then Sagittarius ignores the
entire line. This is useful to write a Scheme program that works as an
executable script in unix-like systems.

Typical Sagittarius script has the first line like this:

@snipet{#!/usr/local/bin/sagittarius}

or

@snipet{#!/bin/env sagittarius}

The second form uses "shell trampoline" technique so that the script works as
far as @code{sagittarius} is in the PATH.

After the script file is successfully loaded, then Sagittarius will process all
toplevel expression the same as Perl.

Now I show a simple example below. This script works like @code{cat(1)}, without
any command-line option processing and error handling.

@codeblock{
#!/usr/local/bin/sagittarius
(import (rnrs))
(let ((args (command-line)))
  (unless (null? (cdr args))
    (for-each (lambda (file)
		(call-with-input-file file
		  (lambda (in)
		    (display (get-string-all in)))))
	      (cdr args)))
  0)
}

If the script file contains @code{main} procedure, then Sagittarius execute
it as well with one argument which contains all command line arguments. This
feature is defined in 
@hyperlink[:href "http://srfi.schemers.org/srfi-22/"]{SRFI-22}. So the
above example can also be written like the following:

@codeblock{
#!/usr/local/bin/sagittarius
(import (rnrs))
(define (main args)
  (unless (null? (cdr args))
    (for-each (lambda (file)
		(call-with-input-file file
		  (lambda (in)
		    (display (get-string-all in)))))
	      (cdr args)))
  0)
}

NOTE: the @code{main} procedure is called after all toplevel expressions
are executed.

@subsection{Working on REPL}

If @code{sagittarius} does not get any script file to process, then it will
go in to REPL (read-eval-print-loop). For developers' convenience, REPL
imports some libraries by default such as @code{(rnrs)}.

If @code{.sashrc} file is located in the directory indicated @code{HOME} or
@code{USERPROFILE} environment variable, then REPL reads it before evaluating
user input. So developer can pre-load some more libraries, instead of typing
each time.

NOTE: @code{.sashrc} is only for REPL, it is developers duty to load all
libraries on script file.

@subsection{Writing a library}

Sagittarius provides 2 styles to write a library, one is R6RS style and other
one is R7RS style. Both styles are processed the same and users can use it
without losing code portability.

Following example is written in R6RS style, for the detail of @code{library}
syntax please see the R6RS document described in bellow sections.
@codeblock{
(library (foo)
  (export bar)
  (import (rnrs))

 (define bar 'bar) ) } The library named @code{(foo)} must be saved the file
named @code{foo.scm}, @code{foo.ss}, @code{foo.sls} or @code{foo.sld} (I use
@code{.scm} for all examples) and located on the loading path, the value is
returned by calling @code{add-load-path} with 0 length string.

If you want to write portable code yet want to use Sagittarius specific
functionality, then you can write implementation specific code separately using
@code{.sagittarius.scm}, @code{.sagittarius.ss}, @code{.sagittarius.sls} or
@code{.sagittarius.sld} extensions. This functionality is implemented almost
all R6RS implementation. If you use R7RS style library syntax, then you can
also use @code{cond-expand} to separate implementation specific
functionalities.

If you don't want to share a library but only used in specific one, you can
write both in one file and name the file you want to show. For example;
@codeblock{
(library (not showing)
  ;; exports all internal use procedures
  (export ...)
  (import (rnrs))
;; write procedures
...
)

(library (shared)
  (export shared-procedure ...)
  (import (rnrs) (not showing))
;; write shared procedures here
)
}
Above script must be saved the file named @code{shared.scm}. The order of
libraries are important. Top most dependency must be the first and next is
second most, so on.

Note: This style can hide some private procedures however if you want to write
portable code, some implementations do not allow you to write this style.

@subsection{Compiled cache}

For better starting time, Sagittarius caches compiled libraries. The cache files
are stored in one of the following environment variables;

For Unix like (POSIX) environment:
@itemlist[
  @item{@code{SAGITTARIUS_CACHE_DIR}}
  @item{@code{HOME}}
]

For Windows environment:
@itemlist[
  @item{@code{SAGITTARIUS_CACHE_DIR}}
  @item{@code{TEMP}}
  @item{@code{TMP}}
]

Sagittarius will use the variables respectively, so if the
@code{SAGITTARIUS_CACHE_DIR} is found then it will be used.

The caching compiled file is carefully designed however the cache file might be
stored in broken state. In that case use @code{-c} option with
@code{sagittarius}, then it will wipe all cache files. If you don't want to use
it, pass @code{-d} option then Sagittarius won't use it.

@subsubsection{Precompiling cache file}

Users can provide own library with precompile script. The script looks like
this;

@codeblock{
(import (the-library-1)
        (the-library-2))
}

When this script is run, then the libraries will be cached in the cache
directory.

Note: The cache files are stored with the names converted from original library
files' absolute path. So it is important that users' libraries are already
installed before precompiling, otherwise Sagittarius won't use the precompiled
cache files.

@include-section["r6rs.scrbl"]
@include-section["r7rs.scrbl"]
@include-section["clos.scrbl"]
@include-section["sagittarius.scrbl"]
@include-section["utils.scrbl"]
@include-section["ported.scrbl"]
@include-section["srfi.scrbl"]
@section[:appendix "A" :tag "index"]{Index}

@index-table[:id "index-table"]
@author["Takashi Kato"]