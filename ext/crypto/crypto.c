/* crypto.c                                      -*- mode: c; coding: utf-8; -*-
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
#include <sagittarius.h>
#define LIBSAGITTARIUS_EXT_BODY
#include <sagittarius/extend.h>
#include "crypto.h"

/* GCM wrapper */
static int wrapped_gcm_process(unsigned char *pt,
			       unsigned char *ct,
			       unsigned long len,
			       cipher_gcm_state *gcm,
			       int direction)
{
  SgObject iv = gcm->spi->iv;
  unsigned long ivlen = SG_BVECTOR_SIZE(iv);
  int err;
  /* reset after encryption */
  gcm_add_aad(&gcm->gcm, NULL, 0); /* make it right state. */
  err = gcm_process(&gcm->gcm, pt, len, ct, direction);
  if (err == CRYPT_OK) {
    unsigned long taglen = sizeof(gcm->tag);
    err = gcm_done(&gcm->gcm, gcm->tag, &taglen);
  }
  /* we reset no matter what */
  gcm_reset(&gcm->gcm);
  gcm_add_iv(&gcm->gcm, SG_BVECTOR_ELEMENTS(iv), ivlen);
  return err;
}
static int gcm_encrypt(const unsigned char *pt,
		       unsigned char *ct,
		       unsigned long len,
		       cipher_gcm_state *gcm)
{
  return wrapped_gcm_process((unsigned char *)pt, ct, len, gcm, GCM_ENCRYPT);
}
static int gcm_decrypt(const unsigned char *ct,
		       unsigned char *pt,
		       unsigned long len,
		       cipher_gcm_state *gcm)
{
  return wrapped_gcm_process(pt, (unsigned char *)ct, len, gcm, GCM_DECRYPT);
}

static int gcm_setiv(unsigned char *IV, unsigned long *len, 
		     cipher_gcm_state *gcm)
{
  /* should we do this way? */
  gcm_reset(&gcm->gcm);
  gcm->spi->iv = Sg_MakeByteVectorFromU8Array(IV, *len);
  return gcm_add_iv(&gcm->gcm, IV, *len);
}

static int fake_gcm_done(cipher_gcm_state *gcm)
{
  gcm_reset(&gcm->gcm);		/* at least reset it */
  memset(gcm->tag, 0, sizeof(gcm->tag));
  return CRYPT_OK;
}

static int gcm_update_aad(cipher_gcm_state *gcm, 
			  unsigned char *aad, unsigned long len)
{
  return gcm_add_aad(&gcm->gcm, aad, len);
}

/* GCM wrapper end */


static void cipher_printer(SgObject self, SgPort *port, SgWriteContext *ctx)
{
  Sg_Printf(port, UC("#<cipher %S>"), SG_CIPHER(self)->spi);
}

static SgObject spi_allocate(SgClass *klass, SgObject initargs);

SgClass *Sg__CipherSpiCPL[] = {
  SG_CLASS_CIPHER_SPI,
  SG_CLASS_CRYPTO,
  SG_CLASS_TOP,
  NULL,
};

SG_DEFINE_ABSTRACT_CLASS(Sg_CryptoClass, NULL);
SG_DEFINE_BASE_CLASS(Sg_CipherSpiClass, SgCipherSpi,
		     NULL, NULL, NULL, spi_allocate,
		     Sg__CipherSpiCPL+1);

SG_DEFINE_BUILTIN_CLASS(Sg_CipherClass, cipher_printer,
			NULL, NULL, NULL, Sg__CipherSpiCPL+1);


static void builtin_cipher_spi_print(SgObject self, SgPort *port,
				     SgWriteContext *ctx)
{
  Sg_Printf(port, UC("#<spi %A>"), SG_BUILTIN_CIPHER_SPI(self)->name);
}
SG_DEFINE_BUILTIN_CLASS(Sg_BuiltinCipherSpiClass, builtin_cipher_spi_print,
			NULL, NULL, NULL, Sg__CipherSpiCPL);

static void finalize_cipher_spi(SgObject obj, void *data)
{
  SG_BUILTIN_CIPHER_SPI(obj)->done(&SG_BUILTIN_CIPHER_SPI(obj)->skey);
}

static SgObject spi_allocate(SgClass *klass, SgObject initargs)
{
  SgCipherSpi *spi = SG_ALLOCATE(SgCipherSpi, klass);
  SG_SET_CLASS(spi, klass);
  /* to keep backward compatibility */
  spi->updateAAD = SG_FALSE;
  spi->tag = SG_FALSE;
  spi->tagsize = SG_FALSE;
  /* for convenience */
  spi->padder = SG_FALSE;
  return SG_OBJ(spi);
}

static SgBuiltinCipherSpi *make_builtin_cipher_spi()
{
  SgBuiltinCipherSpi *c = SG_NEW(SgBuiltinCipherSpi);
  SG_SET_CLASS(c, SG_CLASS_BUILTIN_CIPHER_SPI);
  return c;
}

