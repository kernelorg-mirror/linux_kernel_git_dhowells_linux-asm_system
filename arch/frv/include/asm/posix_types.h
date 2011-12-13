#ifndef _ASM_POSIX_TYPES_H
#define _ASM_POSIX_TYPES_H

#include <uapi/asm/posix_types.h>


#undef	__FD_SET
#define	__FD_SET(d, set)	((set)->fds_bits[__FDELT(d)] |= __FDMASK(d))

#undef	__FD_CLR
#define	__FD_CLR(d, set)	((set)->fds_bits[__FDELT(d)] &= ~__FDMASK(d))

#undef	__FD_ISSET
#define	__FD_ISSET(d, set)	(!!((set)->fds_bits[__FDELT(d)] & __FDMASK(d)))

#undef	__FD_ZERO
#define __FD_ZERO(fdsetp) (memset (fdsetp, 0, sizeof(*(fd_set *)fdsetp)))

#endif
