*** Settings ***
Documentation	This prepares a container for building Mistify-OS within the
...		container.
...
...	This test suite creates an LXC container then provisions the
...	container with tools needed to run buildmistify within the container.
...
...	WARNING: Currently this supports only Debian based containers.

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

Connect To Container
    Login To Localhost
    ssh.Write  lxc-attach -n ${containername}
    ${_o}=  ssh.Read Until  ${prompt}
    Log To Console  \nAttach:\n${_o}
    Should Contain  ${_o}  ${prompt}

Define Package List
    [Documentation]	Creating this variable here because RF complained
    ...			about using this technique in the variables section
    ...			and using a true list wasn't producing the desired
    ...			results for passing the list to apt-get.
    ...	NOTE: gcc-multilib is a work around for a problem with building
    ...	multilib using crosstools-ng. This is needed in order to build an
    ...	which depends upon grub and grub is 32 bit.
    ${packages}=  catenate  SEPARATOR=${SPACE}
    ...  man build-essential  git  mercurial  unzip  bc  libncurses5-dev
    ...  syslinux  genisoimage  libdevmapper-dev  libnl-dev
    ...  autoconf  automake  libtool  gettext  autopoint
    ...  pkg-config  flex  gperf  bison  texinfo  gawk  subversion
    ...  gcc-multilib
    Set Suite Variable  ${packages}

Update APT Database
    [Documentation]	The package database needs to be updated
    ...			before the packages can be installed.
    Log To Console  \nThis works only for debian based distros!!
    Log To Console  \nInstalling: ${packages}
    ssh.Write  ls /
    ${_o}=  ssh.Read Until  ${prompt}  loglevel=INFO
    Log To Console  \nUpdating the package database.
    ssh.Set Client Configuration  timeout=3m
    ssh.Write  apt-get update
    ${_o}=  ssh.Read Until  ${prompt}  loglevel=INFO

Install Key Tools
    ssh.Write  apt-get install -y ${packages}
    ssh.Set Client Configuration  timeout=20m
    ${_o}=  ssh.Read Until  ${prompt}  loglevel=INFO
    Log To Console  \napt-get returned:\n${_o}
    ssh.Set Client Configuration  timeout=3m

Verify Key Tools Installed
    Log To Console  \nThis works only for debian based distros!!
    Log To Console  \nPackage list: ${packages}
    ssh.Write  dpkg -l \| awk '/^[hi]i/{print $2}'
    ${_o}=	ssh.Read Until	${prompt}
    Log To Console  \nInstalled packages:\n${_o}
    @{_packages}=	Split String  ${packages}
    :FOR  ${_p}  IN  @{_packages}
    	\	Should Contain  ${_o}  ${_p}

Disconnect From Container
    ssh.Write  exit
    ${_o}=  ssh.Read Until  exit
    Should Contain  ${_o}  exit
    Disconnect From Localhost

*** Keywords ***
Setup Testsuite
    ${containername}=	Container Name
    Set Suite Variable  ${containername}
    Set Suite Variable  ${prompt}  root\@${containername}
    ${_rc}=	Use Container
    ...	${containername}	${DISTRO_NAME}
    ...	${DISTRO_VERSION_NAME}	${DISTRO_ARCH}
    Log To Console	\nUsing container: ${containername}
    Run Keyword Unless  ${_rc} == 0
    ...	Log To Console	\nContainer could not be created.
    ...		WARN

Teardown Testsuite
    Stop Container	${containername}

