#ifndef _UAPI_LINUX_STDDEF_H
#define _UAPI_LINUX_STDDEF_H

#include <linux/compiler.h>

#undef NULL
#if defined(__cplusplus)
#define NULL 0
#else
#define NULL ((void *)0)
#endif


#endif /* _UAPI_LINUX_STDDEF_H */
