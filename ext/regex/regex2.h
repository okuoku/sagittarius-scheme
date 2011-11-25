/* regex.h                                                -*- coding: utf-8; -*-
 *
 *   Copyright (c) 2010-2011  Takashi Kato <ktakashi@ymail.com>
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
#ifndef SAGITTARIUS_REGEX_H_
#define SAGITTARIUS_REGEX_H_

#include <sagittarius.h>

enum PatternFlags {
  /* on Sagittarius Scheme, internal line seperator is lf. */
  /* SG_UNIX_LINE         = (1L << 0), */
  SG_CASE_INSENSITIVE  = (1L << 1),
  SG_COMMENTS          = (1L << 2),
  SG_MULTILINE         = (1L << 3),
  SG_LITERAL           = (1L << 4),
  SG_DOTALL            = (1L << 5),
  SG_UNICODE_CASE      = (1L << 6),
  /* we do not support canonical equivalence */
  /* SG_CANON_EQ          = (1L << 7), */
};

enum Anchor {
  UNANCHORED,         /* No anchoring */
  ANCHOR_START,       /* Anchor at start only */
  ANCHOR_BOTH,        /* Anchor at start and end */
};

typedef struct inst_rec_t inst_t;

typedef union {		 /* arguments for opcode */
  SgChar c;		 /* RX_CHAR: target character */
  unsigned int n;	 /* RX_SAVE: submatch start or end position */
  struct {		 /* RX_SPLIT */
    inst_t *x;		 /*   primary position to jump */
    inst_t *y;		 /*   secondary position to jump */
  } pos;
  int bol;		 /* RX_START: beginning of line flag.
			    1: ^ or multi line mode
			    0: \A or single line mode */
  int eol; 		 /* RX_END: end of line flag. values are the same as
			            above. */
  SgObject set;		 /* RX_SET: charset */
} inst_arg_t;

struct inst_rec_t
{
  unsigned char opcode;		/* opcode: max 255 */
  inst_arg_t    arg;
};

typedef struct
{
  inst_t *root;			/* root match code */
  inst_t *matchRoot;		/* match function root
				   (could be the same as above) */
  int     rootLength;
  int     matchRootLength;
} prog_t;

typedef struct SgPatternRec
{
  SG_META_HEADER;
  SgObject pattern;		/* regex pattern: string or ast */
  SgObject ast;			/* parsed ast */
  int      flags;		/* flags, details are above.
				   this flags are initial condition, if regex
				   has (?imx:...) in its body, matcher
				   overwrites the flags in runtime.*/
  int      groupCount;		/* captured group count */
  prog_t  *prog;		/* compiled regex */
} SgPattern;

SG_DECLARE_META_OBJ(Sg_PatternMeta);
#define SG_META_PATTERN   (&Sg_PatternMeta)
#define SG_PATTERN(obj)   ((SgPattern *)obj)
#define SG_PATTERN_P(obj) SG_META_OBJ_TYPE_P(obj, SG_META_PATTERN)

typedef struct
{
  int start;
  int end;
} submatch_t;

typedef struct SgMatcherRec
{
  SG_META_HEADER;
  SgPattern *pattern;
  SgString  *text;
  /* privates */
  int        first;
  int        from;
  int        to;
  int        last;
  int        hitEnd;
  int        oldLast;
  int        acceptMode;
  int        anchorBounds;
  submatch_t submatch[1];
} SgMatcher;

SG_DECLARE_META_OBJ(Sg_MatcherMeta);
#define SG_META_MATCHER   (&Sg_MatcherMeta)
#define SG_MATCHER(obj)   ((SgMatcher *)obj)
#define SG_MATCHER_P(obj) SG_META_OBJ_TYPE_P(obj, SG_META_MATCHER)

#define argumentAsPattern(index, tmp_, var_)				\
  castArgumentType(index, tmp_, var_, crypto, SG_PATTERN_P, SG_PATTERN)

#define argumentAsMatcher(index, tmp_, var_)				\
  castArgumentType(index, tmp_, var_, crypto, SG_MATCHER_P, SG_MATCHER)


SG_CDECL_BEGIN
SgObject Sg_CompileRegex(SgString *pattern, int flags, int parseOnly);

SgMatcher* Sg_RegexMatcher(SgPattern *pattern, SgString *text);
int        Sg_RegexLookingAt(SgMatcher *m);
/* for debug */
void     Sg_DumpRegex(SgPattern *pattern, SgObject port);

SG_CDECL_END

#endif /* SAGITTARIUS_REGEX_H_ */
