*** Settings ***
Documentation	This script performs basic verification that dns (cbootstrapd) is
...		functional.
...

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

*** Test Cases ***
Select Test Node
    [Documentation]  Select which node to run the tests against.
    Use Node  @{MISTIFY_CLUSTER_NODES}[0]

Is cbootstrapd Active
    [Documentation]	Verify cbootstrapd is active.
    Service cbootstrapd Should Be active

Is cbootstrapd Running
    cbootstrapd Is Running

Was cbootstrapd Responds
    [Documentation]	This uses curl to see if cbootstrapd replys to a.
    ...			query.
    ...	This should produce an error from cbootstrapd since it has not yet
    ...	been configured.
    ${_if}=  Learn Test Interface
    ${_ip}=  Learn IP Address  ${_if}
    ${_o}=  SSH Run And Get Key Line  CFG:
    ...  curl http://ipxe.services.lochness.local:8888/config/${_ip}
    Should Contain  ${_o}  hypervisor not found

*** Keywords ***
