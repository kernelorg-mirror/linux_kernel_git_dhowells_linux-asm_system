#ifndef __LINUX_IP6_NETFILTER_H
#define __LINUX_IP6_NETFILTER_H

#include <uapi/linux/netfilter_ipv6.h>


#ifdef CONFIG_NETFILTER
extern int ip6_route_me_harder(struct sk_buff *skb);
extern __sum16 nf_ip6_checksum(struct sk_buff *skb, unsigned int hook,
				    unsigned int dataoff, u_int8_t protocol);

extern int ipv6_netfilter_init(void);
extern void ipv6_netfilter_fini(void);
#else /* CONFIG_NETFILTER */
static inline int ipv6_netfilter_init(void) { return 0; }
static inline void ipv6_netfilter_fini(void) { return; }
#endif /* CONFIG_NETFILTER */

#endif /*__LINUX_IP6_NETFILTER_H*/
