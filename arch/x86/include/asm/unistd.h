#ifdef __KERNEL__
# ifdef CONFIG_X86_32
#  include <asm/unistd_32.h>
# else
#  include <asm/unistd_64.h>
# endif
#else
# ifdef __i386__
#  include <asm/unistd_32.h>
# else
#  include <asm/unistd_64.h>
# endif
#endif