SgObject Sg_MakeBuiltinCipherSpi(SgString *name, SgCryptoMode mode,
				 SgObject ckey, SgObject iv, int rounds,
				 SgObject padder, int ctr_mode)
{
  const char *cname = Sg_Utf32sToUtf8s(name);
  SgBuiltinCipherSpi *spi = make_builtin_cipher_spi();
  int cipher = find_cipher(cname), err;
  SgByteVector *key;
  keysize_proc keysize;

  ASSERT(SG_BUILTIN_SYMMETRIC_KEY_P(ckey));

  key = SG_BUILTIN_SYMMETRIC_KEY(ckey)->secretKey;
  spi->name = name;
  spi->cipher = cipher;
  spi->key = SG_BUILTIN_SYMMETRIC_KEY(ckey);
  spi->iv = iv;
  spi->mode = mode;
  spi->rounds = rounds;
  spi->padder = padder;

  if (cipher == -1) {
    Sg_Error(UC("%S is not supported"), name);
    return SG_UNDEF;
  }
  keysize = cipher_descriptor[cipher].keysize;

  /* set up mode */
  switch (mode) {
  case MODE_ECB:
    err = ecb_start(cipher, SG_BVECTOR_ELEMENTS(key), SG_BVECTOR_SIZE(key),
		    rounds, &spi->skey.ecb_key);
    SG_INIT_CIPHER(spi, ecb_encrypt, ecb_decrypt,
		   NULL, NULL, ecb_done, keysize);
    break;
  case MODE_CBC:
    if (!SG_BVECTOR(iv)) {
      Sg_Error(UC("iv required on CBC mode"));
      return SG_UNDEF;
    }
    err = cbc_start(cipher, SG_BVECTOR_ELEMENTS(iv),
		    SG_BVECTOR_ELEMENTS(key), SG_BVECTOR_SIZE(key),
		    rounds, &spi->skey.cbc_key);
    SG_INIT_CIPHER(spi,
		   cbc_encrypt, cbc_decrypt, cbc_getiv, cbc_setiv,
		   cbc_done, keysize);
    break;
  case MODE_CFB:
    if (!SG_BVECTOR(iv)) {
      Sg_Error(UC("iv required on CFB mode"));
      return SG_UNDEF;
    }
    err = cfb_start(cipher, SG_BVECTOR_ELEMENTS(iv),
		    SG_BVECTOR_ELEMENTS(key), SG_BVECTOR_SIZE(key),
		    rounds, &spi->skey.cfb_key);
    SG_INIT_CIPHER(spi,
		   cfb_encrypt, cfb_decrypt, cfb_getiv, cfb_setiv,
		   cfb_done, keysize);
    break;
  case MODE_OFB:
    if (!SG_BVECTOR(iv)) {
      Sg_Error(UC("iv required on OFB mode"));
      return SG_UNDEF;
    }
    err =ofb_start(cipher, SG_BVECTOR_ELEMENTS(iv),
		   SG_BVECTOR_ELEMENTS(key), SG_BVECTOR_SIZE(key),
		   rounds, &spi->skey.ofb_key);
    SG_INIT_CIPHER(spi,
		   ofb_encrypt, ofb_decrypt, ofb_getiv, ofb_setiv,
		   ofb_done, keysize);
    break;
  case MODE_CTR:
    if (!SG_BVECTOR(iv)) {
      Sg_Error(UC("iv required on CTR mode"));
      return SG_UNDEF;
    }
    err = ctr_start(cipher, SG_BVECTOR_ELEMENTS(iv),
		    SG_BVECTOR_ELEMENTS(key), SG_BVECTOR_SIZE(key),
		    rounds,
		    /* counter size is 0 by default.
		       (using a full block length. see libtomcrypto manual.)
		    */
		    ctr_mode,
		    &spi->skey.ctr_key);
    SG_INIT_CIPHER(spi,
		   ctr_encrypt, ctr_decrypt, ctr_getiv, ctr_start,
		   ctr_done, keysize);
    break;
  case MODE_GCM:
    if (!SG_BVECTOR(iv)) {
      Sg_Error(UC("iv required on GCM mode"));
      return SG_UNDEF;
    }
    err = gcm_init(&spi->skey.cipher_gcm.gcm, cipher, 
		   SG_BVECTOR_ELEMENTS(key), SG_BVECTOR_SIZE(key));
    if (err == CRYPT_OK) {
      err = gcm_add_iv(&spi->skey.cipher_gcm.gcm, 
		       SG_BVECTOR_ELEMENTS(iv), SG_BVECTOR_SIZE(iv));
    }
    SG_INIT_CIPHER(spi, gcm_encrypt, gcm_decrypt, NULL, gcm_setiv,
		   fake_gcm_done, keysize);
    spi->update_aad = (update_aad_proc)gcm_update_aad;
    spi->skey.cipher_gcm.spi = spi;
    break;
  default:
    Sg_Error(UC("invalid mode %d"), mode);
    return SG_UNDEF;
  }
  if (err != CRYPT_OK) {
    Sg_Error(UC("%S initialization failed: %A"),
	     name, Sg_MakeStringC(error_to_string(err)));
    return SG_UNDEF;
  }
  Sg_RegisterFinalizer(spi, finalize_cipher_spi, NULL);
  return SG_OBJ(spi);
}

