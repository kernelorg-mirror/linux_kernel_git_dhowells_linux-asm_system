#ifndef _UAPI_LINUX_STRING_H_
#define _UAPI_LINUX_STRING_H_

/* We don't want strings.h stuff being used by user stuff by accident */

#ifndef __KERNEL__
#include <string.h>
#endif
#endif /* _UAPI_LINUX_STRING_H_ */
