*** Settings ***
Documentation  This test suite performs a set of simple smoke tests against
...  a build of Mistify-OS. It is intended to be run immediately following a
...  build.
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

