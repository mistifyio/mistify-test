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
${test_data}		some_test_data
${test_data_path}	testmistify/TEST_DATA
${tmp_json_file}	tmp/tmp.json

*** Test Cases ***
Test is running
    Log Message  OK

Verify Etcd Is Running
    Use Node  @{MISTIFY_CLUSTER_NODES}[0]
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
    ${_o}=  Set Etcd Data  /${test_data_path}  '${test_data}'
    Should Contain  ${_o}  ${test_data}

Verify Data Can Be Retrieved
    ${_d}=  Get Etcd Data  /${test_data_path}
    Should Contain  ${_d}  ${test_data}

Verify Data Can Be Retrieved Using Curl
    SSH Run  rm -f ${tmp_json_file}
    Download Etcd Data  ${test_data_path}  ${tmp_json_file}
    ${_v}=  Get Json Field  ${tmp_json_file}  value
    Should Contain  ${_v}  ${test_data}

Verify Data Can Be Retrieved By Another Host
    SSH Run  rm -f ${tmp_json_file}
    Release Node
    Download Etcd Data  ${test_data_path}  ${tmp_json_file}  ${ip}
    ${_v}=  Get Json Field  ${tmp_json_file}  value
    Should Contain  ${_v}  ${test_data}

*** Keywords ***

