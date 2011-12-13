#ifndef __ASM_SH_PTRACE_64_H
#define __ASM_SH_PTRACE_64_H

#include <uapi/asm/ptrace_64.h>


#define MAX_REG_OFFSET		offsetof(struct pt_regs, tregs[7])
#define regs_return_value(_regs)	((_regs)->regs[3])

#endif /* __ASM_SH_PTRACE_64_H */
