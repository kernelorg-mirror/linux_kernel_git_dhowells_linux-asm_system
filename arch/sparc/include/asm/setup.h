/*
 *	Just a place holder. 
 */
#ifndef _SPARC_SETUP_H
#define _SPARC_SETUP_H

#include <uapi/asm/setup.h>


#ifdef CONFIG_SPARC32
/* The CPU that was used for booting
 * Only sun4d + leon may have boot_cpu_id != 0
 */
extern unsigned char boot_cpu_id;
extern unsigned char boot_cpu_id4;
#endif

#endif /* _SPARC_SETUP_H */
