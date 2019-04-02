/*===--------------------------------------------------------------------------
 *                   ROCm Device Libraries
 *
 * This file is distributed under the University of Illinois Open Source
 * License. See LICENSE.TXT for details.
 *===------------------------------------------------------------------------*/

#include "oclc.h"
#include "irif.h"
#include "ockl.h"

#define ATTR __attribute__((always_inline))

// XXX from llvm/include/llvm/IR/InstrTypes.h
#define ICMP_NE 33

ATTR bool
OCKL_MANGLE_I32(wfany)(int e)
{
    if (__oclc_wavefrontsize64) {
        return __llvm_amdgcn_icmp_i64_i32(e, 0, ICMP_NE) != 0UL;
    } else {
        return __llvm_amdgcn_icmp_i32_i32(e, 0, ICMP_NE) != 0U;
    }
}

ATTR bool
OCKL_MANGLE_I32(wfall)(int e)
{
    if (__oclc_wavefrontsize64) {
        return __llvm_amdgcn_icmp_i64_i32(e, 0, ICMP_NE) == __builtin_amdgcn_read_exec();
    } else {
        return __llvm_amdgcn_icmp_i32_i32(e, 0, ICMP_NE) == __builtin_amdgcn_read_exec_lo();
    }
}


ATTR bool
OCKL_MANGLE_I32(wfsame)(int e)
{
    if (__oclc_wavefrontsize64) {
        ulong u = __llvm_amdgcn_icmp_i64_i32(e, 0, ICMP_NE) != 0UL;
        return (u == 0UL) | (u == __builtin_amdgcn_read_exec());
    } else {
        uint u = __llvm_amdgcn_icmp_i32_i32(e, 0, ICMP_NE) != 0U;
        return (u == 0UL) | (u == __builtin_amdgcn_read_exec_lo());
    }
}

