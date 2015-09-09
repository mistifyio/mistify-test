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
    :FOR  ${_n}  IN  @{MISTIFY_SDK_NODES}
      \  Log Message  Resetting node to initial state: ${_n}
      \  Use Node  ${_n}  reset
      \  Release Node
      \  Log Message  \nSSH to node: ${_n}
      \  SSH As User To Node  ${USER}  ${_n}
      \  Create Needed Directories
      \  Authenticate With Github
      \  Clone The Mistify Test Repo
      \  Clone The Mistify OS Repo
      \  Install The Seed Toolchain
      \  Install GNU Package  m4  1.4.17
      \  Install GNU Package  autoconf  2.69
      \  Install GNU Package  automake  1.15
      \  Install GNU Package  libtool  2.4.6
      \  Install GNU Package  bison  3.0.4
      \  Install GNU Package  flex  2.5.39  _url=http://download.sourceforge.net/project
      \  Install GNU Package  texinfo  4.13a
      \  Install GNU Package  ncurses  5.9  _install=install.includes
      \  Install Python PIP
      \  Install Robot Framework
      \  Build The GO Compiler
      \  SSH Run  exit

*** Keywords ***
Create Needed Directories
    [Documentation]  This creates some directories which are needed later.
    ...  These are the directories for the mistify relelated clones, where
    ...  downloaded files are maintained and, where toolchains will reside.
    SSH Run  mkdir ~/downloads
    SSH Run  mkdir ~/projects
    SSH Run  mkdir ~/tmp

Install Python PIP
    [Documentation]  PIP is used to install Python packages.
    ssh.Set Client Configuration  timeout=3m
    SSH Run  cd ~/downloads
    ${_o}=  SSH Run And Get Output  wget https://bootstrap.pypa.io/get-pip.py
    Should Contain  ${_o}  saved
    SSH Run  cd ~/tmp
    ${_o}=  SSH Run And Get Output  sudo python ../downloads/get-pip.py
    ...  _delay=5s
    Should Contain  ${_o}  Successfully installed pip
    ssh.Set Client Configuration  timeout=3s

Install Robot Framework
    [Documentation]  So some tests can be executed in the mistify-os environment
    ...  Robot Framework is installed.
    ssh.Set Client Configuration  timeout=3m
    ${_o}=  SSH Run And Get Output  sudo pip install robotframework
    ...  _delay=5s
    Should Contain  ${_o}  Successfully installed robotframework
    ssh.Set Client Configuration  timeout=3s

Authenticate With Github
    [Documentation]  Using the keys previously installed in .ssh authenticate
    ...  with github.com so can clone and update projects.
    ssh.Set Client Configuration  timeout=30s
    ${_o}=  SSH Run And Get Output  ssh -T git@github.com  _delay=5s
    Should Contain  ${_o}  successfully authenticated
    ssh.Set Client Configuration  timeout=3s

Clone The Mistify Test Repo
    [Documentation]  Some of the scripts and tests from mistiy-test are handy.
    ...  Clone the repo so can use them.
    ssh.Set Client Configuration  timeout=3m
    SSH Run  cd ~/projects
    ${_o}=  SSH Run And Get Output
    ...  git clone git@github.com:mistifyio/mistify-test.git  _delay=5s
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
    SSH Run  cd ~/projects
    ${_o}=  SSH Run And Get Output
    ...  git clone git@github.com:mistifyio/mistify-os.git  _delay=5s
    Should Contain  ${_o}  Cloning into
    Should Contain  ${_o}  Checking connectivity... done.
    ssh.Set Client Configuration  timeout=3s

