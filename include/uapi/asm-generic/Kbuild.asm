#
# Headers that are optional in arch/*/uapi/asm/
#
opt-header += kvm.h
opt-header += kvm_para.h
opt-header += a.out.h

#
# Headers that are mandatory in arch/*/uapi/asm/
#
asm-headers += auxvec.h
asm-headers += bitsperlong.h
asm-headers += byteorder.h
asm-headers += errno.h
asm-headers += fcntl.h
asm-headers += ioctl.h
asm-headers += ioctls.h
asm-headers += ipcbuf.h
asm-headers += mman.h
asm-headers += msgbuf.h
asm-headers += param.h
asm-headers += poll.h
asm-headers += posix_types.h
asm-headers += ptrace.h
asm-headers += resource.h
asm-headers += sembuf.h
asm-headers += setup.h
asm-headers += shmbuf.h
asm-headers += sigcontext.h
asm-headers += siginfo.h
asm-headers += signal.h
asm-headers += socket.h
asm-headers += sockios.h
asm-headers += stat.h
asm-headers += statfs.h
asm-headers += swab.h
asm-headers += termbits.h
asm-headers += termios.h
asm-headers += types.h
asm-headers += unistd.h

header-y := $(foreach hdr,$(asm-headers) $(opt-headers), \
		$(if $(wildcard $(srctree)/arch/$(SRCARCH)/include/uapi/$(hdr)), \
		  $(hdr)))
