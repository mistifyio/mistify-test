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
Verify Test Network Reachable
    Use Node  @{MISTIFY_CLUSTER_NODES}[0]
    ${_o}=  ${MISTIFY_CLUSTER_GATEWAY_IP} Is Responding To Ping
    Should Not Contain  ${_o}  Network is unreachable

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
    Restart Service systemd-networkd
    ${_t}=  Mark Time
    Log Message  Network started at: ${_t}
    Wait Until Host Responds To Ping  ${MISTIFY_CLUSTER_GATEWAY_IP}
    ${_t}=  Mark Time
    Log Message  ${MISTIFY_CLUSTER_GATEWAY_IP} responded at: ${_t}

*** Keywords ***
