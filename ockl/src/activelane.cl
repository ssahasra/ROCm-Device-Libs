/*===--------------------------------------------------------------------------
 *                   ROCm Device Libraries
 *
 * This file is distributed under the University of Illinois Open Source
 * License. See LICENSE.TXT for details.
 *===------------------------------------------------------------------------*/

#include "irif.h"
#include "ockl.h"

__attribute__((always_inline)) uint
OCKL_MANGLE_U32(activelane)(void)
{
    if (__llvm_amdgcn_wavefrontsize() == 32) {
        return __llvm_amdgcn_mbcnt_lo(__builtin_amdgcn_read_exec_lo(), 0u);
    } else {
        return __llvm_amdgcn_mbcnt_hi(__builtin_amdgcn_read_exec_hi(),
                __llvm_amdgcn_mbcnt_lo(__builtin_amdgcn_read_exec_lo(), 0u));
    }
}

