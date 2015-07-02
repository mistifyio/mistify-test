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
    [Setup]	Use Node  @{MISTIFY_CLUSTER_NODES}[0]  ${ts_setup}
    ${_l}=  SSH Run And Get First Line  systemctl --no-pager is-system-running
    Should Contain  ${_l}  running
    SSH Run  systemctl --no-pager --state=failed

Verify Etcd Is Running
    [Documentation]	Verify the etcd service is running. This should be
    ...			running following boot.
    ${_l}=  SSH Run And Get First Line  systemctl --no-pager is-active etcd
    Should Contain  ${_l}  active

Verify Etcd Can Be Shutdown
    [Documentation]	Verify the etcd service can be shutdown using systemctl.

    ${_c}=  catenate
    ...	systemctl --no-pager stop etcd >/dev/null;
    ...	systemctl --no-pager is-active etcd
    ${_l}=  SSH Run And Get First Line  ${_c}
    Should Contain  ${_l}  inactive

Verify Etcd Will Be Restarted
    [Documentation]	The etcd service is configured to automatically restart
    ...			after 5 seconds. Verify this happens.
    Sleep  7  Wait for etcd to be automatically restarted.
    ${_l}=  SSH Run And Get First Line  systemctl --no-pager is-active etcd
    Should Contain  ${_l}  active

*** Keywords ***
