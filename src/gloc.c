/* gloc.c                                          -*- mode:c; coding:utf-8; -*-
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
#define LIBSAGITTARIUS_BODY
#include "sagittarius/gloc.h"
#include "sagittarius/port.h"
#include "sagittarius/writer.h"

static void gloc_print(SgObject obj, SgPort *port, SgWriteContext *ctx)
{
  SgGloc *g = SG_GLOC(obj);
  Sg_Putuz(port, UC("#<gloc "));
  Sg_Write(g->name, port, ctx->mode);
  Sg_Putc(port, ' ');
  Sg_Write(g->library, port, ctx->mode);
  Sg_Putc(port, '>');
}

SG_DEFINE_BUILTIN_CLASS_SIMPLE(Sg_GlocClass, gloc_print);

SgObject Sg_MakeGloc(SgSymbol *name, SgLibrary *library)
{
  SgGloc *g = SG_NEW(SgGloc);
  SG_SET_CLASS(g, SG_CLASS_GLOC);
  g->name = name;
  g->library = library;
  g->value = SG_UNBOUND;
  g->constant = FALSE;
  return SG_OBJ(g);
}

int Sg_GlocConstP(SgGloc *g)
{
  return g->constant;
}