SgObject Sg_CreateCipher(SgObject spi)
{
  SgCipher *c = SG_NEW(SgCipher);
  SG_SET_CLASS(c, SG_CLASS_CIPHER);
  c->spi = spi;
  return SG_OBJ(c);
}

static SgObject check_intp(SgObject result, void **data)
{
  if (SG_INTP(result)) return result;
  else return SG_MAKE_INT(-1);
}

SgObject Sg_VMCipherSuggestKeysize(SgCipher *cipher, int keysize)
{
  SgObject spi = cipher->spi;

  if (SG_BUILTIN_CIPHER_SPI_P(spi)) {
    int err;
    if ((err = SG_BUILTIN_CIPHER_SPI(spi)->keysize(&keysize)) != CRYPT_OK) {
      Sg_Error(UC("Failed to get key size: %A"),
	       Sg_MakeStringC(error_to_string(err)));
      return SG_MAKE_INT(-1);
    }
    return SG_MAKE_INT(keysize);
  } else {
    /* must be others */
    if (!SG_PROCEDUREP(SG_CIPHER_SPI(spi)->keysize)) {
      Sg_Error(UC("cipher does not support keysize %S"), cipher);
      return SG_MAKE_INT(-1);	/* dummy */
    }
    Sg_VMPushCC(check_intp, NULL, 0);
    return Sg_VMApply1(SG_CIPHER_SPI(spi)->keysize, SG_MAKE_INT(keysize));
  }
}

int Sg_CipherBlockSize(SgCipher *cipher)
{
  SgObject spi = cipher->spi;
  if (SG_BUILTIN_CIPHER_SPI_P(spi)) {
    return cipher_descriptor[SG_BUILTIN_CIPHER_SPI(spi)->cipher].block_length;
  } else {
    SgObject r = SG_CIPHER_SPI(spi)->blocksize;
    if (SG_INTP(r)) return SG_INT_VALUE(r);
    else return -1;
  }
}

static SgObject sym_after_padding(SgObject data, void **d)
{
  SgCipher *crypto = SG_CIPHER(d[0]);
  SgBuiltinCipherSpi *spi = SG_BUILTIN_CIPHER_SPI(crypto->spi);
  int len = SG_BVECTOR_SIZE(data);
  SgObject ct = Sg_MakeByteVector(len, 0);
  int err = spi->encrypt(SG_BVECTOR_ELEMENTS(data), SG_BVECTOR_ELEMENTS(ct),
			 len, &spi->skey);
  if (err != CRYPT_OK) {
    Sg_Error(UC("cipher-encrypt: %A"), error_to_string(err));
    return SG_UNDEF;		/* dummy */
  }
  return SG_OBJ(ct);
}

static SgObject symmetric_encrypt(SgCipher *crypto, SgByteVector *d)
{
  SgObject data = d;	/* cipher text */
  SgBuiltinCipherSpi *spi = SG_BUILTIN_CIPHER_SPI(crypto->spi);

  ASSERT(SG_BUILTIN_CIPHER_SPI_P(spi));

  if (!SG_FALSEP(spi->padder)) {
    struct ltc_cipher_descriptor *desc = &cipher_descriptor[spi->cipher];
    int block_size = desc->block_length;
    void *d[1];
    d[0] = crypto;
    Sg_VMPushCC(sym_after_padding, d, 1);
    return Sg_VMApply3(spi->padder, data, SG_MAKE_INT(block_size), SG_TRUE);
  } else {
    void *d[1];
    d[0] = crypto;
    return sym_after_padding(data, d);
  }
}

static SgObject pub_enc_after_padding(SgObject result, void **data)
{
  SgCipher *crypto = SG_CIPHER(data[0]);
  return Sg_VMApply2(SG_CIPHER_SPI(crypto->spi)->encrypter, result, 
		     SG_CIPHER_SPI(crypto->spi)->key);
}

static SgObject public_key_encrypt(SgCipher *crypto, SgByteVector *d)
{
  SgObject data = d;
  if (!SG_FALSEP(SG_CIPHER_SPI(crypto->spi)->padder)) {
    void *d[1];
    d[0] = crypto;
    Sg_VMPushCC(pub_enc_after_padding, d, 1);
    return Sg_VMApply2(SG_CIPHER_SPI(crypto->spi)->padder, data, SG_TRUE);
  }
  return Sg_VMApply2(SG_CIPHER_SPI(crypto->spi)->encrypter, data, 
		   SG_CIPHER_SPI(crypto->spi)->key);
}

