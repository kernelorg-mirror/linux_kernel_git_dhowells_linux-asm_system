#ifndef __ASM_SH_PTRACE_32_H
#define __ASM_SH_PTRACE_32_H

#include <uapi/asm/ptrace_32.h>


#define MAX_REG_OFFSET		offsetof(struct pt_regs, tra)
#define regs_return_value(_regs)	((_regs)->regs[0])

#endif /* __ASM_SH_PTRACE_32_H */
