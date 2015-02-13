@; -*- mode:scribble; coding: utf-8 -*-

@subsection[:tag "lib.sagittarius.threads"]{(sagittarius threads) - Thread}

@define[Library]{@name{(sagittarius threads)}}
@desc{The library provides thread related procedures. The procedures provided
this library is based on @hyperlink[:href "http://srfi.schemers.org/srfi-18/srfi-18.html"]{SRFI-18 Multithreading support} and Sagittarius specific procedures.
}

@subsubsection{Thread APIs}

@define[Function]{@name{thread?} @args{obj}}
@desc{[SRFI-18] Returns #t if given @var{obj} is a thread, otherwise #f.}

@define[Function]{@name{current-thread}}
@desc{[SRFI-18] Returns the current thread.}

@define[Function]{@name{make-thread} @args{thunk :optional name}}
@desc{[SRFI-18] Returns a new thread. The created thread is not executed. 
To run it, users must explicitly call the @code{thread-start!} procedure.

The optional argument @var{name} gives the thread a name. The name can be
retrieved calling @code{thread-name} procedure. If the argument is not given,
then the @code{make-thread} procedures creates an unique name.
}

@define[Function]{@name{thread-name} @args{thread}}
@desc{[SRFI-18] Returns the name of @var{thread}.}

@define[Function]{@name{thread-state} @args{thread}}
@desc{Returns the current state of @var{thread}.}

@define[Function]{@name{thread-specific} @args{thread}}
@desc{[SRFI-18] Returns the content of the @var{thread}'s specific slot.}

@define[Function]{@name{thread-specific-set!} @args{thread obj}}
@desc{[SRFI-18] Stores @var{obj} into the @var{thread}'s specific slot and
returns unspecified value.}

@define[Function]{@name{thread-start!} @args{thread}}
@desc{[SRFI-18] Executes the given @var{thread} and returns @var{thread}}

@define[Function]{@name{thread-yield!}}
@desc{[SRFI-18] The current thread exits the running state if its quantum
had expired.}

@define[Function]{@name{thread-sleep!} @args{timeout}}
@desc{[SRFI-18] The current thread waits until the timeout is reached.

@var{timeout} must be either a time object or an exact integer. The first case,
it represents absolute time of the future. The latter case represents second
from current time.}

@define[Function]{@name{thread-terminate!} @args{thread}}
@desc{[SRFI-18] Causes an abnormal termination of the @var{thread}. If 
the @var{thread} is not already terminated, all mutexes owned by the 
@var{thread} become unlocked/abandoned and a "terminated thread exception"
object is stored in the @var{thread}'s end-exception field. If @var{thread}
is the current thread, @code{thread-terminate!} does not return. Otherwise 
@code{thread-terminate!} returns an unspecified value; the termination of 
the thread will occur before @code{thread-terminate!} returns.
}

@define[Function]{@name{thread-join!}
 @args{thread :optional timeout timeout-val}}
@desc{[SRFI-18] The current thread waits until the @var{thread} terminates 
(normal or not) or until the @var{timeout} is reached if @var{timeout} is 
specified. If the @var{timeout} is reached, @code{thread-join!} returns 
@var{timeout-val} if it is supplied, otherwise a "join timeout exception" 
is raised. If the @var{thread} terminated normally, the content of the 
end-result field is returned, otherwise the content of the end-exception
field is raised.}

@define[Function]{@name{thread-stop!}
 @args{thread :optional timeout timeout-val}}
@desc{Stops execution of the @var{thread}. Users can resume the @var{thread}
by calling @code{thread-cont!}.
}

@define[Function]{@name{thread-cont!} @args{thread}}
@desc{Resumes execution of the @var{thread}.}

@subsubsection{Mutex APIs}

@define[Function]{@name{mutex?} @args{obj}}
@desc{[SRFI-18] Returns #t if given @var{obj} is a mutex, otherwise #f.}

@define[Function]{@name{make-mutex} @args{:optional name}}
@desc{[SRFI-18] Returns a new mutex. 

The optional argument @var{name} gives the mutex a name. If it's not specified,
then the procedure makes an unique name.}

@define[Function]{@name{mutex-name} @args{mutex}}
@desc{[SRFI-18] Returns the name of given @var{mutex}.}

@define[Function]{@name{mutex-specific} @args{mutex}}
@desc{[SRFI-18] Returns the content of specific slot of given @var{mutex}.}

@define[Function]{@name{mutex-specific-set!} @args{mutex obj}}
@desc{[SRFI-18] Stores the @var{obj} to given @var{mutex}'s specific slot.}

@define[Function]{@name{mutex-state} @args{mutex obj}}
@desc{[SRFI-18] Returns the state of given @var{mutex}.}

@define[Function]{@name{mutex-lock!} @args{mutex :optional timeout thread}}
@desc{[SRFI-18] Locks the given @var{mutex}. If the @var{mutex} is currently
locked, the current thread waits the @var{mutex} is unlocked or until the
@var{timeout} is reached. If @var{timeout} is reached, the procedure returns
#f.

@; TBD thread argument description.
}

@define[Function]{@name{mutex-unlock!} @args{mutex :optional cv timeout}}
@desc{[SRFI-18] Unlocks the given @var{mutex}. If condition variable @var{cv}
is specified, the current thread is blocked and added to the @var{cv} before
unlocking @var{mutex}, the thread can unblock at any time but no later than
when an appropriate call to @code{condition-variable-signal!} or
@code{condition-variable-broadcast!} is performed, and no later than the 
@var{timeout}, if it's given.

@; TBD better description.
}

@; TBD with-locking-mutex

@subsubsection{Condition variable APIs}

@define[Function]{@name{condition-variable?} @args{obj}}
@desc{[SRFI-18] Returns #t if given @var{obj} is a condition variable,
otherwise #f.}

@define[Function]{@name{make-condition-variable} @args{:optional name}}
@desc{[SRFI-18] Returns a new condition variable.

The optional argument @var{name} gives the condition variable a name. If 
it's not specified, then the procedure makes an unique name.}

@define[Function]{@name{condition-variable-name} @args{cv}}
@desc{[SRFI-18] Returns the name of given @var{cv}.}

@define[Function]{@name{condition-variable-specific} @args{cv}}
@desc{[SRFI-18] Returns the content of specific slot of given @var{cv}.}

@define[Function]{@name{condition-variable-specific-set!} @args{cv obj}}
@desc{[SRFI-18] Stores the @var{obj} to given @var{cv}'s specific slot.}

@define[Function]{@name{condition-variable-signal} @args{cv}}
@desc{[SRFI-18] If there are thread blocked on @var{cv}, the scheduler selects
a thread and unblocks it.}

@define[Function]{@name{condition-variable-broadcast!} @args{cv}}
@desc{[SRFI-18] Unblocks all the threads blocked on the @var{cv}.}

@; TBD sys-nanosleep
@; TBD condition accessors.