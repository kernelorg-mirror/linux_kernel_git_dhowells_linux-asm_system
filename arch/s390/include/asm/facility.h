/*
 * Copyright IBM Corp. 1999, 2009
 *
 * Author(s): Martin Schwidefsky <schwidefsky@de.ibm.com>
 */

#ifndef __ASM_FACILITY_H
#define __ASM_FACILITY_H

#include <asm/lowcore.h>

#define MAX_FACILITY_BIT (256*8)	/* stfle_fac_list has 256 bytes */

/*
 * The test_facility function uses the bit odering where the MSB is bit 0.
 * That makes it easier to query facility bits with the bit number as
 * documented in the Principles of Operation.
 */
static inline int test_facility(unsigned long nr)
{
	unsigned char *ptr;

	if (nr >= MAX_FACILITY_BIT)
		return 0;
	ptr = (unsigned char *) &S390_lowcore.stfle_fac_list + (nr >> 3);
	return (*ptr & (0x80 >> (nr & 7))) != 0;
}

#endif /* __ASM_FACILITY_H */
