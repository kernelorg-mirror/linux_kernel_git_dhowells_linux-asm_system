#ifndef _ASM_POWERPC_TERMIOS_H
#define _ASM_POWERPC_TERMIOS_H

#include <uapi/asm/termios.h>

/*                   ^C  ^\ del  ^U  ^D   1   0   0   0   0  ^W  ^R  ^Z  ^Q  ^S  ^V  ^U  */
#define INIT_C_CC "\003\034\177\025\004\001\000\000\000\000\027\022\032\021\023\026\025" 

#include <asm-generic/termios-base.h>

#endif	/* _ASM_POWERPC_TERMIOS_H */
