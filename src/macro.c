/* macro.c                                         -*- mode:c; coding:utf-8; -*-
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
#include "sagittarius/macro.h"
#include "sagittarius/clos.h"
#include "sagittarius/closure.h"
#include "sagittarius/identifier.h"
#include "sagittarius/pair.h"
#include "sagittarius/port.h"
#include "sagittarius/vector.h"
#include "sagittarius/symbol.h"
#include "sagittarius/code.h"
#include "sagittarius/library.h"
#include "sagittarius/subr.h"
#include "sagittarius/reader.h"
#include "sagittarius/vm.h"
#include "sagittarius/gloc.h"
#include "sagittarius/writer.h"
#include "sagittarius/builtin-symbols.h"

static void syntax_print(SgObject obj, SgPort *port, SgWriteContext *ctx)
{
  Sg_Printf(port, UC("#<syntax %A>"), SG_SYNTAX(obj)->name);
}

SG_DEFINE_BUILTIN_CLASS_SIMPLE(Sg_SyntaxClass, syntax_print);

SgObject Sg_MakeSyntax(SgSymbol *name, SgObject proc)
{
  SgSyntax *z = SG_NEW(SgSyntax);
  SG_SET_CLASS(z, SG_CLASS_SYNTAX);
  z->name = name;
  z->proc = proc;
  return SG_OBJ(z);
}

static void macro_print(SgObject obj, SgPort *port, SgWriteContext *ctx)
{
  Sg_Printf(port, UC("#<macro %A>"), SG_MACRO(obj)->name);
}

SG_DEFINE_BUILTIN_CLASS_SIMPLE(Sg_MacroClass, macro_print);

SgObject Sg_MakeMacro(SgObject name, SgClosure *transformer, 
		      SgObject data, SgObject env, SgCodeBuilder *compiledCode)
{
  SgMacro *z = SG_NEW(SgMacro);
  SG_SET_CLASS(z, SG_CLASS_MACRO);
  SG_INIT_MACRO(z, name, transformer, data, env, compiledCode);
  return SG_OBJ(z);
}

static SgObject unwrap_rec(SgObject form, SgObject history)
{
  SgObject newh;
  if (!SG_PTRP(form)) return form;
  if (!SG_FALSEP(Sg_Memq(form, history))) return form;

  if (Sg_ConstantLiteralP(form)) return form;

  if (SG_PAIRP(form)) {
    SgObject ca, cd;
    newh = Sg_Cons(form, history);
    ca = unwrap_rec(SG_CAR(form), newh);
    cd = unwrap_rec(SG_CDR(form), newh);
    if (ca == SG_CAR(form) && cd == SG_CDR(form)) {
      return form;
    } else {
      return Sg_Cons(ca, cd);
    }
  }
  if (SG_IDENTIFIERP(form)) {
    return SG_IDENTIFIER_NAME(form);
  }
  if (SG_SYMBOLP(form)) {
    return form;
  }
  if (SG_VECTORP(form)) {
    int i, j, len = SG_VECTOR_SIZE(form);
    SgObject elt, *pelt = SG_VECTOR_ELEMENTS(form);
    newh = Sg_Cons(form, history);
    for (i = 0; i < len; i++, pelt++) {
      elt = unwrap_rec(*pelt, newh);
      if (elt != *pelt) {
	SgObject newvec = Sg_MakeVector(len, SG_FALSE);
	pelt = SG_VECTOR_ELEMENTS(form);
	for (j = 0; j < i; j++, pelt++) {
	  SG_VECTOR_ELEMENT(newvec, j) = *pelt;
	}
	SG_VECTOR_ELEMENT(newvec, i) = elt;
	for (; j < len; j++, pelt++) {
	  SG_VECTOR_ELEMENT(newvec, j) = unwrap_rec(*pelt, newh);
	}
	return newvec;
      }
    }
    return form;
  }
  return form;
}

/* convert all identifier to symbol */
SgObject Sg_UnwrapSyntax(SgObject form)
{
  return unwrap_rec(form, SG_NIL);
}

static SgObject macro_name(SgMacro *m)
{
  return m->name;
}

static SgObject macro_trans(SgMacro *m)
{
  return m->transformer;
}

static SgObject macro_data(SgMacro *m)
{
  return m->data;
}
static SgObject macro_env(SgMacro *m)
{
  return m->env;
}
static SgObject macro_code(SgMacro *m)
{
  SgCodeBuilder *cb = m->compiledCode;
  return (cb) ? cb: SG_FALSE;
}


static SgSlotAccessor macro_slots[] = {
  SG_CLASS_SLOT_SPEC("name", 0, macro_name, NULL),
  SG_CLASS_SLOT_SPEC("transformer", 1, macro_trans, NULL),
  SG_CLASS_SLOT_SPEC("data", 2, macro_data, NULL),
  SG_CLASS_SLOT_SPEC("env", 3, macro_env, NULL),
  SG_CLASS_SLOT_SPEC("compiled-code", 4, macro_code, NULL),
  { { NULL } }
};

void Sg__InitMacro()
{
  SgLibrary *lib = Sg_FindLibrary(SG_INTERN("(sagittarius clos)"), TRUE);
  Sg_InitStaticClass(SG_CLASS_MACRO, UC("<macro>"), lib, macro_slots, 0);
  Sg_InitStaticClass(SG_CLASS_SYNTAX, UC("<syntax>"), lib, NULL, 0);
}

/*
  end of file
  Local Variables:
  coding: utf-8-unix
  End:
*/
