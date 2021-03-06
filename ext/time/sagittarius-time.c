/* -*- C -*- */
/*
 * time.c: srfi-19 time library
 *
 *   Copyright (c) 2010-2015  Takashi Kato <ktakashi@ymail.com>
 *
 *   Redistribution and use in source and binary forms, with or without
 *   modification, are permitted provided that the following conditions
 *   are met:
 *
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 *   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 *   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 *   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 *   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *  $Id: $
 */
#include <math.h>
#include <sagittarius.h>
#define LIBSAGITTARIUS_BODY
#include <sagittarius/extend.h>
#include "sagittarius-time.h"

static SgObject time_utc = SG_UNDEF;
static SgObject time_tai = SG_UNDEF;
static SgObject time_monotonic = SG_UNDEF;
static SgObject time_duration = SG_UNDEF;
static SgObject time_process = SG_UNDEF;
static SgObject time_thread = SG_UNDEF;

static SgTime* make_time_int(SgObject type)
{
  SgTime *t = SG_NEW(SgTime);
  SG_SET_CLASS(t, SG_CLASS_TIME);
  t->type = SG_FALSEP(type) ? time_utc : type;
  return t;
}

SgObject Sg_MakeTime(SgObject type, int64_t sec, uint64_t nsec)
{
  SgTime *t = make_time_int(type);
  unsigned long rn = nsec % TM_NANO;
  int64_t rs = sec + (nsec / TM_NANO);
  t->sec = rs;
  t->nsec = rn;
  return SG_OBJ(t);
}

SgObject Sg_SecondsToTime(int64_t sec)
{
  return Sg_MakeTime(time_utc, sec, 0);
}

SgObject Sg_TimeToSeconds(SgTime *t)
{
  if (t->nsec) {
    return Sg_MakeFlonum((double)t->sec + (double)t->nsec/TM_NANO);
  } else {
    return Sg_MakeIntegerFromS64(t->sec);
  }
}

SgObject Sg_TimeDifference(SgTime *x, SgTime *y, SgTime *r)
{
  if (!SG_EQ(x->type, y->type)) {
    Sg_Error(UC("TIME-ERROR time-differece: imcompatible-time-types %S vs %S"), 
	     x, y);
  }
  r->type = time_duration;
  if (SG_CLASS_OF(x)->compare(x, y, FALSE) == 0) {
    r->sec = 0;
    r->nsec = 0;
  } else {
    int64_t nano = (x->sec * TM_NANO + x->nsec) - (y->sec * TM_NANO + y->nsec);
    unsigned long nanos = labs(nano % TM_NANO);
    int64_t secs = nano / TM_NANO;
    r->sec = secs;
    r->nsec = nanos;
  }
  return r;
}

SgObject Sg_AddDuration(SgTime *x, SgTime *y, SgTime *r)
{
  int64_t sec_plus;
  long nsec_plus, rr, q;
  
  if (!SG_EQ(y->type, time_duration)) {
    Sg_Error(UC("TIME-ERROR add-duration: no-duration %S"), y);
  }
  sec_plus = x->sec + y->sec;
  nsec_plus = x->nsec + y->nsec;
  rr = nsec_plus % TM_NANO;
  q = nsec_plus / TM_NANO;
  if (rr < 0) {
    r->sec = sec_plus + q + -1;
    r->nsec = TM_NANO + rr;
  } else {
    r->sec = sec_plus + q;
    r->nsec = rr;
  }
  return r;
}

SgObject Sg_SubDuration(SgTime *x, SgTime *y, SgTime *r)
{
  int64_t sec_minus;
  long rr, q, nsec_minus;
  
  if (!SG_EQ(y->type, time_duration)) {
    Sg_Error(UC("TIME-ERROR subtract-duration: no-duration %S"), y);
  }
  sec_minus = x->sec - y->sec;
  nsec_minus = x->nsec - y->nsec;
  rr = nsec_minus % TM_NANO;
  q = nsec_minus / TM_NANO;
  if (rr < 0) {
    r->sec = sec_minus - q - 1;
    r->nsec = TM_NANO + rr;
  } else {
    r->sec = sec_minus - q;
    r->nsec = rr;
  }
  return r;
}

extern void Sg__Init_time_stub(SgLibrary *lib);
extern void Sg__Init_date_stub(SgLibrary *lib);

SG_EXTENSION_ENTRY void CDECL Sg_Init_sagittarius__time()
{
  SgLibrary *lib;
  SG_INIT_EXTENSION(sagittarius__time);
  time_utc = SG_INTERN("time-utc");
  time_tai = SG_INTERN("time-tai");
  time_monotonic = SG_INTERN("time-monotonic");
  time_duration = SG_INTERN("time-duration");
  time_process = SG_INTERN("time-process");
  time_thread = SG_INTERN("time-thread");

  lib = SG_LIBRARY(Sg_FindLibrary(SG_INTERN("(sagittarius time-private)"),
				  FALSE));
  Sg__Init_time_stub(lib);
  Sg__Init_date_stub(lib);
}

