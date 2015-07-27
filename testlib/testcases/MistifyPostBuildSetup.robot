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

*** Variables ***

*** Test Cases ***
Prepare For New Test Run
    Get Command Line Options
    Use Cluster Container
    Run Keyword If  '${ts_setup}'=='reset'  Update Mistify Images
    # Test cases assume already logged into the nodes.
    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
      \  Use Node  ${_n}  reset
      \  Release Node

*** Keywords ***
