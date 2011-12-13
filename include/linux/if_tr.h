/*
 * INET		An implementation of the TCP/IP protocol suite for the LINUX
 *		operating system.  INET is implemented using the  BSD Socket
 *		interface as the means of communication with the user level.
 *
 *		Global definitions for the Token-Ring IEEE 802.5 interface.
 *
 * Version:	@(#)if_tr.h	0.0	07/11/94
 *
 * Author:	Fred N. van Kempen, <waltje@uWalt.NL.Mugnet.ORG>
 *		Donald Becker, <becker@super.org>
 *		Peter De Schrijver, <stud11@cc4.kuleuven.ac.be>
 *
 *		This program is free software; you can redistribute it and/or
 *		modify it under the terms of the GNU General Public License
 *		as published by the Free Software Foundation; either version
 *		2 of the License, or (at your option) any later version.
 */
#ifndef _LINUX_IF_TR_H
#define _LINUX_IF_TR_H

#include <linux/skbuff.h>
#include <uapi/linux/if_tr.h>

static inline struct trh_hdr *tr_hdr(const struct sk_buff *skb)
{
	return (struct trh_hdr *)skb_mac_header(skb);
}
#endif	/* _LINUX_IF_TR_H */
