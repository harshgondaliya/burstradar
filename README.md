# BurstRadar
This repository contains implementation of BurstRadar system using P4 _V1Model Architecture_ on _simple_switch target_. BurstRadar system is presented in the paper: [**BurstRadar: Practical Real-time Microburst Monitoring for Datacenter Networks**](https://drive.google.com/open?id=1gCPpqhtfsiABZm1_1sMKfB4tm6t1Vhxs) by Raj Joshi et. al.,  published in the Proceedings of the ACM 9th Asia-Pacific Workshop on Systems (APSys’18). 

BurstRadar detects a microburst in the dataplane, captures a snapshot of telemetry information of all the involved packets, and further exports this telemetry information to a monitoring server in an out-of-band manner. A detailed explanation and background of BurstRadar system is provided in the aforementioned paper.
<p align="center">
  <img src="https://github.com/harshgondaliya/burstradar/blob/master/burstradar-diagram.PNG">
</p>

## Steps to test BurstRadar system
### A. Environment Setup
1. Install [Oracle VirtualBox](https://www.virtualbox.org/).
2. Download the VM Image [(P4 Tutorial 2019-08-15)](https://drive.google.com/open?id=1mfk-BiLQP3YHcOznaHoeio1fWHSNBnKw).
3. Import _P4 Tutorial 2019-08-15.ova_ appliance in VirtualBox.
4. Start the VM in VirtualBox and execute the following: 
   * Change to ```/home/vagrant``` directory.
     ```
     vagrant@p4:~$ cd /home/vagrant
     ```
   * Clone the ```p4lang/tutorials``` repository.
     ```
     vagrant@p4:~$ git clone https://github.com/p4lang/tutorials.git
     ```
   * Uninstall ```python-scapy``` and its dependent packages.
     ```
     vagrant@p4:~$ sudo apt-get remove --auto-remove python-scapy
     ```
   * Download and install Scapy 2.4.3.
     ```
     vagrant@p4:~$ git clone https://github.com/secdev/scapy.git 
     vagrant@p4:~$ cd scapy
     vagrant@p4:~/scapy$ sudo python setup.py install
     ```
   * Set environment ```PATH``` to scapy directory.
     ```
     vagrant@p4:~/scapy$ gedit ~/.bashrc
     ```
     * Add the following line to ```.bashrc``` file, save and exit. 
       ```
       export PATH="/home/vagrant/scapy:$PATH" 
       ```
     * Source ```.bashrc``` file.
       ```
       vagrant@p4:~/scapy$ source ~/.bashrc
       ```
   * Install ```tcpreplay``` package which is needed for executing ```sendpfast()``` scapy function.
     ```
     vagrant@p4:~$ sudo apt-get install tcpreplay
     ```
     
   * Change to the exercises directory.
     ```
     vagrant@p4:~/scapy$ cd ../tutorials/exercises/
     ```
   * Clone the burstradar repository and move to that directory.
     ```
     vagrant@p4:~/tutorials/exercises$ git clone https://github.com/harshgondaliya/burstradar.git
     vagrant@p4:~/tutorials/exercises$ cd burstradar
     vagrant@p4:~/tutorials/exercises/burstradar$
     
     ```

### B. Running BurstRadar
1. In the ```/home/vargrant/tutorials/exercises/burstradar/``` directory, execute:
   ```
   vagrant@p4:~/tutorials/exercises/burstradar$ sudo make run
   ```
   BMv2 Mininet CLI starts.
2. Open a new terminal and execute the following:
   * Start CLI
     ```
     vagrant@p4:~$ simple_switch_CLI
     ```
     Connection to the BMv2 simple_switch through thrift-port is started.
   * Set default values of ```bytesRemaining``` and ```index``` registers
     ```
     vagrant@p4:~$ simple_switch_CLI
     Obtaining JSON from switch...
     Done
     Control utility for runtime P4 table manipulation
     RuntimeCmd: register_write bytesRemaining 0 0
     RuntimeCmd: register_write index 0 0
     ```
   * Set mirror port for a given session id (In our case, session id = 11)
     ```
     RuntimeCmd: mirroring_add 11 4
     ```
3. In BMv2 Mininet CLI, execute:
   ```
   mininet> xterm h1 h2 h3 h4 h3
   ```
   Note: Two xterm displays for ```h3``` are started.
   * In ```h4```'s xterm display, execute:
     ```
     ./receive.py
     ```
   * In the first xterm display of ```h3```, execute:
     ```
     ./receive.py
     ```
   * In the second xterm display of ```h3```, execute:
     ```
     iperf -s -w 2m
     ```
   * In ```h2```'s xterm display, execute:
     ```
     iperf -c 10.0.3.3 -w 2m -t 35
     ```
     This ensures that approx. 4-4.5 Mbps background traffic is running between host 2 and host 3.
   * In ```h1```'s xterm display, execute:
     ```
     ./send.py 10.0.3.3 6700 300
     ```
     This ensures that approx. 10 Mbps burst traffic is sent from host 1 to host host 3.
   * A few packets that causes microburst will be marked and received at the monitoring server (```h4```). 
   * Similarly, burst traffic can be sent concurrently to multiple egress ports and the BurstRadar system will give desired results.

## Result Screenshots
![results](https://github.com/harshgondaliya/burstradar/blob/master/results-screenshot.PNG)

