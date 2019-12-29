#!/usr/bin/env python
import sys
import struct
import os
from scapy.all import sniff, sendp, hexdump, get_if_list, get_if_hwaddr
from scapy.all import Packet, IPOption
from scapy.fields import ShortField, IntField, LongField, BitField, FieldListField, FieldLenField, SourceIPField, Emph, ShortEnumField, ByteEnumField
from scapy.all import IP, TCP, UDP, Raw
from scapy.layers.inet import _IPOption_HDR, DestIPField
from scapy.data import IP_PROTOS, TCP_SERVICES
def get_if():
    ifs=get_if_list()
    iface=None
    for i in get_if_list():
        if "eth0" in i:
            iface=i
            break;
    if not iface:
        print "Cannot find eth0 interface"
        exit(1)
    return iface

class IPOption_TELEMETRY(IPOption):
    name = "TELEMETRY"
    option = 31
    fields_desc = [ _IPOption_HDR,			
                    	Emph(SourceIPField("src", "dst")),
                   	Emph(DestIPField("dst", "127.0.0.1")),
			ShortEnumField("sport", 20, TCP_SERVICES),
			ShortEnumField("dport", 80, TCP_SERVICES),
			ByteEnumField("proto", 0, IP_PROTOS),
			BitField("ingress_timestamp", 0, 48),
			BitField("egress_timestamp", 0, 48),
			BitField("enqQdepth", 0, 19),
			BitField("deqQdepth", 0, 19),
			BitField("padding", 0, 2) ]
def handle_pkt(pkt):
    if TCP in pkt and pkt[TCP].dport == 1234:
        print "got a packet"
        pkt.show2()
    #    hexdump(pkt)
        sys.stdout.flush()


def main():
    ifaces = filter(lambda i: 'eth' in i, os.listdir('/sys/class/net/'))
    iface = ifaces[0]
    print "sniffing on %s" % iface
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x))

if __name__ == '__main__':
    main()
