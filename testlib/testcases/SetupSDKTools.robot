*** Settings ***
Documentation	This performs the steps necessary to setup to use the
...  buildmistify script to build mistify-os in the mistify-os environment.
...
...  NOTE: This at the moment is hardcoded in places because the steps necessary
...  have only recently been worked out.

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

Install Latest Mistify Build
    [Documentation]  Later, each node will be reset. Install the latest build
    ...  so the nodes will boot using the latest kernel and initrd.
    Update Mistify Images

Collect Node Attributes
    [Documentation]  Collect the node attributes for use by the other tests.
    ...
    ...  NOTE: Since "Collect Attributes" creates a global scope variable
    ...  (${Nodes}) any test suites following this one will be able to access
    ...  the already collected atributes for each of the test nodes.
    ...
    ...  NOTE: The root user needs to be logged into the console.
    Collect SDK Attributes

Setup Tools In All SDK Instances
    [Documentation]  This installs the tools needed to run buildmistify.
    ...  NOTE: Since the rootfs is actually a RAM disk many of these changes
    ...  are not persistent across boots.
    :FOR  ${_n}  IN  @{MISTIFY_SDK_NODES}
      \  Log Message  Resetting node to initial state: ${_n}
      \  Use Node  ${_n}  reset
      \  Release Node
      \  Log Message  \nSSH to node: ${_n}
      \  SSH As User To Node  ${USER}  ${_n}
      \  Create Needed Directories  ${USER}
      \  Install unzip
      \  Install autotools Package  texinfo  4.13  _flags=LDFLAGS=" -L/usr/lib -lncurses"
      \  Install autotools Package  ccache  3.2.3  _url=http://samba.org/ftp
      \  Install Mercurial
      \  Install Python PIP
      \  Install Robot Framework
      \  Authenticate With Github
      \  Clone The Mistify Test Repo
      \  Clone The Mistify OS Repo
      \  SSH Run  exit

*** Keywords ***
Create Needed Directories
    [Documentation]  This creates some directories which are needed later.
    ...  These are the directories for the mistify relelated clones, where
    ...  downloaded files are maintained and, where toolchains will reside.
    [Arguments]  ${_user}
    # This makes these directories persistent and relative to the user.
    SSH Run  sudo mkdir -p ${MISTIFY_SDK_ROOT}
    SSH Run  sudo chown ${_user}.${_user} ${MISTIFY_SDK_ROOT}
    SSH Run  mkdir -p ${MISTIFY_SDK_SYSROOT}/usr/include
    # SSH Run  sudo ln -s ${MISTIFY_SDK_SYSROOT}/usr/include /usr/include
    SSH Run  mkdir -p ${MISTIFY_SDK_SYSROOT}/usr/local
    SSH Run  sudo ln -s ${MISTIFY_SDK_SYSROOT}/usr/local /usr/local
    SSH Run  mkdir ${MISTIFY_SDK_ROOT}/downloads
    SSH Run  mkdir ${MISTIFY_SDK_ROOT}/projects
    SSH Run  mkdir ${MISTIFY_SDK_ROOT}/tmp

Install autotools Package
    [Documentation]  This installs a GNU package using autoconf.
    [Arguments]  ${_package}  ${_version}
    ...  ${_install}=install
    ...  ${_url}=http://ftp.gnu.org/gnu
    ...  ${_flags}=${SPACE}
    Log Message  \nInstalling ${_package}-${_version}
    ssh.Set Client Configuration  timeout=5m
    SSH Run  cd ${MISTIFY_SDK_ROOT}/tmp
    ${_i}=  SSH Run And Get Return Code
    ...  wget ${_url}/${_package}/${_package}-${_version}.tar.gz
    ...  _delay=10s
    Should Be Equal As Integers  ${_i}  ${0}
    SSH Run  tar xzf ${_package}-${_version}.tar.gz
    SSH Run  cd ${_package}-${_version}
    SSH Run  ${_flags} ./configure --prefix=/usr && make && sudo make ${_install}  _delay=15s
    ssh.Set Client Configuration  timeout=3s

Install unzip
    [Documentation]  The busybox version of unzip works in most cases but
    ...  doesn't always. So build natively.
    Log Message  \nInstalling unzip.
    ssh.Set Client Configuration  timeout=5m
    SSH Run  cd ${MISTIFY_SDK_ROOT}/tmp
    ${_i}=  SSH Run And Get Return Code
    ...  wget http://downloads.sourceforge.net/infozip/unzip60.tar.gz
    ...  _delay=10s
    Should Be Equal As Integers  ${_i}  ${0}
    SSH Run  tar xzf unzip60.tar.gz
    SSH Run  cd unzip60
    SSH Run  make CC=gcc -f unix/Makefile generic  _delay=15s
    SSH Run  sudo make prefix=/usr MANDIR=/usr/share/man/man1 -f unix/Makefile install
    ...  _delay=15s
    ssh.Set Client Configuration  timeout=3s

