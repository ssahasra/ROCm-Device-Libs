#ifndef SERVICES_H
#define SERVICES_H

typedef enum {
    SERVICE_ID_DEFAULT = 0,
    SERVICE_ID_FUNCTION_CALL = 1,
    SERVICE_ID_PRINTF = 2
} __ockl_hostcall_service_id;

extern long2
__ockl_hostcall_preview(uint service_id,
                        ulong arg0, ulong arg1, ulong arg2, ulong arg3,
                        ulong arg4, ulong arg5, ulong arg6, ulong arg7);

#endif // SERVICES_H
