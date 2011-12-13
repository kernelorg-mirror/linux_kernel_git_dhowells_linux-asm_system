#ifndef _ASM_POWERPC_TYPES_H
#define _ASM_POWERPC_TYPES_H

#include <uapi/asm/types.h>

#ifndef __ASSEMBLY__

typedef __vector128 vector128;

typedef struct {
	unsigned long entry;
	unsigned long toc;
	unsigned long env;
} func_descr_t;

#endif /* __ASSEMBLY__ */

#endif /* _ASM_POWERPC_TYPES_H */
