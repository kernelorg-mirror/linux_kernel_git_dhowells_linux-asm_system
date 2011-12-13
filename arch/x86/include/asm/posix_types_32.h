#ifndef _ASM_X86_POSIX_TYPES_32_H
#define _ASM_X86_POSIX_TYPES_32_H

#include <uapi/asm/posix_types_32.h>


#undef	__FD_SET
#define __FD_SET(fd,fdsetp)					\
	asm volatile("btsl %1,%0":				\
		     "+m" (*(__kernel_fd_set *)(fdsetp))	\
		     : "r" ((int)(fd)))

#undef	__FD_CLR
#define __FD_CLR(fd,fdsetp)					\
	asm volatile("btrl %1,%0":				\
		     "+m" (*(__kernel_fd_set *)(fdsetp))	\
		     : "r" ((int) (fd)))

#undef	__FD_ISSET
#define __FD_ISSET(fd,fdsetp)					\
	(__extension__						\
	 ({							\
	 unsigned char __result;				\
	 asm volatile("btl %1,%2 ; setb %0"			\
		      : "=q" (__result)				\
		      : "r" ((int)(fd)),			\
			"m" (*(__kernel_fd_set *)(fdsetp)));	\
	 __result;						\
}))

#undef	__FD_ZERO
#define __FD_ZERO(fdsetp)					\
do {								\
	int __d0, __d1;						\
	asm volatile("cld ; rep ; stosl"			\
		     : "=m" (*(__kernel_fd_set *)(fdsetp)),	\
		       "=&c" (__d0), "=&D" (__d1)		\
		     : "a" (0), "1" (__FDSET_LONGS),		\
		       "2" ((__kernel_fd_set *)(fdsetp))	\
		     : "memory");				\
} while (0)

#endif /* _ASM_X86_POSIX_TYPES_32_H */
