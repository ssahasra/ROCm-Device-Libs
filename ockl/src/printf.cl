/*===--------------------------------------------------------------------------
 *                   ROCm Device Libraries
 *
 * This file is distributed under the University of Illinois Open Source
 * License. See LICENSE.TXT for details.
 *===------------------------------------------------------------------------*/

#include <ockl.h>
#include "services.h"

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

/** \brief Transmit a fragment of a printf string.
 *
 *  If this is the last fragment of the string, then it is padded with
 *  zeroes up to the next multiple of four bytes.
 */
static long2
send_string_fragment(ulong msg_desc, const uchar *data, uint len)
{
    uint rounded = (len + 3) & ~(uint)3;
    msg_desc = msg_set_bytes(msg_desc, rounded);

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
        = __ockl_hostcall_preview(SERVICE_ID_PRINTF,
                                msg_desc, arg1, arg2, arg3,
                                arg4, arg5, arg6, arg7);

    return result.x;
}

/** \brief Transmit a string as part of a hostcall message.
 *  \param msg_desc Descriptor for the target hostcall message.
 *  \param data     Pointer to contents of the string.
 *  \param len      Length of the string.
 *  \return The values returned by the last hostcall in the sequence.
 *
 *  A string of arbitrary length is broken up and transmitted to the
 *  host over a series of hostcalls.
 *
 *  NOTE: The string is padded with zeroes up to the next multiple of
 *  four. This allows subsequenet printf arguments to be aligned on a
 *  four byte boundary.
 */
long2
__ockl_printf_send_string(ulong msg_desc, const uchar *data, uint len)
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
            retval = send_string_fragment(desc, data, plen);
            desc = (ulong)retval.x;
            len -= plen;
            data += plen;

            if (len == 0) thread_done = 1;
        }
    } while (__ockl_wfall_i32(thread_done) == 0);

    return retval;
}

/** \brief Transmit a sequence of dwords as part of a hostcall message.
 *  \param msg_desc   Descriptor for the hostcall message.
 *  \param num_dwords Number of dwords being transmitted.
 *  \param arg0..arg13 Up to 14 dwords to be packed into the payload.
 *  \return The values returned by the hostcall.
 */
long2
__ockl_printf_send_dwords(ulong msg_desc,
                             uint num_dwords,
                             uint arg0, uint arg1, uint arg2, uint arg3,
                             uint arg4, uint arg5, uint arg6, uint arg7,
                             uint arg8, uint arg9, uint arg10, uint arg11,
                             uint arg12, uint arg13)
{
    uchar num_bytes = num_dwords * sizeof(uint);
    msg_desc = msg_set_bytes(msg_desc, num_bytes);

    long2 result
        = __ockl_hostcall_preview(SERVICE_ID_PRINTF, msg_desc,
                                  ((ulong)arg1 << 32) | arg0,
                                  ((ulong)arg3 << 32) | arg2,
                                  ((ulong)arg5 << 32) | arg4,
                                  ((ulong)arg7 << 32) | arg6,
                                  ((ulong)arg9 << 32) | arg8,
                                  ((ulong)arg11 << 32) | arg10,
                                  ((ulong)arg13 << 32) | arg12);

    return result.x;
}
