#ifndef _INET_DIAG_H_
#define _INET_DIAG_H_ 1

#include <uapi/linux/inet_diag.h>

struct sock;
struct inet_hashinfo;

struct inet_diag_handler {
	struct inet_hashinfo    *idiag_hashinfo;
	void			(*idiag_get_info)(struct sock *sk,
						  struct inet_diag_msg *r,
						  void *info);
	__u16                   idiag_info_size;
	__u16                   idiag_type;
};

extern int  inet_diag_register(const struct inet_diag_handler *handler);
extern void inet_diag_unregister(const struct inet_diag_handler *handler);
#endif /* _INET_DIAG_H_ */