SgObject Sg_VMCipherEncrypt(SgCipher *crypto, SgByteVector *data)
{
  if (SG_BUILTIN_CIPHER_SPI_P(crypto->spi)) {
    return symmetric_encrypt(crypto, data);
  } else {
    return public_key_encrypt(crypto, data);
  }
}

static SgObject symmetric_decrypt(SgCipher *crypto, SgByteVector *data)
{
  SgBuiltinCipherSpi *spi = SG_BUILTIN_CIPHER_SPI(crypto->spi);
  SgObject pt;			/* plain text */
  int len = SG_BVECTOR_SIZE(data), err;

  pt = Sg_MakeByteVector(len, 0);
  err = spi->decrypt(SG_BVECTOR_ELEMENTS(data), SG_BVECTOR_ELEMENTS(pt),
		     len, &spi->skey);
  if (err != CRYPT_OK) {
    Sg_Error(UC("cipher-decrypt: %A"), Sg_MakeStringC(error_to_string(err)));
    return SG_UNDEF;
  }

  if (!SG_FALSEP(spi->padder)) {
    struct ltc_cipher_descriptor *desc = &cipher_descriptor[spi->cipher];
    int block_size = desc->block_length;
    /* drop padding */
    return Sg_VMApply3(spi->padder, pt, SG_MAKE_INT(block_size), SG_FALSE);
  }
  return pt;			/* just return the value */
}

static SgObject pub_dec_after_decrypt(SgObject result, void **data)
{
  SgCipher *crypto = SG_CIPHER(data[0]);
  if (!SG_FALSEP(SG_CIPHER_SPI(crypto->spi)->padder)) {
    return Sg_VMApply2(SG_CIPHER_SPI(crypto->spi)->padder, result, SG_FALSE);
  }
  return result;
}

static SgObject public_key_decrypt(SgCipher *crypto, SgByteVector *data)
{
  void *d[1];
  d[0] = crypto;
  Sg_VMPushCC(pub_dec_after_decrypt, d, 1);
  return Sg_VMApply2(SG_CIPHER_SPI(crypto->spi)->decrypter, SG_OBJ(data),
		     SG_CIPHER_SPI(crypto->spi)->key);
}


SgObject Sg_VMCipherDecrypt(SgCipher *crypto, SgByteVector *data)
{
  if (SG_BUILTIN_CIPHER_SPI_P(crypto->spi)) {
    return symmetric_decrypt(crypto, data);
  } else {
    return public_key_decrypt(crypto, data);
  }
}

SgObject Sg_VMCipherUpdateAAD(SgCipher *crypto, SgByteVector *data, 
			      int s, int e)
{
  if (SG_BUILTIN_CIPHER_SPI_P(crypto->spi)) {
    SgBuiltinCipherSpi *spi = SG_BUILTIN_CIPHER_SPI(crypto->spi);
    if (spi->update_aad) {
      unsigned long len = SG_BVECTOR_SIZE(data);
      SG_CHECK_START_END(s, e, len);
      int err = spi->update_aad(&spi->skey, SG_BVECTOR_ELEMENTS(data)+s, e-s);
      if (err != CRYPT_OK) {
	Sg_Error(UC("cipher-update-add!: %A"), error_to_string(err));
      }
      return SG_TRUE;
    }
  } else if (SG_PROCEDUREP(SG_CIPHER_SPI(crypto->spi)->updateAAD)) {
    SgObject tmp;
    int len = SG_BVECTOR_SIZE(data);
    SG_CHECK_START_END(s, e, len);
    if (s == 0 && e == len) {
      tmp = SG_OBJ(data);
    } else {
      tmp = Sg_MakeByteVectorFromU8Array(SG_BVECTOR_ELEMENTS(data)+s, e-1);
    }
    return Sg_VMApply1(SG_PROCEDURE(SG_CIPHER_SPI(crypto->spi)->updateAAD), 
		       tmp);
  }
  /* nothing to be done */
  return SG_FALSE;
}

