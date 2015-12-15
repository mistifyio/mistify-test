*** Settings ***
Documentation	This creates a user having the same credentials as the
...		user running this testsuite.
...
...	A problem with using unprivileged containers is the user and
...	group IDs are remapped for security reasons. This enables root
...	access inside the container without worry of corrupting the host
...	environment. The problem is that the host side user can't easily
...	install keys for use with other hosts (e.g. github) and results
...	in having to enter a password over and over again which is
...	unacceptable for unattended builds.
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

Suite Setup             Setup Testsuite
Suite Teardown          Teardown Testsuite

*** Variables ***

*** Test Cases ***
Show Prompts
    Log To Console  containername = ${containername}
    Log To Console  rootprompt = ${rootprompt}
    Log To Console  userprompt = ${userprompt}

Connect To Container
    Login To Localhost
    ssh.Write  lxc-attach -n ${containername}
    ${_o}=  ssh.Read Until  ${rootprompt}
    Log To Console  \nAttached to: ${_o}
    Should Contain  ${_o}  ${rootprompt}

Define Package List
    [Documentation]	This is the list of packages needed to support running
    ...			multiple VMs in the container which can communicate with
    ...			each other.
    ${packages}=  catenate  SEPARATOR=${SPACE}
    ...  openssh-server sshpass
    Set Suite Variable  ${packages}

Update APT Database
    [Documentation]	The package database needs to be updated
    ...			before the packages can be installed.
    Log To Console  \nThis works only for debian based distros!!
    Log To Console  \nInstalling: ${packages}
    ssh.Write  ls /
    ${_o}=  ssh.Read Until  ${rootprompt}  loglevel=INFO
    Log To Console  \nUpdating the package database.
    ssh.Set Client Configuration  timeout=1m
    ssh.Write  apt-get update
    ${_o}=  ssh.Read Until  ${rootprompt}  loglevel=INFO

Install Key Tools
    ssh.Write  apt-get install -y ${packages}
    ssh.Set Client Configuration  timeout=20m
    ${_o}=  ssh.Read Until  ${rootprompt}  loglevel=INFO
    Log To Console  \napt-get returned:\n${_o}
    ssh.Set Client Configuration  timeout=3m

Verify Key Tools Installed
    Log To Console  \nThis works only for debian based distros!!
    Log To Console  \nPackage list: ${packages}
    ssh.Write  dpkg -l \| awk '/^[hi]i/{print $2}'
    ${_o}=	ssh.Read Until	${rootprompt}
    Log To Console  \nInstalled packages:\n${_o}
    @{_packages}=	Split String  ${packages}
    :FOR  ${_p}  IN  @{_packages}
    	\	Should Contain  ${_o}  ${_p}

Create User In Container
    [Documentation]	Create the user account if it doesn't exist.
    ...
    ...		NOTE: It is possible this test is being run following
    ...		a previous run where the user account was created.
    ssh.Write  getent passwd ${USER} \| cut -d : -f 1
    ${_o}=	ssh.Read Until  ${rootprompt}
    ${_u}=	Get Line  ${_o}  0
    Run Keyword If  '${_u}' != '${USER}'
    ...  Create User  ${USER}

Verify User Entry In Passwd
    ssh.Write  grep ${USER} ${/}etc${/}passwd
    ${_o}=  ssh.Read Until  ${rootprompt}
    Log To Console  \nGrep returned: ${_o}
    Should Contain  ${_o}  ${USER}

Verify User Entry In Group
    ssh.Write  grep ${USER} ${/}etc${/}group
    ${_o}=  ssh.Read Until  ${rootprompt}
    Log To Console  \nGrep returned: ${_o}
    Should Contain  ${_o}  ${USER}

Verify User Home Directory
    ssh.Write  ls ${/}home \| grep ${USER}
    ${_o}=  ssh.Read Until  ${rootprompt}
    Log To Console  \nGrep returned: ${_o}
    Should Contain  ${_o}  ${USER}

Set User Password
    [Documentation]	Set the user password to be the same as the user name.

    Log To Console  \nSetting user ${USER} password to ${USER}
    ssh.Write  passwd ${USER}
    ssh.Read Until  password:
    ssh.Write  ${USER}
    ssh.Read Until  password:
    ssh.Write  ${USER}
    ${_O}=  ssh.Read Until  ${rootprompt}
    Should Contain  ${_o}  password updated successfully

Add User To Sudo
    [Documentation]	Some commands in the container must be executed as
    ...			root when executing test cases.
    Log To Console  \nAdding user ${USER} to the sudo group.
    ${_o}=  SSH Run And Get Return Code	adduser ${USER} sudo
    Should Be Equal As Integers  ${_o}  ${0}

Enable Nopassword Sudo For User
    ${_t}=  catenate  SEPARATOR=${SPACE}
    ...  ${USER} ALL=(ALL) NOPASSWD:ALL
    Log To Console  \nWriting ${_t} to /etc/sudoers.d/${USER}
    SSH Run  cd /etc/sudoers.d
    SSH Run  echo "${_t}">${USER}
    ${_o}=  SSH Run And Get Output  cat ${USER}
    Should Contain  ${_o}  ${USER}
    Should Contain  ${_o}  NOPASSWD

Detach From Container
    ssh.Write  exit
    # NOTE: Switching SSH connections is not yet supported.
    Disconnect From Localhost

Verify User Can SSH
    ${ip}=	Container IP Address  ${containername}
    Set Suite Variable  ${ip}
    Log To Console  \nLogging in as ${USER} to container at IP: ${ip}
    Login to SUT  ${ip}  ${USER}  ${USER}
    ssh.Write  pwd
    ${homedir}=  ssh.Read Until  ${userprompt}
    Should Contain  ${homedir}  ${USER}
    Set Suite Variable  ${homedir}
    Disconnect From SUT

Transfer User Keys
    [Documentation]	The user keys are needed mostly for the build
    ...			process.
    ...
    ...		The build accesses a number of git repositories. Having
    ...		the keys means not having to enter the password. In order
    ...		for this to work the public keys need to be installed on
    ...		the different servers.
    Log To Console	\nCopying local keys from ${HOME} to\n
    ...  		the container at ${homedir}.
    Login to SUT  ${ip}  ${USER}  ${USER}
    ssh.Put Directory  ${HOME}/.ssh  /home/${USER}  mode=600
    Log To Console  Copied keys.
    Disconnect From SUT

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
    ...	${containername}	${DISTRO_NAME}
    ...	${DISTRO_VERSION_NAME}	${DISTRO_ARCH}
    Log To Console	\nUsing container: ${containername}
    Run Keyword Unless  ${_rc} == 0
    ...	Log To Console	\nContainer could not be created.
    ...		WARN

Teardown Testsuite
    ssh.Close All Connections
    Stop Container	${containername}

Create User
    [Arguments]  ${_user}
    Log To Console  \nCreating user: ${_user}
    ssh.Write  useradd -m -s ${/}bin${/}bash -U ${_user}
    ssh.Read Until  ${rootprompt}

