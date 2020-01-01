/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;
const bit<32> TYPE_EGRESS_CLONE = 2;
#define IS_E2E_CLONE(std_meta) (std_meta.instance_type == TYPE_EGRESS_CLONE)
const bit<32> E2E_CLONE_SESSION_ID = 11;
const bit<32> MAX_ENTRIES = 26;
#define THRESHOLD 1500
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
    bit<19> deqQdepth; 
    bit<2> padding; // 238 bits of telemetry data + 2 bits of padding + 16 bits of IPOption header = 256 bits (multiple of 32)
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
    bit<1> flag; // metadata for each packet
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
	
	/* 
		State needs to be maintained for bytesRemaining, index, ring_buffer for data packets. Thus, they are implemented using
		registers.
	*/
	register<bit<19>>(1) bytesRemaining; // bytes count stored in a register
	bit<19> bytes; // temporary bytes count in bit<> format
	int<19> bytes_int; // temporary bytes count in int<> format
	int<19> deqQdepth;
	register<bit<32>>(1) index; // index stored in a register
	bit<32> id; // temporary index in bit<> format
	register<bit<SIZE_OF_ENTRY>>(MAX_ENTRIES) ring_buffer; 
	bit<SIZE_OF_ENTRY> data; // to move data to register 
	bit<SIZE_OF_ENTRY> data_clone; // to extract data from register and transfer it to cloned packet
	
	action do_clone_e2e(){
		clone3(CloneType.E2E,E2E_CLONE_SESSION_ID,meta);
	}	
	action mark_packet(){
		meta.flag = 1;
		data = hdr.ipv4.srcAddr ++ hdr.ipv4.dstAddr ++ hdr.tcp.srcPort ++ hdr.tcp.dstPort ++
			  hdr.ipv4.protocol ++ standard_metadata.ingress_global_timestamp ++
				standard_metadata.egress_global_timestamp ++ standard_metadata.enq_qdepth ++  
                                   standard_metadata.deq_qdepth; // concatenate all required fields into one bitstring	
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
	apply {  // index and bytesRemaining register values are initialized to 0 from the control plane (simple_switch_CLI)
		index.read(id, 0);
		bytesRemaining.read(bytes, 0);	
		bytes_int = (int<19>)bytes;
		if(!IS_E2E_CLONE(standard_metadata)){
			deqQdepth = (int<19>)(standard_metadata.deq_qdepth * 19w1500);	
			if(deqQdepth > THRESHOLD){
				bytes_int = (deqQdepth - (int<19>)(bit<19>)standard_metadata.packet_length);
				mark_packet();
			}		
			else{
				if(bytes_int > 0){
				    bytes_int = bytes_int - (int<19>)(bit<19>)standard_metadata.packet_length;
				    mark_packet();
				}
			}
			if(bytes_int < 0){
				bytes_int = 0;
			}
			bytes = (bit<19>)bytes_int;
			bytesRemaining.write(0, bytes);				
			if(meta.flag == 1){
				generate_clone.apply();			
			}	
		}
		else{
			    ring_buffer.read(data_clone, (bit<32>)meta.index);
			    hdr.ipv4.ihl = hdr.ipv4.ihl + 8; // 32 bit word * 8 = 256 bits
			    hdr.ipv4.totalLen = hdr.ipv4.totalLen + 32;	
			    hdr.ipv4_option.setValid();	// add IPOption header
			    hdr.ipv4_option.optionLength = 32; // telemetry(240) + IPOption(16) = 256 bytes ==> 256/8 = 32 octets 
			    hdr.ipv4_option.option = TYPE_TELEMETRY;
			    hdr.telemetry.setValid(); // add telemetry header
			    hdr.telemetry.ipv4_srcAddr[31:0] = data_clone[237:206];// extract in the same sequence in which it was concatenated
			    hdr.telemetry.ipv4_dstAddr[31:0] = data_clone[205:174];
			    hdr.telemetry.tcp_sport[15:0] = data_clone[173:158];
			    hdr.telemetry.tcp_dport[15:0] = data_clone[157:142];
			    hdr.telemetry.protocol[7:0] = data_clone[141: 134];
			    hdr.telemetry.ingress_timestamp[47:0] = data_clone[133:86];
			    hdr.telemetry.egress_timestamp[47:0] = data_clone[85:38]; 
			    hdr.telemetry.enqQdepth[18:0] = (data_clone[37:19] * 19w1500);
			    hdr.telemetry.deqQdepth[18:0] = (data_clone[18:0] * 19w1500);
			    hdr.telemetry.padding = (bit<2>)0; 					
			    truncate(86); // Ether(14) + IP (20) + IP Option (32) + TCP (20) = 86 bytes
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

	update_checksum(
	    hdr.ipv4_option.isValid(),
            { hdr.ipv4_option.copyFlag,
	      hdr.ipv4_option.optClass,       // update checksum for IP Option header
              hdr.ipv4_option.option,
              hdr.ipv4_option.optionLength},
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);

	update_checksum(
	    hdr.telemetry.isValid(),
            { hdr.telemetry.ipv4_srcAddr,
	      hdr.telemetry.ipv4_dstAddr,
              hdr.telemetry.tcp_sport,
              hdr.telemetry.tcp_dport,
              hdr.telemetry.protocol,           // update checksum for telemetry header
              hdr.telemetry.ingress_timestamp,
              hdr.telemetry.egress_timestamp,
              hdr.telemetry.enqQdepth,
              hdr.telemetry.deqQdepth,
              hdr.telemetry.padding},
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
