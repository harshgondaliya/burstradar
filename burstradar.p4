/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;
const bit<32> TYPE_EGRESS_CLONE = 2;
#define IS_E2E_CLONE(std_meta) (std_meta.instance_type == TYPE_EGRESS_CLONE)
const bit<32> E2E_CLONE_SESSION_ID = 11;
const bit<19> THRESHOLD = 18750;
const bit<32> MAX_ENTRIES = 29;
#define SIZE_OF_ENTRY 238
#define TYPE_TELEMETRY 31
/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header ipv4_option_t {
    bit<1> copyFlag;
    bit<2> optClass;
    bit<5> option;
    bit<8> optionLength;
}

header telemetry_t{
    bit<32> ipv4_srcAddr;
    bit<32> ipv4_dstAddr;
    bit<16> tcp_sport;
    bit<16> tcp_dport;
    bit<8>  protocol;
    bit<48> ingress_timestamp;
    bit<48> egress_timestamp; 
    bit<19> enqQdepth;
    bit<19> deqQdepth; // total 238 bits of telemetry data
    bit<18> padding; 	// to make size a multiple of 32-bit word
} 

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<3>  res;
    bit<3>  ecn;
    bit<6>  ctrl;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}
struct metadata {
    bit<1> flag;
    bit<7> index;
}

struct headers {
    ethernet_t    ethernet;
    ipv4_t        ipv4;
    ipv4_option_t ipv4_option;	
    telemetry_t   telemetry;
    tcp_t 	  tcp; 	
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start { 
	transition parse_ethernet;	
    }
    state parse_ethernet{
	packet.extract(hdr.ethernet);        
	transition select(hdr.ethernet.etherType){ 
		TYPE_IPV4: parse_ipv4;
		default: accept;
	}
    } 
    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            6: parse_tcp;
            default: accept;
        }
    }    
    state parse_tcp {
        packet.extract(hdr.tcp);
        transition accept;
    }	
}


/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {   
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action drop() {
        mark_to_drop(standard_metadata); 
    }
    
    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
    	hdr.ethernet.srcAddr = hdr.ethernet.dstAddr; 
	hdr.ethernet.dstAddr = dstAddr;
	hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
	standard_metadata.egress_spec = port; 	
    }
    
    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }
    
    apply {
	if(hdr.ipv4.isValid()){
	        
		ipv4_lpm.apply();
	}
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
	
	register<bit<19>>(1) bytesRemaining;
	bit<19> bytes;
	register<bit<32>>(1) index;
	bit<32> id;
	register<bit<SIZE_OF_ENTRY>>(MAX_ENTRIES) ring_buffer; 
	bit<SIZE_OF_ENTRY> data;
	
	action do_clone_e2e(){
		clone(CloneType.E2E,E2E_CLONE_SESSION_ID);
	}	
	action mark_packet(){
		meta.flag = 1;
		data = hdr.ipv4.srcAddr ++ hdr.ipv4.dstAddr ++ hdr.tcp.srcPort ++ hdr.tcp.dstPort ++ hdr.ipv4.protocol ++ standard_metadata.enq_qdepth ++ standard_metadata.deq_qdepth ++ standard_metadata.ingress_global_timestamp ++ standard_metadata.egress_global_timestamp;
		ring_buffer.write(id, data);
		meta.index = (bit<7>)id;
		id = id + 1;
		if(id==MAX_ENTRIES){
			id=0;
		}
		index.write(0, id);
	}
	table generate_clone{
		actions = {
			do_clone_e2e;
			NoAction;
		}
		default_action = NoAction();
	}
	apply {
		index.read(id, 0);
		bytesRemaining.read(bytes, 0);			
		if(!IS_E2E_CLONE(standard_metadata)){
			if(standard_metadata.deq_qdepth > THRESHOLD){
				bytes = standard_metadata.deq_qdepth - (bit<19>)standard_metadata.packet_length;
				mark_packet();
			}		
			else{
				bytes = bytes - (bit<19>)standard_metadata.packet_length;
				mark_packet();
			}
			bytesRemaining.write(0, bytes);				
			if(meta.flag == 1){
				generate_clone.apply();			
			}	
		}
		else{
			    ring_buffer.read(data, (bit<32>)meta.index);
			    hdr.ipv4_option.setValid();	
			    hdr.ipv4.ihl = hdr.ipv4.ihl + 8;
			    hdr.ipv4_option.optionLength = hdr.ipv4_option.optionLength + 32; 
			    hdr.ipv4_option.option = TYPE_TELEMETRY;
			    hdr.ipv4.totalLen = hdr.ipv4.totalLen + 32;	
			    hdr.telemetry.setValid();
			    hdr.telemetry.ipv4_srcAddr = data[237:206];
			    hdr.telemetry.ipv4_dstAddr = data[205:174];
			    hdr.telemetry.tcp_sport = data[173:158];
			    hdr.telemetry.tcp_dport = data[157:142];
			    hdr.telemetry.protocol = data[141: 134];
			    hdr.telemetry.ingress_timestamp = data[133:86];
			    hdr.telemetry.egress_timestamp = data[85:38]; 
			    hdr.telemetry.enqQdepth = data[37:19];
			    hdr.telemetry.deqQdepth = data[18:0];	 					
		}
	}
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
	update_checksum(
	    hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	      hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}


/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        /* TODO: add deparser logic */
	packet.emit(hdr.ethernet); 
	packet.emit(hdr.ipv4);
	packet.emit(hdr.ipv4_option);
	packet.emit(hdr.telemetry);
	packet.emit(hdr.tcp);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
