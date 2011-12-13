#ifndef _ASM_X86_DEBUGREG_H
#define _ASM_X86_DEBUGREG_H

#include <uapi/asm/debugreg.h>


DECLARE_PER_CPU(unsigned long, cpu_dr7);

static inline void hw_breakpoint_disable(void)
{
	/* Zero the control register for HW Breakpoint */
	set_debugreg(0UL, 7);

	/* Zero-out the individual HW breakpoint address registers */
	set_debugreg(0UL, 0);
	set_debugreg(0UL, 1);
	set_debugreg(0UL, 2);
	set_debugreg(0UL, 3);
}

static inline int hw_breakpoint_active(void)
{
	return __this_cpu_read(cpu_dr7) & DR_GLOBAL_ENABLE_MASK;
}

extern void aout_dump_debugregs(struct user *dump);

extern void hw_breakpoint_restore(void);

#endif /* _ASM_X86_DEBUGREG_H */
