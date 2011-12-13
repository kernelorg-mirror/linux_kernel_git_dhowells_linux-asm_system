/*
 *  include/asm-s390/posix_types.h
 *
 *  S390 version
 *
 *  Derived from "include/asm-i386/posix_types.h"
 */
#ifndef __ARCH_S390_POSIX_TYPES_H
#define __ARCH_S390_POSIX_TYPES_H

#include <uapi/asm/posix_types.h>


#undef __FD_SET
static inline void __FD_SET(unsigned long fd, __kernel_fd_set *fdsetp)
{
	unsigned long _tmp = fd / __NFDBITS;
	unsigned long _rem = fd % __NFDBITS;
	fdsetp->fds_bits[_tmp] |= (1UL<<_rem);
}

#undef __FD_CLR
static inline void __FD_CLR(unsigned long fd, __kernel_fd_set *fdsetp)
{
	unsigned long _tmp = fd / __NFDBITS;
	unsigned long _rem = fd % __NFDBITS;
	fdsetp->fds_bits[_tmp] &= ~(1UL<<_rem);
}

#undef __FD_ISSET
static inline int __FD_ISSET(unsigned long fd, const __kernel_fd_set *fdsetp)
{
	unsigned long _tmp = fd / __NFDBITS;
	unsigned long _rem = fd % __NFDBITS;
	return (fdsetp->fds_bits[_tmp] & (1UL<<_rem)) != 0;
}

#undef  __FD_ZERO
#define __FD_ZERO(fdsetp) \
	((void) memset ((void *) (fdsetp), 0, sizeof (__kernel_fd_set)))

#endif
