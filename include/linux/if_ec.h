/* Definitions for Econet sockets. */
#ifndef __LINUX_IF_EC
#define __LINUX_IF_EC

#include <uapi/linux/if_ec.h>


#define EC_HLEN				6

/* This is what an Econet frame looks like on the wire. */
struct ec_framehdr {
  unsigned char dst_stn;
  unsigned char dst_net;
  unsigned char src_stn;
  unsigned char src_net;
  unsigned char cb;
  unsigned char port;
};

struct econet_sock {
  /* struct sock has to be the first member of econet_sock */
  struct sock	sk;
  unsigned char cb;
  unsigned char port;
  unsigned char station;
  unsigned char net;
  unsigned short num;
};

static inline struct econet_sock *ec_sk(const struct sock *sk)
{
	return (struct econet_sock *)sk;
}

struct ec_device {
  unsigned char station, net;		/* Econet protocol address */
};

#endif
