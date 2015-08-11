*** Settings ***
Documentation	This script is designed to setup a test run for a newly completed
...		build.
...
...	If the command line parameter "SETUP" equals "reset" then
...	images are downloaded from the build server and	installed into
...	the test container to be booted by the nodes involved in the
...	test run. Otherwise previously installed images are used.
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

Suite Teardown	Stop Tests If Failed

*** Variables ***

*** Test Cases ***
Prepare For New Test Run
    Get Command Line Options
    Use Cluster Container

# The following is to record the container states for diagnostic purposes.
The Cluster Bridge Exists And Has Expected IP Addresses
    ${_o}=  SSH Run And Get Output  ip addr show dev ${MISTIFY_BRIDGE}
    Should Contain  ${_o}  ${MISTIFY_BRIDGE}
    Should Contain  ${_o}  ${MISTIFY_BRIDGE_IP}/${MISTIFY_NET_MASK_BITS}
    Should Contain  ${_o}  ${MISTIFY_CLUSTER_GATEWAY_IP}/${MISTIFY_CLUSTER_NET_MASK_BITS}

Node Interfaces Exist And Are Part Of Bridge
    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
      \  ${_o}=  SSH Run And Get Key Line  LINE:  ip addr show dev ${_n}
      \  Should Contain  ${_o}  ${MISTIFY_BRIDGE}

The DHCP Server Is Running
    ${_o}=  SSH Run And Get Key Line  DHCP:  ps aux \| grep dhcpd
    Should Contain  ${_o}  testmistify/vm-network-dhcpd-pid

The HTTP Server Is Running To Serve Guest Images
    ${_o}=  SSH Run And Get Output  HTTP:  ps aux \| grep Simple
    Should Contain  ${_o}  SimpleHTTPServer

The Screen Sessions Exist And Are Detached
    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
      \  ${_o}=  SSH Run And Get Key Line  LINE:  screen -ls ${_n} \| grep ${_n}
      \  Should Contain  ${_o}  Detached

Install New Images
    Run Keyword If  '${ts_setup}'=='reset'  Update Mistify Images

Restart Nodes Using New Images
    # Test cases assume already logged into the nodes.
    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
      \  Use Node  ${_n}  reset
      \  Release Node

*** Keywords ***
Stop Tests If Failed
    Release Cluster Container
    Run Keyword If Any Tests Failed  Fatal Error
    ...  Container is not configured properly. Stopping test execution.
