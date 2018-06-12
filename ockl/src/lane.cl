/*===--------------------------------------------------------------------------
 *                   ROCm Device Libraries
 *
 * This file is distributed under the University of Illinois Open Source
 * License. See LICENSE.TXT for details.
 *===------------------------------------------------------------------------*/

#include "irif.h"
#include "ockl.h"

__attribute__((always_inline)) uint
OCKL_MANGLE_U32(lane)(void)
{
    if (__llvm_amdgcn_wavefrontsize() == 32) {
        return __llvm_amdgcn_mbcnt_lo(~0u, 0u);
    } else {
        return __llvm_amdgcn_mbcnt_hi(~0u, __llvm_amdgcn_mbcnt_lo(~0u, 0u));
    }
}

