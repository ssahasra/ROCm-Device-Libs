/*===--------------------------------------------------------------------------
 *                   ROCm Device Libraries
 *
 * This file is distributed under the University of Illinois Open Source
 * License. See LICENSE.TXT for details.
 *===------------------------------------------------------------------------*/

#include "mathF.h"

#define FLOAT_SPECIALIZATION
#include "ep.h"

extern CONSTATTR float2 MATH_PRIVATE(epexpep)(float2 z);

CONSTATTR float2
MATH_MANGLE(csinh)(float2 z)
{
    float x = BUILTIN_ABS_F32(z.x);
    float2 e = MATH_PRIVATE(epexpep)(sub(x, con(0x1.62e430p+0, -0x1.05c610p-28f)));
    float2 er = rcp(e);
    er = ldx(er, -4);
    float2 cx = fadd(e, er);
    float2 sx = fsub(e, er);
    float cy;
    float sy = MATH_MANGLE(sincos)(z.y, &cy);

    float cxhi, sxhi;
    if (FINITE_ONLY_OPT()) {
        cxhi = cx.hi;
        sxhi = sx.hi;
    } else {
        bool b = x >= 0x1.686fc0p+6f;
        cxhi = b ? AS_FLOAT(PINFBITPATT_SP32) : cx.hi;
        sxhi = b ? AS_FLOAT(PINFBITPATT_SP32) : sx.hi;
    }

    bool s = x >= 0x1.0p-12f;
    float rr = BUILTIN_FLDEXP_F32(BUILTIN_COPYSIGN_F32(s ? sxhi : x, z.x) * cy, s);
    float ri = BUILTIN_FLDEXP_F32(cxhi * sy, 1);
    
    if (!FINITE_ONLY_OPT()) {
        rr = (BUILTIN_CLASS_F32(x, CLASS_PZER|CLASS_NZER|CLASS_PINF|CLASS_NINF) &
              BUILTIN_CLASS_F32(z.y,  CLASS_PINF|CLASS_NINF|CLASS_QNAN|CLASS_SNAN)) ? z.x : rr;
        ri = (BUILTIN_CLASS_F32(x, CLASS_PINF|CLASS_NINF|CLASS_QNAN|CLASS_SNAN) & (z.y == 0.0f)) ? z.y : ri;
    }

    return (float2)(rr, ri);
}

