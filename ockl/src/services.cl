/*===--------------------------------------------------------------------------
 *                   ROCm Device Libraries
 *
 * This file is distributed under the University of Illinois Open Source
 * License. See LICENSE.TXT for details.
 *===------------------------------------------------------------------------*/

#include "services.h"

long2
__ockl_call_host_function(ulong fptr,
                          ulong arg0, ulong arg1, ulong arg2, ulong arg3,
                          ulong arg4, ulong arg5, ulong arg6)
{
    return __ockl_hostcall_preview(SERVICE_ID_FUNCTION_CALL,
                                   fptr, arg0, arg1, arg2, arg3,
                                   arg4, arg5, arg6);
}
