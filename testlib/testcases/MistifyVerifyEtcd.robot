*** Settings ***
Documentation	This script performs basic verification that etcd can be used
...		to save and retrieve settings.
...
...	This uses a single node to verify etcd.
...
...	This assumes a system configuration as setup by
...	ClusterInitialization.robot. All node VMs are running and all screen
...	sessions are detached.
...
...	The network is left in a state useable for the cluster tests.
...
...	Command line options (passed by testmistify using '-- -v <OPTION>:<value>')
...	SETUP
...	  reset		Reset a node to initial states during testsuite setup

Library		String
Library		Collections

#+
# NOTE: The variable TESTLIBDIR is passed from the command line by the testmistify
# script. There is no default value for this variable.
#-
Resource	${TESTLIBDIR}/resources/mistify.robot
Resource	${TESTLIBDIR}/resources/ssh.robot
Resource	${TESTLIBDIR}/resources/lxc.robot

Resource	${TESTLIBDIR}/resources/cluster-helpers.robot

Suite Setup	Use Cluster Container
Suite Teardown	Release Cluster Container

*** Variables ***
${etc_data_dir}		/mistify/data/etcd
${test_data}		This is test data
${test_data_path}	testmistify/TEST_DATA

*** Test Cases ***
Test is running
    Log Message  OK

Verify Etcd Is Running
    Use Node  @{MISTIFY_CLUSTER_NODES}[0]  ${ts_setup}
    ${_o}=  SSH Run And Get Output  ps aux \| grep etcd
    Should Contain  ${_o}  /usr/sbin/etcd
    Should Contain  ${_o}  ${etc_data_dir}

Verify Etcd Is Listening On Localhost
    Is Etcd Listening On Port 127.0.0.1 4001
    Is Etcd Listening On Port 127.0.0.1 7001
    Is Etcd Listening On Port 127.0.0.1 2379
    Is Etcd Listening On Port 127.0.0.1 2380

Verify Etcd Can Be Reconfigured
    Set Suite Variable  ${if}  ${MISTIFY_CLUSTER_NODE_BRIDGE}
    Log Message  Interface is: ${if}
    Set Suite Variable  ${ip}  ${MISTIFY_CLUSTER_PRIMARY_IP}
    Log Message  IP address is: ${ip}
    ${_of}=  catenate
    ...  cat >/etc/sysconfig/etcd << EOF\n
    ...  ETCD_DATA_DIR=${etc_data_dir}\n
    ...  ETCD_LISTEN_CLIENT_URLS=http://${ip}:2379,http://${ip}:4001,http://localhost:2379,http://localhost:4001
    ...  \nEOF
    SSH Run  ${_of}
    SSH Run  systemctl restart etcd

Verify Etcd Is Healthy
    Wait Until Keyword Succeeds  15 s  1 s  Is Etcd Healthy

Verify Etcd Is Listening On Configured Ports
    Is Etcd Listening On Port 127.0.0.1 4001
    Is Etcd Listening On Port 127.0.0.1 7001
    Is Etcd Listening On Port 127.0.0.1 2379
    Is Etcd Listening On Port 127.0.0.1 2380
    Is Etcd Listening On Port ${ip} 4001
    Is Etcd Listening On Port ${ip} 2379

Verify Data Can Be Set
    ${_o}=  SSH Run And Get Output  etcdctl set /${test_data_path} '${test_data}'
    Should Contain  ${_o}  ${test_data}

Verify Data Can Be Retrieved
    ${_o}=  SSH Run And Get Output  etcdctl get /${test_data_path}
    Should Contain  ${_o}  ${test_data}

Verify Data Can Be Retrieved Using Curl
    ${_c}=  catenate
    ...  curl http://localhost:4001/v2/keys/${test_data_path} 2>/dev/null \|
    ...  cut -d ':' -f 5 \| cut -d '"' -f 2
    ${_o}=  SSH Run And Get Output  ${_c}
    Should Contain  ${_o}  ${test_data}

*** Keywords ***
Is Etcd Listening On Port ${_ip} ${_port}
    Log Message  Verifying etcd is listening at: ${_ip}:${_port}
    ${_o}=  SSH Run And Get Output  netstat -lpn \| grep etcd \| grep ${_port}
    Should Contain  ${_o}  ${_ip}:${_port}
    Should Contain  ${_o}  LISTEN
    Should Contain  ${_o}  /etcd

Is Etcd Healthy
    ${_o}=  SSH Run And Get Output  etcdctl cluster-health
    Log Message  Cluster health: \n${_o}
    Should Contain  ${_o}  is healthy
