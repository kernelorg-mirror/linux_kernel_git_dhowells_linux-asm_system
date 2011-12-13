/*
 *  SCSI Transport Netlink Interface
 *    Used for the posting of outbound SCSI transport events
 *
 *  Copyright (C) 2006   James Smart, Emulex Corporation
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */
#ifndef SCSI_NETLINK_H
#define SCSI_NETLINK_H


#include <scsi/scsi_host.h>
#include <uapi/scsi/scsi_netlink.h>

/* Exported Kernel Interfaces */
int scsi_nl_add_transport(u8 tport,
	 int (*msg_handler)(struct sk_buff *),
	void (*event_handler)(struct notifier_block *, unsigned long, void *));
void scsi_nl_remove_transport(u8 tport);

int scsi_nl_add_driver(u64 vendor_id, struct scsi_host_template *hostt,
	int (*nlmsg_handler)(struct Scsi_Host *shost, void *payload,
				 u32 len, u32 pid),
	void (*nlevt_handler)(struct notifier_block *nb,
				 unsigned long event, void *notify_ptr));
void scsi_nl_remove_driver(u64 vendor_id);

void scsi_nl_send_transport_msg(u32 pid, struct scsi_nl_hdr *hdr);
int scsi_nl_send_vendor_msg(u32 pid, unsigned short host_no, u64 vendor_id,
			 char *data_buf, u32 data_len);

#endif /* SCSI_NETLINK_H */
