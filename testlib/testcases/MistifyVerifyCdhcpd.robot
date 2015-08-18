*** Settings ***
Documentation	This script performs basic verification that cdhcpd is
...		functional.
...
...	NOTE: This assumes cdhcpd was enabled in the nconfigd test.

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
Select Test Node
    [Documentation]  Select which node to run the tests against.
    Use Node  @{MISTIFY_CLUSTER_NODES}[0]

Is cdhcpd Active
    [Documentation]	Verify cdhcpd is active.
    Service cdhcpd Should Be active

Is cdhcpd Running
    cdhcpd Is Running

Was cdhcpd Configured
    [Documentation]	Verify the DHCP server was configured.
    /etc/dhcp/dhcpd.conf Should Contain lochness.local
    /etc/dhcp/dhcpd.conf Should Contain ${MISTIFY_CLUSTER_PRIMARY_IP}

*** Keywords ***
