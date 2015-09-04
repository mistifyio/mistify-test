*** Settings ***
Documentation  This test suite is used to verify cluster creation and running
...  cluster operation in VMs inside a container.
...
...  This script emmits parameters and variables to the log file to document
...  the settings used for this suite of tests.

Resource	${TESTLIBDIR}/resources/mistify.robot
Resource	${TESTLIBDIR}/resources/cluster-helpers.robot

*** Test Cases ***
Record States
    [Documentation]     Record the variables and other settings for this suite.
    Get Command Line Options
    Log Variables