SgObject Sg_VMCipherTag(SgCipher *crypto, SgByteVector *dst)
{
  if (SG_BVECTOR_LITERALP(dst)) {
    Sg_Error(UC("cipher-tag!: got literal bytevector %A"), dst);
  }
  if (SG_BUILTIN_CIPHER_SPI_P(crypto->spi)) {
    SgBuiltinCipherSpi *spi = SG_BUILTIN_CIPHER_SPI(crypto->spi);
    int i;
    switch (spi->mode) {
    case MODE_GCM:
      for (i = 0; 
	   i < SG_BVECTOR_SIZE(dst) && i < sizeof(spi->skey.cipher_gcm.tag);
	   i++) {
	SG_BVECTOR_ELEMENT(dst, i) = spi->skey.cipher_gcm.tag[i];
      }
      return SG_MAKE_INT(i);
    default: break;
    }
  } else if (SG_PROCEDUREP(SG_CIPHER_SPI(crypto->spi)->tag)) {
    /* should return integer but we don't check. */
    return Sg_VMApply1(SG_PROCEDURE(SG_CIPHER_SPI(crypto->spi)->tag), dst);
  }
  return SG_MAKE_INT(0);
}

static SgObject builtin_tagsize(SgBuiltinCipherSpi *spi)
{
  switch (spi->mode) {
  case MODE_GCM: return SG_MAKE_INT(sizeof(spi->skey.cipher_gcm.tag));
  default: return SG_MAKE_INT(0);
  }
}

SgObject Sg_VMCipherMaxTagSize(SgCipher *crypto)
{
  if (SG_BUILTIN_CIPHER_SPI_P(crypto->spi)) {
    SgBuiltinCipherSpi *spi = SG_BUILTIN_CIPHER_SPI(crypto->spi);
    return builtin_tagsize(spi);
  } else if (SG_INTP(SG_CIPHER_SPI(crypto->spi)->tagsize)) {
    return SG_CIPHER_SPI(crypto->spi)->tagsize;
  }
  return SG_MAKE_INT(0);
}

SgObject Sg_VMCipherSignature(SgCipher *crypto, SgByteVector *data, 
			      SgObject opt)
{
  if (SG_BUILTIN_CIPHER_SPI_P(crypto->spi)) {
    Sg_Error(UC("builtin cipher does not support signing, %S"), crypto);
    return SG_UNDEF;		/* dummy */
  } else {
    SgObject h = SG_NIL, t = SG_NIL;
    ASSERT(SG_CIPHER_SPI(crypto->spi)->signer);
    if (!SG_PROCEDUREP(SG_CIPHER_SPI(crypto->spi)->signer)) {
      Sg_Error(UC("cipher does not support signing, %S"), crypto);
    }
    SG_APPEND1(h, t, data);
    SG_APPEND1(h, t, SG_CIPHER_SPI(crypto->spi)->key);
    SG_APPEND(h, t, opt);
    return Sg_VMApply(SG_CIPHER_SPI(crypto->spi)->signer, h);
  }
}

SgObject Sg_VMCipherVerify(SgCipher *crypto, SgByteVector *M, SgByteVector *S,
			   SgObject opt)
{
  if (SG_BUILTIN_CIPHER_SPI_P(crypto->spi)) {
    Sg_Error(UC("builtin cipher does not support verify, %S"), crypto);
    return SG_UNDEF;		/* dummy */
  } else {
    SgObject h = SG_NIL, t = SG_NIL;
    ASSERT(SG_CIPHER_SPI(crypto->spi)->verifier);
    if (!SG_PROCEDUREP(SG_CIPHER_SPI(crypto->spi)->verifier)) {
      Sg_Error(UC("cipher does not support verify, %S"), crypto);
    }
    SG_APPEND1(h, t, M);
    SG_APPEND1(h, t, S);
    SG_APPEND1(h, t, SG_CIPHER_SPI(crypto->spi)->key);
    SG_APPEND(h, t, opt);
    return Sg_VMApply(SG_CIPHER_SPI(crypto->spi)->verifier, h);
  }
}

struct table_entry_t
{
  SgObject name;
  SgObject spi;
  struct table_entry_t *next;
};

static struct
{
  int dummy;
  struct table_entry_t *entries;
} table = { 1, NULL };

/* WATCOM has somehow the same name already */
#define lock lock_
static SgInternalMutex lock;

int Sg_RegisterSpi(SgObject name, SgObject spiClass)
{
  struct table_entry_t *e;
  SgObject r = Sg_LookupSpi(name);
  /* already there, we won't overwrite.
     TODO, should we overwrite this?
   */
  if (!SG_FALSEP(r)) return FALSE;

  Sg_LockMutex(&lock);
  e = SG_NEW(struct table_entry_t);
  e->name = name;
  e->spi = spiClass;
  e->next = table.entries;
  table.entries = e;
  Sg_UnlockMutex(&lock);
  return TRUE;
}

SgObject Sg_LookupSpi(SgObject name)
{
  struct table_entry_t *all;
  Sg_LockMutex(&lock);
  for (all = table.entries; all; all = all->next) {
    if (Sg_EqualP(name, all->name)) {
      Sg_UnlockMutex(&lock);
      return all->spi;
    }
  }
  Sg_UnlockMutex(&lock);
  /* now we need to check builtin */
  if (SG_KEYWORDP(name)) {
    const char *cname = Sg_Utf32sToUtf8s(SG_KEYWORD_NAME(name));
    if(find_cipher(cname) != -1) return SG_TRUE;
  }
  return SG_FALSE;
}



