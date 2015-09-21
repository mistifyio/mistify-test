*** Settings ***
Documentation  This test suite is used to setup a number of tools needed to.
...  build Mistify-OS using the mistify-os repo and the buildmistify script.
...
...  In order for this suite to work the sdk variant of Mistify-OS needs to be
...  built. e.g. (from the mistify-os directory)
...    ./buildmistify --variant sdk
...
...  This script emmits parameters and variables to the log file to document
...  the settings used for this suite of tests.

Resource	${TESTLIBDIR}/config/mistify.robot
Resource	${TESTLIBDIR}/resources/cluster-helpers.robot

*** Test Cases ***
Record States
    [Documentation]     Record the variables and other settings for this suite.
    Get Command Line Options
    Log Variables

