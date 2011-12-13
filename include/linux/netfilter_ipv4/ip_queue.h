/*
 * This is a module which is used for queueing IPv4 packets and
 * communicating with userspace via netlink.
 *
 * (C) 2000 James Morris, this code is GPL.
 */
#ifndef _IP_QUEUE_H
#define _IP_QUEUE_H

#include <uapi/linux/netfilter_ipv4/ip_queue.h>

#ifdef DEBUG_IPQ
#define QDEBUG(x...) printk(KERN_DEBUG ## x)
#else
#define QDEBUG(x...)
#endif  /* DEBUG_IPQ */
#endif /*_IP_QUEUE_H*/
