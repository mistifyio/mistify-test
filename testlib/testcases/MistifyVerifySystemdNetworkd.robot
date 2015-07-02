*** Settings ***
Documentation	This script performs basic verification that systemd can be used
...		to reconfigure the network.
...
...	This uses a single node to verify networkd.
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

*** Test Cases ***
Verify Test Network Unreachable
    [Setup]	Use Node  @{MISTIFY_CLUSTER_NODES}[0]  ${ts_setup}
    ${_o}=  SSH Run And Get Output  ping -c 1 ${MISTIFY_CLUSTER_GATEWAY_IP}
    Should Contain  ${_o}  Network is unreachable

Install Test Configuration
    [Documentation]	Reconfigure and restart the network and verify the
    ...			configuration takes effect.
    ...
    ...	NOTE: This relies upon test version config files in /root.

    ${_c}=  catenate
    ...	cp ~/${MISTIFY_CLUSTER_NODE_BRIDGE}.network.test
    ...	/etc/systemd/network/${MISTIFY_CLUSTER_NODE_BRIDGE}.network
    SSH Run  ${_c}
    ${_c}=  catenate
    ...	cp ~/ethernet.network.test
    ...	/etc/systemd/network/ethernet.network
    SSH Run  ${_c}
    ${_c}=  catenate
    ...	cp resolv.conf.test
    ...	/etc/resolv.conf
    SSH Run  ${_c}

Verify Device File Copied
    Files Should Be Same
    ...	~/${MISTIFY_CLUSTER_NODE_BRIDGE}.network.test
    ...	/etc/systemd/network/${MISTIFY_CLUSTER_NODE_BRIDGE}.network

Verify Ethernet File Copied
    Files Should Be Same
    ...	~/ethernet.network.test
    ...	/etc/systemd/network/ethernet.network

Verify Resolv File Copied
    Files Should Be Same
    ...	~/resolv.conf.test
    ...	/etc/resolv.conf

Reconfigure Network And Verify Test Network Reachable
    SSH Run  systemctl restart systemd-networkd
    Sleep  10
    ${_o}=  SSH Run And Get Output  ping -c 1 ${MISTIFY_CLUSTER_GATEWAY_IP}
    Should Contain  ${_o}  1 packets transmitted
    Should Contain  ${_o}  1 received

*** Keywords ***
