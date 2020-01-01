# BurstRadar
This repository contains implementation of BurstRadar system on P4 V1 Model Architecture. BurstRadar system has been devised by Raj Joshi, Ting Qu et al. in their paper [**BurstRadar: Practical Real-time Microburst Monitoring for Datacenter Networks**](https://drive.google.com/open?id=1gCPpqhtfsiABZm1_1sMKfB4tm6t1Vhxs) presented in the Proceedings of the ACM 9th Asia-Pacific Workshop on Systems (APSys’18). 

## Steps to test BurstRadar System
### A. Environment Setup
1. Install VirtualBox [Oracle VirtualBox](https://www.virtualbox.org/).
2. Download the VM Image [(P4 Tutorial 2019-08-15)](http://stanford.edu/~sibanez/docs/).
3. Import _P4 Tutorial 2019-08-15.ova_ appliance in VirtualBox.
4. Start the VM in VirtualBox and execute the following: 
   - Change to /home/vagrant directory\
     cd /home/vagrant
   - Clone the p4lang/tutorials repository\
     git clone https://github.com/p4lang/tutorials.git 
   - Uninstall python-scapy and its dependent packages\
     sudo apt-get remove --auto-remove python-scapy
   - Download and install Scapy 2.4.3\
     git clone https://github.com/secdev/scapy.git \
     cd scapy\
     sudo python setup.py install
   - Set environment PATH to scapy directory\
     gedit ~/.bashrc\
     copy the following line to .bashrc file \
     export PATH="/home/vagrant/scapy:$PATH" 
     <br/>source ~/.bashrc
   - Change to exercises directory\
     cd tutorials/exercises/
   - Clone the burstradar repository\
     git clone https://github.com/harshgondaliya/burstradar.git

### B. Runing BurstRadar
1. In the /home/vargrant/tutorials/exercises/burstradar/ directory, execute:
   - make run
   BMv2 Mininet CLI starts
2. Open a new terminal and exexute:
   - simple_switch_CLI
   Connection to BMv2 simple_switch through thrift-port is started\
   - Set default values of bytesRemaining and index registers\
     register_write bytesRemaining 0 0
     register_write index 0 0
   - Set mirror port for a given session id (In our case, session id = 11)
     mirroring_add 11 3
3. In Bmv2 Mininet CLI, execute:
   - xterm h1 h2 h3 h4 h2 h3
   