Install Mercurial
    [Documentation]  Some buildroot packages use hg to clone the source.
    ...  Mercurial provides this but because of the embedded paths.
    ...  in python can't be installed using pip. So get the source and
    ...  compile locally.
    [Arguments]  ${_version}=3.5.2
    Log Message  \nInstalling Mercurial.
    ssh.Set Client Configuration  timeout=5m
    SSH Run  cd ${MISTIFY_SDK_ROOT}/tmp
    ${_i}=  SSH Run And Get Return Code
    ...  wget https://www.mercurial-scm.org/release/mercurial-${_version}.tar.gz
    ...  _delay=10s
    Should Be Equal As Integers  ${_i}  ${0}
    SSH Run  tar xzf mercurial-${_version}.tar.gz
    SSH Run  cd mercurial-${_version}
    SSH Run  sudo make install  _delay=15s
    ssh.Set Client Configuration  timeout=3s

Install Python PIP
    [Documentation]  PIP is used to install Python packages.
    ssh.Set Client Configuration  timeout=3m
    SSH Run  cd ${MISTIFY_SDK_ROOT}/downloads
    ${_o}=  SSH Run And Get Output  wget https://bootstrap.pypa.io/get-pip.py
    ...  _delay=10s
    Should Contain  ${_o}  saved
    SSH Run  cd ${MISTIFY_SDK_ROOT}/tmp
    ${_o}=  SSH Run And Get Output  sudo python ${MISTIFY_SDK_ROOT}/downloads/get-pip.py
    ...  _delay=5s
    Should Contain  ${_o}  Successfully installed pip
    ssh.Set Client Configuration  timeout=3s

Install Robot Framework
    [Documentation]  So some tests can be executed in the mistify-os environment
    ...  Robot Framework is installed.
    ssh.Set Client Configuration  timeout=3m
    ${_o}=  SSH Run And Get Output  sudo pip install robotframework
    ...  _delay=10s
    Should Contain  ${_o}  Successfully installed robotframework
    ssh.Set Client Configuration  timeout=3s

Authenticate With Github
    [Documentation]  Using the keys previously installed in .ssh authenticate
    ...  with github.com so can clone and update projects.
    ssh.Set Client Configuration  timeout=30s
    ${_o}=  SSH Run And Get Output  ssh -T git@github.com  _delay=10s
    Should Contain  ${_o}  successfully authenticated
    ssh.Set Client Configuration  timeout=3s

Clone The Mistify Test Repo
    [Documentation]  Some of the scripts and tests from mistiy-test are handy.
    ...  Clone the repo so can use them.
    ssh.Set Client Configuration  timeout=3m
    SSH Run  cd ${MISTIFY_SDK_ROOT}/projects
    ${_o}=  SSH Run And Get Output
    ...  git clone git@github.com:mistifyio/mistify-test.git  _delay=10s
    Should Contain  ${_o}  Cloning into
    Should Contain  ${_o}  Checking connectivity... done.
    SSH Run  cd mistify-test

    # Temporary -- switch to the feature branch -- may make this an option later.
    ${_o}=  SSH Run And Get Output  git checkout feature
    Should Contain  ${_o}  Switched to a new branch 'feature'

    ssh.Set Client Configuration  timeout=3s

Clone The Mistify OS Repo
    [Documentation]  This the reason for doing all this. The objective is to.
    ...  eventually build mistify-os.

    ssh.Set Client Configuration  timeout=3m
    SSH Run  cd ${MISTIFY_SDK_ROOT}/projects
    ${_o}=  SSH Run And Get Output
    ...  git clone git@github.com:mistifyio/mistify-os.git  _delay=10s
    Should Contain  ${_o}  Cloning into
    Should Contain  ${_o}  Checking connectivity... done.
    ssh.Set Client Configuration  timeout=3s

####
# throwaway
Install Development Headers
    [Documentation]  This copies the development headers from the seed build of
    ...  mistify-os.
    ${_c}=  catenate
    ...  ${MISTIFY_SDK_ROOT}/projects/mistify-test/testlib/scripts/scp-nostrict -r
    ...  ${MISTIFY_SDK_HOST_IP}:${BUILDDIR}/staging/usr/include/*
    ...  ${MISTIFY_SDK_SYSROOT}/usr/include/
    ${_o}=  SSH Run And Get Output  ${_c}  _delay=10s
    Should Contain  ${_o}  zlib.h

####
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

