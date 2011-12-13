#ifndef __KERNEL__
# ifdef __i386__
#  include <asm/unistd_32.h>
# else
#  include <asm/unistd_64.h>
# endif
#endif
