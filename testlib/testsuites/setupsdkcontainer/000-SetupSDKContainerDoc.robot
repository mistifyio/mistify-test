*** Settings ***
Documentation  This test suite is used to standup a container in which tests
...  against a build of Mistify-OS can be run. This created the container and
...  then initializes virtual machines running Mistify-OS. One virtual machine
...  per configured node is started. The container network is configured so that
...  the virtual machines can communicate with each other.
...
...  In order for this suite to work the sdk variant of Mistify-OS needs to be
...  built. e.g. (from the mistify-os directory)
...    ./buildmistify --variant sdk
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

