*** Settings ***
Documentation	This script performs basic verification that systemd is
...		functional.
...
...	This uses a single node to verify systemd. It also uses the etcd service
...	to verify services can be started and restarted. The etcd service is
...	configured to automatically restart which serves to verify systemd will
...	restart a service which has been configured to do so.
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

Verify Systemd Is Functional
    [Documentation]	Verify systemctl can be used to check service states and.
    ...  systemd is in a running state (not degraded or failed).
    ${_l}=  SSH Run And Get First Line  systemctl --no-pager is-system-running
    Should Contain  ${_l}  running

Verify No Failed Services
    ${_o}=  Get List Of failed Services
    Should Not Contain  ${_o}  failed

Verify Etcd Is Running
    [Documentation]	Verify the etcd service is running. This should be
    ...			running following boot.
    Service etcd Should Be active

Verify Etcd Can Be Shutdown
    [Documentation]	Verify the etcd service can be shutdown and automatically
    ...			restarted by systemd.

    ${_t}=  Mark Time

    Stop Service etcd
    ${_o}=  Get etcd Log Since ${_t}
    Should Contain  ${_o}  Stopping etcd
    Should Contain  ${_o}  Stopped etcd

Verify Etcd Is Inactive
    [Documentation]	The etcd service should be inactive after using systemd
    ...			to stop it.

    Wait 10 Seconds Until Service etcd Is inactive
    Service etcd Should Be inactive
    ${_o}=  Get etcd Log Since ${marker}
    Should Not Contain  ${_o}  Started etcd
    Should Not Contain  ${_o}  Starting etcd

Verify Etcd Becomes Active When Started
    [Documentation]	The etcd service should be active shortly after using
    ...			systemd to start it.

    ${_t}=  Mark Time

    Start Service etcd
    Wait 10 Seconds Until Service etcd Is active
    ${_o}=  Get etcd Log Since ${_t}
    Should Contain  ${_o}  Starting etcd
    Should Contain  ${_o}  Started etcd

*** Keywords ***
