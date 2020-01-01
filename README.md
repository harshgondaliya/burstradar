# BurstRadar
This repository contains implementation of BurstRadar system using P4 V1 Model Architecture. BurstRadar system is presented in the paper: [**BurstRadar: Practical Real-time Microburst Monitoring for Datacenter Networks**](https://drive.google.com/open?id=1gCPpqhtfsiABZm1_1sMKfB4tm6t1Vhxs) by Raj Joshi et. al.,  published in the Proceedings of the ACM 9th Asia-Pacific Workshop on Systems (APSys’18). 

## Steps to test BurstRadar System
### A. Environment Setup
1. Install VirtualBox [Oracle VirtualBox](https://www.virtualbox.org/).
2. Download the VM Image [(P4 Tutorial 2019-08-15)](http://stanford.edu/~sibanez/docs/).
3. Import _P4 Tutorial 2019-08-15.ova_ appliance in VirtualBox.
4. Start the VM in VirtualBox and execute the following: 
   * Change to ```/home/vagrant``` directory
     ```
     cd /home/vagrant
     ```
   * Clone the ```p4lang/tutorials``` repository
     ```
     git clone https://github.com/p4lang/tutorials.git
     ```
   * Uninstall ```python-scapy``` and its dependent packages
     ```
     sudo apt-get remove --auto-remove python-scapy
     ```
   * Download and install Scapy 2.4.3
     ```
     git clone https://github.com/secdev/scapy.git 
     cd scapy
     sudo python setup.py install
     ```
   * Set environment ```PATH``` to scapy directory
     ```
     gedit ~/.bashrc
     copy the following line to .bashrc file 
     export PATH="/home/vagrant/scapy:$PATH" 
     source ~/.bashrc
     ```
   * Change to the exercises directory
     ```
     cd tutorials/exercises
     ```
   * Clone the burstradar repository
     ```
     git clone https://github.com/harshgondaliya/burstradar.git
     ```

### B. Running BurstRadar
1. In the ```/home/vargrant/tutorials/exercises/burstradar/``` directory, execute:
   ```
   make run
   ```
   BMv2 Mininet CLI starts.
2. Open a new terminal and do the following:
   * Start simple_switch CLI
     ```
     simple_switch_CLI
     ```
     Connection to BMv2 simple_switch through thrift-port is started.
   * Set default values of ```bytesRemaining``` and ```index``` registers
     ```
     register_write bytesRemaining 0 0
     register_write index 0 0
     ```
   * Set mirror port for a given session id (In our case, session id = 11)
     ```
     mirroring_add 11 4
     ```
3. In Bmv2 Mininet CLI, execute:
   - xterm h1 h2 h3 h4 h2 h3
   

