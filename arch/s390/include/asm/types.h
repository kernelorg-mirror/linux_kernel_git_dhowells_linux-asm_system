/*
 *  include/asm-s390/types.h
 *
 *  S390 version
 *
 *  Derived from "include/asm-i386/types.h"
 */
#ifndef _S390_TYPES_H
#define _S390_TYPES_H

#include <uapi/asm/types.h>


#ifndef __ASSEMBLY__

#ifndef __s390x__
typedef union {
	unsigned long long pair;
	struct {
		unsigned long even;
		unsigned long odd;
	} subreg;
} register_pair;

#endif /* ! __s390x__   */
#endif /* __ASSEMBLY__  */
#endif /* _S390_TYPES_H */
