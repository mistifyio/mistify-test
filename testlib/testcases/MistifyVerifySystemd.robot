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
Resource	${TESTLIBDIR}/resources/mistify.robot
Resource	${TESTLIBDIR}/resources/ssh.robot
Resource	${TESTLIBDIR}/resources/lxc.robot

Resource	${TESTLIBDIR}/resources/cluster-helpers.robot

Suite Setup	Use Cluster Container
Suite Teardown	Release Cluster Container

*** Variables ***

*** Test Cases ***
Verify Systemd Is Functional
    [Documentation]	Verify systemctl can be used to check service states.
    [Setup]  Get Command Line Options
    Run Keyword If  '${ts_setup}'=='reset'  Update Mistify Images
    Use Node  @{MISTIFY_CLUSTER_NODES}[0]  ${ts_setup}
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
    Wait 5 Seconds Until Service etcd Is active
    ${_o}=  Get etcd Log Since ${_t}
    Should Contain  ${_o}  Stopping etcd
    Should Contain  ${_o}  Stopped etcd
    Should Contain  ${_o}  Started etcd
    Should Contain  ${_o}  Starting etcd
    Should Contain  ${_o}  listening for peers on

Verify Etcd Is Active
    [Documentation]	The etcd service is configured to automatically restart
    ...			after 5 seconds. Verify this happened.
    Service etcd Should Be active

*** Keywords ***
