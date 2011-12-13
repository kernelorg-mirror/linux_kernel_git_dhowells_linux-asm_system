/* $Id: posix_types.h,v 1.1 2000/07/10 16:32:31 bjornw Exp $ */
#ifndef __ARCH_CRIS_POSIX_TYPES_H
#define __ARCH_CRIS_POSIX_TYPES_H

#include <uapi/asm/posix_types.h>


#undef	__FD_SET
#define __FD_SET(fd,fdsetp) set_bit(fd, (void *)(fdsetp))

#undef	__FD_CLR
#define __FD_CLR(fd,fdsetp) clear_bit(fd, (void *)(fdsetp))

#undef	__FD_ISSET
#define __FD_ISSET(fd,fdsetp) test_bit(fd, (void *)(fdsetp))

#undef	__FD_ZERO
#define __FD_ZERO(fdsetp) memset((void *)(fdsetp), 0, __FDSET_LONGS << 2)

#endif /* __ARCH_CRIS_POSIX_TYPES_H */
