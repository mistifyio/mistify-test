*** Settings ***
Documentation	This script performs basic verification that a simple three
...  node cluster can be created in a virtual machine environment.
...
...  A container is used as the test bed and three virtual machines are expected
...  to exist in the container which are then used to boot and configure
...  Mistify-OS to serve as the cluster nodes.
...
...  Mistify-OS includes a script named "cluster-init" which is used by this
...  test to create and initialize the cluster.
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
Resource	${TESTLIBDIR}/config/mistify.robot
Resource	${TESTLIBDIR}/resources/ssh.robot
Resource	${TESTLIBDIR}/resources/lxc.robot

Resource	${TESTLIBDIR}/resources/cluster-helpers.robot

Suite Setup	Use Cluster Container
Suite Teardown	Release Cluster Container

*** Variables ***
${_testdir}  /tmp/test

*** Test Cases ***
Select Test Node
    [Documentation]  One node serves as the primary node for initializing the
    ...  cluster.
    Use Node  @{MISTIFY_CLUSTER_NODES}[0]

Setup Network
    [Documentation]  Set the network back to a known state.
    SSH Run  ~/testlib/scripts/vm-network
    
Verify The Cluster Initialization Script Exists
    [Documentation]  This series of tests depends upon /root/clutster-init.
    ...  Verify it exists on the target.
    /root/cluster-init Should Exist
    /root/nodes-config Should Exist

Setup Init Test Dir
    [Documentation]  The cluster initialization script is run from a different
    ...  directory in order to avoid having to rename files to change
    ...  configuration.
    SSH Run  mkdir -p ${_testdir}
    SSH Run  cp /root/cluster-init ${_testdir}
    SSH Run  cp /root/nodes-config ${_testdir}/cluster-init-config

Shutdown The DHCP Server
    [Documentation]  Stop the DHCP server running in the container. This is
    ...  necessary because the cluster will provide its own DHCP services.
    Release Node
    ${_o}=  SSH Run And Get Output
    ...  ~/testlib/scripts/vm-network --shutdowndhcpd
    Should Contain  ${_o}  The dhcp server is not running
    Use Node  @{MISTIFY_CLUSTER_NODES}[0]

Run The Cluster Init Script
    [Documentation]  Now run the cluster-init script and verify the output.
    ${_o}=  SSH Run  ${_testdir}/cluster-init  return

Verify configure_network
    ssh.Set Client Configuration  timeout=3s
    ${_o}=  SSH Wait For Output  stopping nconfigd to avoid races
    Should Not Contain  ${_o}  Error

*** Keywords ***
