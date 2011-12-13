#ifndef _ASM_X86_UNISTD_64_H
#define _ASM_X86_UNISTD_64_H

#include <uapi/asm/unistd_64.h>


#ifndef COMPILE_OFFSETS
#include <asm/asm-offsets.h>
#define NR_syscalls (__NR_syscall_max + 1)
#endif

/*
 * "Conditional" syscalls
 *
 * What we want is __attribute__((weak,alias("sys_ni_syscall"))),
 * but it doesn't work on all toolchains, so we just do it by hand
 */
#define cond_syscall(x) asm(".weak\t" #x "\n\t.set\t" #x ",sys_ni_syscall")
#endif /* _ASM_X86_UNISTD_64_H */
