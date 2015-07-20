*** Settings ***
Documentation	This script performs basic verification that dns (queensland) is
...		functional.
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

*** Test Cases ***
Get Node Information
    Use Node  @{MISTIFY_CLUSTER_NODES}[0]

Is queensland Active
    [Documentation]	Verify queensland is active.
    Service queensland Should Be active

Is queensland Running
    queensland Is Running

Was queensland Configured
    [Documentation]	This uses etcdctl to verify the ip address.
    ${_if}=  Learn Test Interface
    ${_ip}=  Learn IP Address  ${_if}
    ${_o}=  SSH Run And Get Key Line  CFG:
    ...  etcdctl get /queesnland/nodes/`hostname`

*** Keywords ***
