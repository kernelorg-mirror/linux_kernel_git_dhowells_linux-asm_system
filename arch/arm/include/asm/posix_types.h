/*
 *  arch/arm/include/asm/posix_types.h
 *
 *  Copyright (C) 1996-1998 Russell King.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 *  Changelog:
 *   27-06-1996	RMK	Created
 */
#ifndef __ARCH_ARM_POSIX_TYPES_H
#define __ARCH_ARM_POSIX_TYPES_H

#include <uapi/asm/posix_types.h>


#undef	__FD_SET
#define __FD_SET(fd, fdsetp) \
		(((fd_set *)(fdsetp))->fds_bits[(fd) >> 5] |= (1<<((fd) & 31)))

#undef	__FD_CLR
#define __FD_CLR(fd, fdsetp) \
		(((fd_set *)(fdsetp))->fds_bits[(fd) >> 5] &= ~(1<<((fd) & 31)))

#undef	__FD_ISSET
#define __FD_ISSET(fd, fdsetp) \
		((((fd_set *)(fdsetp))->fds_bits[(fd) >> 5] & (1<<((fd) & 31))) != 0)

#undef	__FD_ZERO
#define __FD_ZERO(fdsetp) \
		(memset (fdsetp, 0, sizeof (*(fd_set *)(fdsetp))))

#endif
