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
Get Node Information
    Collect Attributes

Select Test Node
    [Documentation]  Select which node to run the tests against.
    Use Node  @{MISTIFY_CLUSTER_NODES}[0]

Is Nconfigd Active
    [Documentation]	Verify nconfigd is active.
    Service nconfigd Should Be active

Can Nconfigd Be Shutdown
    [Documentation]	Verify the nconfigd service can be shutdown using systemctl.
    Stop Service nconfigd
    Wait Until Keyword Succeeds  3 s  1 s  Service nconfigd Should Be inactive

Can Nconfigd Be Configured
    [Documentation]	Reconfigure nconfigd using etcdctl and verify the change
    ...			takes effect.
    Enable Hypervisor For Service  @{MISTIFY_CLUSTER_NODES}[0]  dhcpd
    Enable Hypervisor For Service  @{MISTIFY_CLUSTER_NODES}[0]  dns
    Enable Hypervisor For Service  @{MISTIFY_CLUSTER_NODES}[0]  cbootstrapd
    Enable Hypervisor For Service  @{MISTIFY_CLUSTER_NODES}[0]  etcd
    Enable Hypervisor For Service  @{MISTIFY_CLUSTER_NODES}[0]  tftpd
    Enable Hypervisor For Service  @{MISTIFY_CLUSTER_NODES}[1]  dns
    Enable Hypervisor For Service  @{MISTIFY_CLUSTER_NODES}[1]  etcd
    Enable Hypervisor For Service  @{MISTIFY_CLUSTER_NODES}[2]  dns
    Enable Hypervisor For Service  @{MISTIFY_CLUSTER_NODES}[2]  etcd

Can Nconfigd Be Restarted
    [Documentation]	Verify the nconfigd service can be restarted using systemctl.
    Start Service nconfigd
    Wait Until Keyword Succeeds  45 s  1 s  Service nconfigd Should Be active

*** Keywords ***