static SgObject ci_name(SgCipherSpi *spi)
{
  return spi->name;
}

static SgObject ci_key(SgCipherSpi *spi)
{
  return spi->key;
}

static SgObject ci_encrypt(SgCipherSpi *spi)
{
  return spi->encrypter;
}

static SgObject ci_decrypt(SgCipherSpi *spi)
{
  return spi->decrypter;
}

static SgObject ci_padder(SgCipherSpi *spi)
{
  return spi->padder;
}

static SgObject ci_signer(SgCipherSpi *spi)
{
  return spi->signer;
}

static SgObject ci_verifier(SgCipherSpi *spi)
{
  return spi->verifier;
}

static SgObject ci_keysize(SgCipherSpi *spi)
{
  return spi->keysize;
}

static SgObject ci_data(SgCipherSpi *spi)
{
  return spi->data;
}

static SgObject ci_blocksize(SgCipherSpi *spi)
{
  return spi->blocksize;
}

static SgObject ci_iv(SgCipherSpi *spi)
{
  return spi->iv;
}

static SgObject ci_updateAAD(SgCipherSpi *spi)
{
  return spi->updateAAD;
}

static SgObject ci_tag(SgCipherSpi *spi)
{
  return spi->tag;
}

static SgObject ci_tagsize(SgCipherSpi *spi)
{
  return spi->tagsize;
}

static void ci_name_set(SgCipherSpi *spi, SgObject value)
{
  spi->name = value;
}
static void ci_key_set(SgCipherSpi *spi, SgObject value)
{
  spi->key = value;
}
static void ci_encrypt_set(SgCipherSpi *spi, SgObject value)
{
  if (!SG_PROCEDUREP(value)) {
    Sg_Error(UC("procedure required, but got %S"), value);
    return;
  }
  spi->encrypter = value;
}
static void ci_decrypt_set(SgCipherSpi *spi, SgObject value)
{
  if (!SG_PROCEDUREP(value)) {
    Sg_Error(UC("procedure required, but got %S"), value);
    return;
  }
  spi->decrypter = value;
}
static void ci_padder_set(SgCipherSpi *spi, SgObject value)
{
  if (SG_FALSEP(value) || SG_PROCEDUREP(value)) {
    spi->padder = value;
  } else {
    Sg_Error(UC("padder must be #f or procedure, but got %S."), value);
  }
}
static void ci_signer_set(SgCipherSpi *spi, SgObject value)
{
  spi->signer = value;
}
static void ci_verifier_set(SgCipherSpi *spi, SgObject value)
{
  spi->verifier = value;
}
static void ci_keysize_set(SgCipherSpi *spi, SgObject value)
{
  spi->keysize = value;
}
static void ci_data_set(SgCipherSpi *spi, SgObject value)
{
  spi->data = value;
}

static void ci_blocksize_set(SgCipherSpi *spi, SgObject value)
{
  spi->blocksize = value;
}

static void ci_iv_set(SgCipherSpi *spi, SgObject value)
{
  spi->iv = value;
}

static void ci_updateAAD_set(SgCipherSpi *spi, SgObject value)
{
  if (SG_FALSEP(value) || SG_PROCEDUREP(value)) {
    spi->updateAAD = value;
  } else {
    Sg_Error(UC("updateAAD must be #f or procedure, but got %S."), value);
  }
}

static void ci_tag_set(SgCipherSpi *spi, SgObject value)
{
  if (SG_FALSEP(value) || SG_PROCEDUREP(value)) {
    spi->tag = value;
  } else {
    Sg_Error(UC("tag must be #f or procedure, but got %S."), value);
  }
}

static void ci_tagsize_set(SgCipherSpi *spi, SgObject value)
{
  if (SG_INTP(value)) {
    spi->tagsize = value;
  } else {
    Sg_Error(UC("tag must be fixnum, but got %S."), value);
  }
}

/* slots for cipher-spi */
static SgSlotAccessor cipher_spi_slots[] = {
  SG_CLASS_SLOT_SPEC("name",     0, ci_name,    ci_name_set),
  SG_CLASS_SLOT_SPEC("key",      1, ci_key,     ci_key_set),
  SG_CLASS_SLOT_SPEC("encrypt",  2, ci_encrypt, ci_encrypt_set),
  SG_CLASS_SLOT_SPEC("decrypt",  3, ci_decrypt, ci_decrypt_set),
  SG_CLASS_SLOT_SPEC("padder",   4, ci_padder,  ci_padder_set),
  SG_CLASS_SLOT_SPEC("signer",   5, ci_signer,  ci_signer_set),
  SG_CLASS_SLOT_SPEC("verifier", 6, ci_verifier,ci_verifier_set),
  SG_CLASS_SLOT_SPEC("keysize",  7, ci_keysize, ci_keysize_set),
  SG_CLASS_SLOT_SPEC("data",     8, ci_data,    ci_data_set),
  SG_CLASS_SLOT_SPEC("blocksize",9, ci_blocksize,  ci_blocksize_set),
  SG_CLASS_SLOT_SPEC("iv",       10, ci_iv,  ci_iv_set),
  SG_CLASS_SLOT_SPEC("update-aad",11, ci_updateAAD,  ci_updateAAD_set),
  SG_CLASS_SLOT_SPEC("tag",      12, ci_tag,  ci_tag_set),
  SG_CLASS_SLOT_SPEC("tagsize",  13, ci_tagsize,  ci_tagsize_set),
  { { NULL } }
};


