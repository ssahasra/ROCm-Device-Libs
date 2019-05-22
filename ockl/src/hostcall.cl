/*===--------------------------------------------------------------------------
 *                   ROCm Device Libraries
 *
 * This file is distributed under the University of Illinois Open Source
 * License. See LICENSE.TXT for details.
 *===------------------------------------------------------------------------*/

#include <ockl.h>

/** \brief Internal implementation of hostcall.
 *
 *  *** INTERNAL USE ONLY ***
 *  Internal function, not safe for direct use in user
 *  code. Application kernels must only use __ockl_hostcall_preview()
 *  defined below.
 */
extern long2
__ockl_hostcall_internal(void *buffer, uint service_id,
                         ulong arg0, ulong arg1, ulong arg2, ulong arg3,
                         ulong arg4, ulong arg5, ulong arg6, ulong arg7);

/** \brief Submit a wave-wide hostcall packet.
 *  \param service_id The service to be invoked on the host.
 *  \param arg0 Up to eight parameters (arg0..arg7)
 *  \return Two 64-bit values.
 *
 *  The hostcall is executed for all active threads in the
 *  wave. #service_id must be uniform across the active threads,
 *  otherwise behaviour is undefined. The service parameters may be
 *  different for each active thread, and correspondingly, the
 *  returned values are also different.
 *
 *  The contents of the input parameters and the return values are
 *  defined by the service being invoked.
 *
 *  *** PREVIEW FEATURE ***
 *  This is a feature preview and considered alpha quality only;
 *  behaviour may vary between ROCm releases. Device code that invokes
 *  hostcall can be launched only on the ROCm release that it was
 *  compiled for, otherwise behaviour is undefined.
 */
long2
__ockl_hostcall_preview(uint service_id,
                        ulong arg0, ulong arg1, ulong arg2, ulong arg3,
                        ulong arg4, ulong arg5, ulong arg6, ulong arg7)
{
    // Retrieve the buffer pointer passed as an implicit kernel
    // argument. This is at offset 3, which is the same as the OpenCL
    // printf buffer.
    __constant size_t *argptr =
        (__constant size_t *)__builtin_amdgcn_implicitarg_ptr();
    void *buffer = (void *)argptr[3];

    return __ockl_hostcall_internal(buffer, service_id, arg0, arg1, arg2, arg3,
                                    arg4, arg5, arg6, arg7);
}

/** Enums that describe the message descriptor fields.
 */
typedef enum {
    DESCRIPTOR_OFFSET_FLAGS = 0,
    DESCRIPTOR_OFFSET_BYTES = 8,
    DESCRIPTOR_OFFSET_MSG_ID = 16
} descriptor_offset_t;

typedef enum {
    DESCRIPTOR_WIDTH_FLAGS = 8,
    DESCRIPTOR_WIDTH_BYTES = 8,
    DESCRIPTOR_WIDTH_MSG_ID = 48
} descriptor_width_t;

typedef enum {
    DESCRIPTOR_FLAG_BEGIN = 1,
    DESCRIPTOR_FLAG_END = 2
} descriptor_flag_t;

static ulong
msg_set_bytes(ulong pd, uchar len)
{
    ulong reset_mask = ~(((1UL << DESCRIPTOR_WIDTH_BYTES) - 1) << DESCRIPTOR_OFFSET_BYTES);
    return (pd & reset_mask) | ((ulong)len << DESCRIPTOR_OFFSET_BYTES);
}

static ulong
msg_set_begin_flag(ulong pd)
{
    return pd | ((ulong)DESCRIPTOR_FLAG_BEGIN << DESCRIPTOR_OFFSET_FLAGS);
}

static ulong
msg_reset_begin_flag(ulong pd)
{
    ulong reset_mask = ~((ulong)DESCRIPTOR_FLAG_BEGIN << DESCRIPTOR_OFFSET_FLAGS);
    return pd & reset_mask;
}

static ulong
msg_get_end_flag(ulong pd)
{
    return pd & ((ulong)DESCRIPTOR_FLAG_END << DESCRIPTOR_OFFSET_FLAGS);
}

static ulong
msg_reset_end_flag(ulong pd)
{
    ulong reset_mask = ~((ulong)DESCRIPTOR_FLAG_END << DESCRIPTOR_OFFSET_FLAGS);
    return pd & reset_mask;
}

static ulong
msg_set_end_flag(ulong pd)
{
    return pd | ((ulong)DESCRIPTOR_FLAG_END << DESCRIPTOR_OFFSET_FLAGS);
}

static long2
message_uchar(uint service_id,
              ulong msg_desc, const uchar *data, uint len)
{
    msg_desc = msg_set_bytes(msg_desc, len);

#define PACK_ULONG(xxx)                                 \
    ulong xxx = 0;                                      \
    if (len > 0) {                                      \
        uint plen = (len > 8) ? 8 : len;                \
        for (uint ii = 0; ii != plen; ++ii) {           \
            xxx |= (ulong)data[ii] << (ii * 8);         \
        }                                               \
        len -= plen;                                    \
        data += plen;                                   \
    }

    PACK_ULONG(arg1);
    PACK_ULONG(arg2);
    PACK_ULONG(arg3);
    PACK_ULONG(arg4);
    PACK_ULONG(arg5);
    PACK_ULONG(arg6);
    PACK_ULONG(arg7);

    long2 result
        = __ockl_hostcall_preview(service_id,
                                msg_desc, arg1, arg2, arg3,
                                arg4, arg5, arg6, arg7);

    return result.x;
}

long2
__ockl_hostcall_message_uchar(uint service_id,
                           ulong msg_desc, const uchar *data, uint len)
{
    ulong end_flag = msg_get_end_flag(msg_desc);
    ulong desc = msg_reset_end_flag(msg_desc);
    long2 retval = {0, 0};

    // Use a waterfall loop until the compiler's handling of
    // convergent operations in divergent loops is improved. The
    // presence of __ockl_wfall_i32(), prevents the compiler from
    // hoisting calls to convergent functions like __ockl_lane_u32().
    int thread_done = 0;
    do {
        if (thread_done == 0) {
            uint plen = len;
            if (len > 56) {
                plen = 56;
            } else {
                desc |= end_flag;
            }
            retval = message_uchar(service_id, desc, data, plen);
            desc = (ulong)retval.x;
            len -= plen;
            data += plen;

            if (len == 0) thread_done = 1;
        }
    } while (__ockl_wfall_i32(thread_done) == 0);

    return retval;
}

long2
__ockl_hostcall_message_uint(uint service_id, ulong msg_desc,
                             uint num_args,
                             uint arg0, uint arg1, uint arg2, uint arg3,
                             uint arg4, uint arg5, uint arg6, uint arg7,
                             uint arg8, uint arg9, uint arg10, uint arg11,
                             uint arg12, uint arg13)
{
    uchar num_bytes = num_args * sizeof(uint);
    msg_desc = msg_set_bytes(msg_desc, num_bytes);

    long2 result
        = __ockl_hostcall_preview(service_id, msg_desc,
                                  ((ulong)arg1 << 32) | arg0,
                                  ((ulong)arg3 << 32) | arg2,
                                  ((ulong)arg5 << 32) | arg4,
                                  ((ulong)arg7 << 32) | arg6,
                                  ((ulong)arg9 << 32) | arg8,
                                  ((ulong)arg11 << 32) | arg10,
                                  ((ulong)arg13 << 32) | arg12);

    return result.x;
}