Install The Seed Toolchain
    [Documentation]  This is a bit of a cheat at the moment. Install a pre-built
    ...  crosstools-ng toolchain which can be used to bootstrap the build
    ...  environment.
    ssh.Set Client Configuration  timeout=10m
    ${_c}=  catenate
    ...  ~/projects/mistify-test/testlib/scripts/scp-nostrict
    ...  ${MISTIFY_SEED_TOOLCHAIN_SCP}/${MISTIFY_SEED_TOOLCHAIN_FILE}
    ...  ~/downloads
    ${_v}=  Set Variable  ~/crosstool/variations
    ${_o}=  SSH Run And Get Output  ${_c}  _delay=10s
    Should Contain  ${_o}  100%
    SSH Run  cd ~
    ${_o}=  SSH Run And Get Output
    ...  git clone git@github.com:crosstool-ng/crosstool-ng.git crosstool
    ...  _delay=10s
    Should Contain  ${_o}  Cloning into
    SSH Run  mkdir ${_v}
    SSH Run  cd ${_v}
    ${_o}=  SSH Run And Get Output
    ...  tar xzf ~/downloads/${MISTIFY_SEED_TOOLCHAIN_FILE}
    Should Not Contain  ${_o}  Cannot open
    # This enables using the pre-built toolchain rather than attempting to
    # build it at this point.
    SSH Run  touch .${MISTIFY_SEED_TOOLCHAIN}-${MISTIFY_SEED_TOOLCHAIN_VERSION}-built
    SSH Run  cd ~
    ${_p}=  catenate  SEPARATOR=
    ...  ${_v}/
    ...  ${MISTIFY_SEEDTOOLCHAIN}-${MISTIFY_SEEDTOOLCHAIN_VERSION}/bin/
    ...  ${MISTIFY_SEEDTOOLCHAIN_PREFIX}-gcc
    SSH Run  export CC=${_p}
    ${_o}=  SSH Run And Get Output  \$CC --help
    Should Contain  ${o_}  Usage:  ${MISTIFY_SEEDTOOLCHAIN_PREFIX}-cc
    ${_p}=  catenate  SEPARATOR=
    ...  ${_v}/
    ...  ${MISTIFY_SEEDTOOLCHAIN}-${MISTIFY_SEEDTOOLCHAIN_VERSION}/bin/
    ...  ${MISTIFY_SEEDTOOLCHAIN_PREFIX}-g++
    SSH Run  export CXX=${_p}
    ssh.Set Client Configuration  timeout=3s

Install GNU Package
    [Documentation]  This installs a GNU package using autoconf.
    [Arguments]  ${_package}  ${_version}
    ...  ${_install}=install
    ...  ${_url}=http://ftp.gnu.org/gnu
    Log Message  \nInstalling ${_package}-${_version}
    ssh.Set Client Configuration  timeout=5m
    SSH Run  mkdir -p ~/tmp
    SSH Run  cd ~/tmp
    ${_i}=  SSH Run And Get Return Code
    ...  wget ${_url}/${_package}/${_package}-${_version}.tar.gz
    ...  _delay=10s
    Should Be Equal As Integers  ${_i}  ${0}
    SSH Run  tar xzf ${_package}-${_version}.tar.gz
    SSH Run  cd ${_package}-${_version}
    SSH Run  ./configure && make && sudo make ${_install}  _delay=15s
    ssh.Set Client Configuration  timeout=3s

Build The Go Compiler
    [Documentation]  The cross toolchain seed has been installed. Now can build
    ...  the go compiler.
    ...  NOTE: This will also cause a clone of the buildroot and go repositories
    ...  and the go repo is very large. Thus the long timeout.
    ssh.Set Client Configuration  timeout=25m
    SSH Run  cd ~/projects/mistify-os
    ${_c}=  catenate
    ...  ./buildmistify --toolchaindir ~/crosstool
    ...  --toolchainprefix ${MISTIFY_SEEDTOOLCHAIN_PREFIX} --dryrun
    ${_r}=  SSH Run And Get Return Code  ${_c}  _delay=10s
    Should Be Equal As Integers  ${_r}  ${0}
    ssh.Set Client Configuration  timeout=3s

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