static SgObject bci_name(SgBuiltinCipherSpi *spi)
{
  return spi->name;
}

static SgObject bci_iv(SgBuiltinCipherSpi *spi)
{
  if (spi->getiv) {
    unsigned long len = cipher_descriptor[spi->cipher].block_length;
    SgObject iv = Sg_MakeByteVector(len, 0);
    spi->getiv(SG_BVECTOR_ELEMENTS(iv), &len, &spi->skey);
    return iv;
  }
  return SG_FALSE;
}

static void bci_iv_set(SgBuiltinCipherSpi *spi, SgObject value)
{
  unsigned long len;
  if (!spi->setiv) {
    Sg_Error(UC("target cipher does not have iv %S"), spi);
  }
  if (!SG_BVECTORP(value)) {
    Sg_Error(UC("iv must be bytevector. %S"), value);
  }
  len = cipher_descriptor[spi->cipher].block_length;
  if (SG_BVECTOR_SIZE(value) != (long)len) {
    Sg_Error(UC("invalid size of iv. %S"), value);
  }
  spi->setiv(SG_BVECTOR_ELEMENTS(value), &len, &spi->skey);
}

static SgObject bci_keysize(SgBuiltinCipherSpi *spi)
{
  return SG_MAKE_INT(SG_BVECTOR_SIZE(spi->key));
}


static SgObject bci_blocksize(SgBuiltinCipherSpi *spi)
{
  return SG_MAKE_INT(cipher_descriptor[spi->cipher].block_length);
}

static SgObject invalid_ref(SgBuiltinCipherSpi *spi)
{
  Sg_Error(UC("can not refer this builtin spi slots"));
  return SG_UNDEF;		/* dummy */
}

static void invalid_set(SgBuiltinCipherSpi *spi, SgObject value)
{
  Sg_Error(UC("can not set this builtin spi slots"));
}

static SgSlotAccessor builtin_cipher_spi_slots[] = {
  SG_CLASS_SLOT_SPEC("name",     0, bci_name,    invalid_set),
  SG_CLASS_SLOT_SPEC("key",      1, invalid_ref, invalid_set),
  SG_CLASS_SLOT_SPEC("encrypt",  2, invalid_ref, invalid_set),
  SG_CLASS_SLOT_SPEC("decrypt",  3, invalid_ref, invalid_set),
  SG_CLASS_SLOT_SPEC("padder",   4, invalid_ref, invalid_set),
  SG_CLASS_SLOT_SPEC("signer",   5, invalid_ref, invalid_set),
  SG_CLASS_SLOT_SPEC("verifier", 6, invalid_ref, invalid_set),
  SG_CLASS_SLOT_SPEC("keysize",  7, bci_keysize, invalid_set),
  SG_CLASS_SLOT_SPEC("data",     8, invalid_ref, invalid_set),
  SG_CLASS_SLOT_SPEC("blocksize",9, bci_blocksize, invalid_set),
  SG_CLASS_SLOT_SPEC("iv",       10, bci_iv, bci_iv_set),
  SG_CLASS_SLOT_SPEC("updateAAD",11, invalid_ref,  invalid_set),
  SG_CLASS_SLOT_SPEC("tag",      12, invalid_ref,  invalid_set),
  SG_CLASS_SLOT_SPEC("tagsize",  13, builtin_tagsize,  invalid_set),
  { { NULL } }
};

SG_DEFINE_GENERIC(Sg_GenericCipherBlockSize, Sg_NoNextMethod, NULL);

/* original one */
static SgObject cipher_blocksize_c_impl(SgObject *args, int argc, void *data)
{
  /* type must be check by here */
  return SG_MAKE_INT(Sg_CipherBlockSize(SG_CIPHER(args[0])));
}
SG_DEFINE_SUBR(cipher_blocksize_c, 1, 0, cipher_blocksize_c_impl,
	       SG_FALSE, NULL);
static SgClass *cipher_blocksize_c_SPEC[] = {
  SG_CLASS_CIPHER
};
static SG_DEFINE_METHOD(cipher_blocksize_c_rec,
			&Sg_GenericCipherBlockSize,
			1, 0, cipher_blocksize_c_SPEC, &cipher_blocksize_c);

