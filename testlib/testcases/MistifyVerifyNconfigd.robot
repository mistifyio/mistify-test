*** Settings ***
Documentation	This script performs basic verification that nconfigd is
...		functional.
...
...	This uses a single node to verify nconfigd. It also uses the etcd service
...	to verify nconfigd responds to configuration changes.
...
...	This assumes a system configuration as setup by
...	ClusterInitialization.robot. All node VMs are running and all screen
...	sessions are detached.
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
Get Node Informatin
    Collect Attributes
    Use Node  @{MISTIFY_CLUSTER_NODES}[0]  ${ts_setup}

Is Nconfigd Active
    [Documentation]	Verify nconfigd is active.
    ${_l}=  SSH Run And Get Key Line  NCD=
    ...  systemctl --no-pager is-active nconfigd
    Service nconfigd Should Be active

Can Nconfigd Be Shutdown
    [Documentation]	Verify the nconfigd service can be shutdown using systemctl.
    ${_c}=  catenate
    ...	systemctl stop nconfigd >/dev/null;
    SSH Run   systemctl stop nconfigd >/dev/null
    Wait Until Keyword Succeeds  3 s  1 s  Service nconfigd Should Be inactive

Can Nconfigd Be Configured
    [Documentation]	Reconfigure nconfigd using etcdctl and verify the change
    ...			takes effect.
    Enable Nconfigd For Service  @{MISTIFY_CLUSTER_NODES}[0]  dhcpd
    Enable Nconfigd For Service  @{MISTIFY_CLUSTER_NODES}[0]  dns
    Enable Nconfigd For Service  @{MISTIFY_CLUSTER_NODES}[0]  cbootstrapd
    Enable Nconfigd For Service  @{MISTIFY_CLUSTER_NODES}[0]  etcd
    Enable Nconfigd For Service  @{MISTIFY_CLUSTER_NODES}[0]  tftpd
    Enable Nconfigd For Service  @{MISTIFY_CLUSTER_NODES}[1]  dns
    Enable Nconfigd For Service  @{MISTIFY_CLUSTER_NODES}[1]  etcd
    Enable Nconfigd For Service  @{MISTIFY_CLUSTER_NODES}[2]  dns
    Enable Nconfigd For Service  @{MISTIFY_CLUSTER_NODES}[2]  etcd

Can Nconfigd Be Restarted
    [Documentation]	Verify the nconfigd service can be restarted using systemctl.
    SSH Run   systemctl start nconfigd >/dev/null
    Wait Until Keyword Succeeds  45 s  1 s  Service nconfigd Should Be active

*** Keywords ***
Enable Nconfigd For Service
    [Arguments]  ${_node}  ${_service}
    ${_u}=  Get Node UUID  ${_node}
    SSH Run  etcdctl set /lochness/hypervisors/${_u}/config/${_service} true
    Check Service State  ${_node}  ${_service}

Check Service State
    [Arguments]  ${_node}  ${_service}
    ${_u}=  Get Node UUID  ${_node}
    ${_o}=  SSH Run And Get Key Line  VAL:
    ...  etcdctl get /lochness/hypervisors/${_u}/config/${_service}
    Should Contain  ${_o}  true
    Log Message  Service state: ${_node} ${_service} ${_o}

