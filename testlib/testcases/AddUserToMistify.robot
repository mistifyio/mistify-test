*** Settings ***
Documentation	This creates a user in Mistify-OS having the same credentials as the
...		user running this testsuite.
...
...	This script deals with that problem by creating a user of the
...	same name in the container using a known password and then
...	uses that password to install keys in the user's home directory
...	within the container.

Library		String

#+
# NOTE: The variable TESTLIBDIR is passed from the command line by the testmistify
# script. There is no default value for this variable.
#-
Resource	${TESTLIBDIR}/config/mistify.robot
Resource	${TESTLIBDIR}/resources/ssh.robot
Resource	${TESTLIBDIR}/resources/lxc.robot

Resource	${TESTLIBDIR}/resources/node-helpers.robot

Suite Setup             Setup Testsuite
Suite Teardown          Teardown Testsuite

*** Variables ***

*** Test Cases ***
Verify Container Is Running
    [Tags]	Net-config
    ${_rc}=	Is Container Running	${containername}
    Should Be Equal As Integers	${_rc}	1

Get Container IP Address
    [Tags]	Net-config
    Log To Console	\n
    ${_o}=	Container IP Address	${containername}
    Log To Console	\nContainer IP address: ${_o}
    Should Contain X Times	${_o}  \.  3
    Set Suite Variable	${ip}  ${_o}
    Log To Console	\nContainer IP address is: ${ip}

Login To Container
    [Tags]	Net-config
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
    Collect SDK Attributes


Add User To All SDK Instances
    :FOR  ${_n}  IN  @{MISTIFY_SDK_NODES}
      \  Log To Console  \nLogin to node: ${_n}
      \  Use Node  ${_n}
      \  Create User In Mistify  ${USER}  ${MISTIFY_SDK_USER_ID}
      \  Verify User Entry In Passwd  ${USER}  ${MISTIFY_SDK_USER_ID}
      \  Verify User Entry In Group  ${USER}  ${MISTIFY_SDK_USER_ID}
      \  Verify User Home Directory  ${USER}
      \  Set User Password  ${USER}
      \  Enable Nopassword Sudo For User  ${USER}
      \  Enable Temporary File Write Permissions
      \  Release Node
      \  Verify User Can SSH  ${USER}  ${_n}
      \  Transfer User Keys  ${USER}  ${_n}

*** Keywords ***

Create User In Mistify
    [Documentation]	Create the user account if it doesn't exist.
    ...
    ...		NOTE: It is possible this test is being run following
    ...		a previous run where the user account was created.
    [Arguments]  ${_user}  ${_userid}
    ${_u}=  SSH Run And Get Key Line  KEY
    ...  getent passwd ${_user} \| cut -d : -f 1
    Run Keyword If  '${_u}' != '${_user}'
    ...  Create User  ${_user}  ${_userid}

Verify User Entry In Passwd
    [Documentation]  This verifies an entry for the user exists in the password
    ...  file.
    [Arguments]  ${_user}  ${_userid}
    ${_o}=  SSH Run And Get Key Line  KEY
    ...  grep ${_user} /etc/passwd
    Log Message  \nGrep returned: ${_o}
    Should Contain  ${_o}  ${_user}:x:${_userid}:${_userid}:
    Should Contain  ${_o}  /home/${_user}

Verify User Entry In Group
    [Documentation]  This verifies an entry for the user exists in the group
    ...  file.
    [Arguments]  ${_user}  ${_userid}
    ${_o}=  SSH Run And Get Key Line  KEY
    ...  grep ${_user} /etc/group
    Log Message  \nGrep returned: ${_o}
    Should Contain  ${_o}  ${_user}:x:${_userid}:

Verify User Home Directory
    [Documentation]  This verifies then home directory for the user exists.
    [Arguments]  ${_user}
    ${_o}=  SSH Run And Get Key Line  KEY
    ...  ls /home \| grep ${_user}
    Log Message  \nGrep returned: ${_o}
    Should Contain  ${_o}  ${_user}

Set User Password
    [Documentation]	Set the user password to be the same as the user name.
    [Arguments]  ${_user}

    Log Message  Unlocking user account: ${_user}
    ${_o}=  SSH Run And Get Output  passwd -u ${_user}
    Should Contain  ${_o}  Password for ${_user} changed by root
    Log Message  Setting null password for ${_user}
    ${_o}=  SSH Run And Get Output  passwd -d ${_user}
    Should Contain  ${_o}  Password for ${_user} changed by root

Enable Nopassword Sudo For User
    [Documentation]  In order to perform some admin functions using scripts it's
    ...  easiest (and least secure) to not require a password for sudo.
    [Arguments]  ${_user}
    Log To Console  \nWriting config to /etc/sudoers.d/${_user}
    SSH Run  cd /etc/sudoers.d
    SSH Run  echo "${_user} ALL=(ALL) NOPASSWD:ALL">${_user}
    ${_o}=  SSH Run And Get Output  cat ${_user}
    Should Contain  ${_o}  ${_user}
    Should Contain  ${_o}  NOPASSWD

Verify User Can SSH
    [Documentation]  Verify that the user can ssh to Mistify-OS.
    [Arguments]  ${_user}  ${_node}
    Log To Console  \nLogging in as ${_user} to Mistify-OS at node: ${_node}
    SSH As User To Node  ${_user}  ${_node}
    ${homedir}=  SSH Run And Get Key Line  KEY  pwd
    Should Contain  ${homedir}  ${_user}
    Set Suite Variable  ${homedir}
    SSH Run  exit

Transfer User Keys
    [Documentation]	The user keys are needed mostly for the build
    ...			process.
    ...
    ...		The build accesses a number of git repositories. Having
    ...		the keys means not having to enter the password. In order
    ...		for this to work the public keys need to be installed on
    ...		the different servers.
    [Arguments]  ${_user}  ${_node}
    Log Message	\nCopying ssh keys to the Mistify-OS node.
    Copy Directory As User To Node  ${_user}  ${_node}  ~/.ssh  ~
    Run Command As User On Node  ${_user}  ${_node}
    ...  chmod 600 ~/ssh/*
    Log Message  Copied keys to node ${_node}.

Enable Temporary File Write Permissions
    [Documentation]  By default mistify-os has permissions on /tmp set to
    ...  writtable only by root. For a lot of tools to work for the user this
    ...  needs to be writable by the user.
    Log Message  \nEnabling write permissions on /tmp.
    SSH Run  chmod 777 /tmp

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


Create User
    [Documentation]  This creates a user in the Mistify-OS environment.
    [Arguments]  ${_user}  ${_userid}
    Log To Console  \nCreating user: ${_user}
    Log Message  Creating account for ${_user} using ID ${_userid}
    SSH Run  adduser -u ${${_userid}} -s `which bash` -D ${_user}