/* keyword (name) one */
static SgObject cipher_blocksize_k_impl(SgObject *args, int argc, void *data)
{
  SgString *name = SG_KEYWORD_NAME(args[0]);
  const char *cname = Sg_Utf32sToUtf8s(name);
  int cipher = find_cipher(cname);
  if (cipher == -1) {
    Sg_Error(UC("%A is not supported"), name);
  }
  return SG_MAKE_INT(cipher_descriptor[cipher].block_length);
}
SG_DEFINE_SUBR(cipher_blocksize_k, 1, 0, cipher_blocksize_k_impl,
	       SG_FALSE, NULL);
static SgClass *cipher_blocksize_k_SPEC[] = {
  SG_CLASS_KEYWORD
};
static SG_DEFINE_METHOD(cipher_blocksize_k_rec,
			&Sg_GenericCipherBlockSize,
			1, 0, cipher_blocksize_k_SPEC, &cipher_blocksize_k);

extern void Sg__Init_crypto_stub(SgLibrary *lib);
SG_CDECL_BEGIN
extern void Sg__InitKey(SgLibrary *lib);
SG_CDECL_END

SG_EXTENSION_ENTRY void CDECL Sg_Init_sagittarius__crypto()
{
  SgLibrary *lib;
  SG_INIT_EXTENSION(sagittarius__crypto);

  lib = SG_LIBRARY(Sg_FindLibrary(SG_INTERN("(sagittarius crypto)"),
				  FALSE));
  Sg_InitBuiltinGeneric(&Sg_GenericCipherBlockSize, 
			UC("cipher-blocksize"), lib);
  Sg_InitBuiltinMethod(&cipher_blocksize_c_rec);
  Sg_InitBuiltinMethod(&cipher_blocksize_k_rec);

  Sg__Init_crypto_stub(lib);

  Sg__InitKey(lib);

  Sg_InitMutex(&lock, FALSE);
  /* initialize libtomcrypt */
#define REGISTER_CIPHER(cipher)						\
  if (register_cipher(cipher) == -1) {					\
    Sg_Warn(UC("Unable to register %S cipher"),				\
	    Sg_MakeStringC((cipher)->name));				\
  }

  REGISTER_CIPHER(&blowfish_desc);
  REGISTER_CIPHER(&xtea_desc);
  REGISTER_CIPHER(&rc2_desc);
  REGISTER_CIPHER(&rc5_desc);
  REGISTER_CIPHER(&rc6_desc);
  REGISTER_CIPHER(&safer_k64_desc);
  REGISTER_CIPHER(&safer_sk64_desc);
  REGISTER_CIPHER(&safer_k128_desc);
  REGISTER_CIPHER(&safer_sk128_desc);
  REGISTER_CIPHER(&saferp_desc);
  REGISTER_CIPHER(&aes_desc);
  REGISTER_CIPHER(&twofish_desc);
  REGISTER_CIPHER(&des_desc);
  REGISTER_CIPHER(&des3_desc);
  REGISTER_CIPHER(&cast5_desc);
  REGISTER_CIPHER(&noekeon_desc);
  REGISTER_CIPHER(&skipjack_desc);
  REGISTER_CIPHER(&anubis_desc);
  REGISTER_CIPHER(&khazad_desc);
  REGISTER_CIPHER(&kseed_desc);
  REGISTER_CIPHER(&kasumi_desc);
  REGISTER_CIPHER(&camellia_desc);

  /* put mode */
#define MODE_CONST(name)					\
  Sg_MakeBinding(lib, SG_INTERN(#name), SG_MAKE_INT(name), TRUE)

  MODE_CONST(MODE_ECB);
  MODE_CONST(MODE_CBC);
  MODE_CONST(MODE_CFB);
  MODE_CONST(MODE_OFB);
  MODE_CONST(MODE_CTR);
  MODE_CONST(MODE_GCM);
  MODE_CONST(CTR_COUNTER_LITTLE_ENDIAN);
  MODE_CONST(CTR_COUNTER_BIG_ENDIAN);
  MODE_CONST(LTC_CTR_RFC3686);

  Sg_InitStaticClass(SG_CLASS_CRYPTO, UC("<crypto>"), lib, NULL, 0);
  Sg_InitStaticClass(SG_CLASS_CIPHER, UC("<cipher>"), lib, NULL, 0);
  Sg_InitStaticClass(SG_CLASS_CIPHER_SPI, UC("<cipher-spi>"), lib,
		     cipher_spi_slots, 0);
  Sg_InitStaticClass(SG_CLASS_BUILTIN_CIPHER_SPI,
		     UC("<builtin-cipher-spi>"), lib,
		     builtin_cipher_spi_slots, 0);
}
