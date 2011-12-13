#ifndef _ALPHA_POSIX_TYPES_H
#define _ALPHA_POSIX_TYPES_H

#include <uapi/asm/posix_types.h>


#ifndef __GNUC__

#define	__FD_SET(d, set)	((set)->fds_bits[__FDELT(d)] |= __FDMASK(d))
#define	__FD_CLR(d, set)	((set)->fds_bits[__FDELT(d)] &= ~__FDMASK(d))
#define	__FD_ISSET(d, set)	(((set)->fds_bits[__FDELT(d)] & __FDMASK(d)) != 0)
#define	__FD_ZERO(set)	\
  ((void) memset ((void *) (set), 0, sizeof (__kernel_fd_set)))

#else /* __GNUC__ */

/* With GNU C, use inline functions instead so args are evaluated only once: */

#undef __FD_SET
static __inline__ void __FD_SET(unsigned long fd, __kernel_fd_set *fdsetp)
{
	unsigned long _tmp = fd / __NFDBITS;
	unsigned long _rem = fd % __NFDBITS;
	fdsetp->fds_bits[_tmp] |= (1UL<<_rem);
}

#undef __FD_CLR
static __inline__ void __FD_CLR(unsigned long fd, __kernel_fd_set *fdsetp)
{
	unsigned long _tmp = fd / __NFDBITS;
	unsigned long _rem = fd % __NFDBITS;
	fdsetp->fds_bits[_tmp] &= ~(1UL<<_rem);
}

#undef __FD_ISSET
static __inline__ int __FD_ISSET(unsigned long fd, const __kernel_fd_set *p)
{ 
	unsigned long _tmp = fd / __NFDBITS;
	unsigned long _rem = fd % __NFDBITS;
	return (p->fds_bits[_tmp] & (1UL<<_rem)) != 0;
}

/*
 * This will unroll the loop for the normal constant case (8 ints,
 * for a 256-bit fd_set)
 */
#undef __FD_ZERO
static __inline__ void __FD_ZERO(__kernel_fd_set *p)
{
	unsigned long *tmp = p->fds_bits;
	int i;

	if (__builtin_constant_p(__FDSET_LONGS)) {
		switch (__FDSET_LONGS) {
		      case 16:
			tmp[ 0] = 0; tmp[ 1] = 0; tmp[ 2] = 0; tmp[ 3] = 0;
			tmp[ 4] = 0; tmp[ 5] = 0; tmp[ 6] = 0; tmp[ 7] = 0;
			tmp[ 8] = 0; tmp[ 9] = 0; tmp[10] = 0; tmp[11] = 0;
			tmp[12] = 0; tmp[13] = 0; tmp[14] = 0; tmp[15] = 0;
			return;

		      case 8:
			tmp[ 0] = 0; tmp[ 1] = 0; tmp[ 2] = 0; tmp[ 3] = 0;
			tmp[ 4] = 0; tmp[ 5] = 0; tmp[ 6] = 0; tmp[ 7] = 0;
			return;

		      case 4:
			tmp[ 0] = 0; tmp[ 1] = 0; tmp[ 2] = 0; tmp[ 3] = 0;
			return;
		}
	}
	i = __FDSET_LONGS;
	while (i) {
		i--;
		*tmp = 0;
		tmp++;
	}
}

#endif /* __GNUC__ */

#endif /* _ALPHA_POSIX_TYPES_H */
