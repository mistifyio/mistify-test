*** Settings ***
Documentation    This runs a simple test similar to the original demo of the MVP.
...
...	The test is executed using a container which was previously prepared
...	using the ProvisionTestContainer.robot script.
...	NOTE: This requires a build of Mistify-OS exists from which to obtain
...	the kernel and initrd images used for the test. Also, guest images
...	need to have been previously downloaded.
...
...	The container is left running with each node running in a separate VM
...	and and their consoles accessable in screen sessions which have been
...	named to match the name of the node's interface.

Library		String

#+
# NOTE: The variable TESTLIBDIR is passed from the command line by the testmistify
# script. There is no default value for this variable.
#-
Resource	${TESTLIBDIR}/resources/mistify.robot
Resource	${TESTLIBDIR}/resources/ssh.robot
Resource	${TESTLIBDIR}/resources/lxc.robot

Resource	${TESTLIBDIR}/resources/cluster-helpers.robot

Suite Setup             Setup Testsuite
Suite Teardown          Teardown Testsuite

*** Variables ***
${httpserverdir}	http

*** Test Cases ***
Verify Container Is Running
    ${_rc}=	Is Container Running	${containername}
    Should Be Equal As Integers	${_rc}	1

Get Container IP Address
    Log To Console	\n
    ${_o}=	Container IP Address	${containername}
    Log To Console	\nContainer IP address: ${_o}
    Should Contain X Times	${_o}  \.  3
    Set Suite Variable	${ip}  ${_o}
    Log To Console	\nContainer IP address is: ${ip}

Login To Container
    Log To Console  \nLogging in as ${USER} to container at IP: ${ip}
    Login to SUT  ${ip}  ${USER}  ${USER}
    ${_o}=  SSH Run And Get Output  pwd
    ${homedir}=  Get Line  ${_o}  0
    Should Contain  ${homedir}  /home/${USER}
    Set Suite Variable  ${homedir}
    Log To Console  Home directory is: ${homedir}

Collect Node Attributes
    [Documentation]  Collect the node attributes for use by the other tests.
    ...
    ...  NOTE: Since "Collect Attributes" creates a global scope variable
    ...  (${Nodes}) any test suites following this one will be able to access
    ...  the already collected atributes for each of the test nodes.
    Collect Attributes

Log Node Attributes
    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
    \  ${_a}=  Get From Dictionary  ${Nodes}  ${_n}
    \  ${_uuid}=  Get From Dictionary  ${_a}  uuid
    \  ${_if}=  Get From Dictionary  ${_a}  if
    \  ${_ip}=  Get From Dictionary  ${_a}  ip
    \  ${_mac}=  Get From Dictionary  ${_a}  mac
    \  Log Message  \n----\nNode: ${_n}
    \  Log Message  uuid: ${_uuid}
    \  Log Message  network interface: ${_if}
    \  Log Message  ip: ${_ip}
    \  Log Message  mac: ${_mac}

*** Keywords ***
Setup Testsuite
    ${containername}=	Container Name
    Set Suite Variable  ${containername}
    Set Suite Variable  ${rootprompt}  root\@${containername}
    Set Suite Variable  ${userprompt}  ${USER}\@${containername}
    Log To Console  containername = ${containername}
    Log To Console  rootprompt = ${rootprompt}
    Log To Console  userprompt = ${userprompt}

    ${_rc}=	Use Container
    ...	${containername}  ${DISTRO_NAME}
    ...	${DISTRO_VERSION_NAME}	${DISTRO_ARCH}
    Log To Console	\nUsing container: ${containername}
    Run Keyword Unless  ${_rc} == 0
    ...	Log To Console	\nContainer could not be started.
    ...		WARN

Teardown Testsuite
    Disconnect From SUT
    # Stop Container	${containername}

