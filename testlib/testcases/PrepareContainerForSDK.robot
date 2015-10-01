*** Settings ***
Documentation    This prepares a container to run Mistify-OS in a single
...  VM to use Mistify-OS to build Mistify-OS.
...
...	The test is executed using a container which was previously prepared
...	using the ProvisionTestContainer.robot script.
...
...	NOTE: This requires a build of Mistify-OS exists from which to obtain
...	the kernel and initrd images used for the test.
...
...
...	The container is left running after being setup to run Mistify-OS
...	nodes. This is because the network configuration will no longer exist
...	after the container has been shutdown making it necessary to run this
...	script again.

Library		String
Library		OperatingSystem

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
${httpserverdir}	http
${toolchaindir}		toolchain

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

Install Seed Toolchain
    [Documentation]	If the toolchain tar file exists in the download directory
    ...			then copy it to the container which will make it
    ...			unnecessary to download the file there (next test).
    SSH Run  mkdir -p ${httpserverdir}/${toolchaindir}
    ${_s}  ${_o}=  Run Keyword And Ignore Error
    ...  ssh.Put File  ${DOWNLOADDIR}/${MISTIFY_SEEDTOOLCHAIN_FILE}
    ...    ${httpserverdir}/${toolchaindir}/
    Run Keyword If  '${_s}' == 'PASS'
    ...  Log Message  Image file ${MISTIFY_SEEDTOOLCHAIN_FILE} copied to container.

Download Toolchain
    [Documentation]	Download a prebuilt toolchain which was built using
    ...  crosstools-ng. This toolchain is used to build a toolchain inside
    ...  Mistify-OS which is then used to build Mistify-OS using a clone
    ...  of mistify-os from the mistifyio repository.
    ...
    ...  NOTE: The download occurs only if the file doesn't exist.
    SSH Run  cd ${httpserverdir}/${toolchaindir}
    ${_o}=  SSH Run And Get Output  pwd
    Log To Console  \nDownloading toolchain from:
    ...  ${MISTIFY_SEEDTOOLCHAIN_URL}/${MISTIFY_SEEDTOOLCHAIN_FILE}
    Log To Console  \nDownloading toolchain to: ${_o}
    ${_c}=  catenate  SEPARATOR=${SPACE}
    ...  if [ ! -f ${MISTIFY_SEEDTOOLCHAIN_FILE} ]; then
    ...    wget ${MISTIFY_SEEDTOOLCHAIN_URL}/${MISTIFY_SEEDTOOLCHAIN_FILE};
    ...  else
    ...    echo "The toolchain file exists.";
    ...  fi
    ssh.Set Client Configuration  timeout=20m
    ssh.Write  ${_c}
    ssh.Read Until  ${userprompt}
    ssh.Set Client Configuration  timeout=3s
    Log To Console  ${_o}
    SSH Run  cd ${homedir}
    ${_o}=  SSH Run And Get Output  ls ${httpserverdir}/${toolchaindir}
    Should Contain  ${_o}  ${MISTIFY_SEEDTOOLCHAIN_FILE}

Copy Mistify Images To Container
    Update Mistify Images

Copy Helper Scripts To Container
    ssh.Put File  scripts/*  scripts/
    ${_o}=  SSH Run And Get Output  ls scripts
    Should Contain  ${_o}  mistify-test-functions.sh
    ssh.Put File  ${TESTLIBDIR}/scripts/*  ${TESTLIBDIR}/scripts/
    ${_o}=  SSH Run And Get Output  ls ${TESTLIBDIR}/scripts
    Should Contain  ${_o}  start-vm
    Should Contain  ${_o}  vm-network

Configure Network For VMs
    [Documentation]	This creates the bridge and tunnel devices for running
    ...			Mistify-OS in containers. In addition, the dhcp server
    ...			is configured and started.
    ...
    ...  NOTE: This relies upon the user being configured for sudo and NOPASSWD.
    ...  NOTE: Up to three Mistify-OS nodes are supported.
    ${_c}=  catenate  SEPARATOR=${SPACE}
    ...	${TESTLIBDIR}/scripts/vm-network
    ...	--bridge ${MISTIFY_BRIDGE}
    ...	--bridgeip ${MISTIFY_BRIDGE_IP}
    ...	--nameserver ${MISTIFY_SDK_GATEWAY_IP}
    :FOR  ${_i}  IN  @{MISTIFY_SDK_NODES}
    	\	${_o}=  SSH Run And Get Output  ${TESTLIBDIR}/scripts/vm-network --tap ${_i}
    	\	Log To Console  ${_o}
    	\	${_o}=  SSH Run And Get Output  ifconfig
    	\	Should Contain  ${_o}  ${_i}

Install Iptables
    [Documentation]  The utility, iptables, is needed to configure NAT in order
    ...  to download packages.
    # This is to avoid having to repond to a prompt regarding these files.
    SSH Run  echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
    SSH Run  echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
    ssh.Write  sudo apt-get install -y iptables-persistent
    ssh.Set Client Configuration  timeout=1m
    ssh.Read Until  ${userprompt}  loglevel=WARN

    ssh.Set Client Configuration  timeout=3s
    ${_o}=  SSH Run And Get Output  which iptables
    Should Contain  ${_o}  /iptables

Setup NAT For SDKs
    [Documentation]  SDK images need to access the outside internet.
    ${_c}=  catenate  SEPARATOR=${SPACE}
    ...	sudo iptables -t nat -A POSTROUTING
    ...	-s ${MISTIFY_BRIDGE_SUBNET}0/24 !
    ...	-d ${MISTIFY_BRIDGE_SUBNET}0/24 -j MASQUERADE
    SSH Run  ${_c}

Start The Nodes
    [Documentation]	Starts each of the configured nodes in VMs.
    ...
    ...	This uses named screen sessions, one for each node. The session name
    ...	is the same as the interface name for the node.
    ssh.Set Client Configuration  timeout=4m
    :FOR  ${_n}  IN  @{MISTIFY_SDK_NODES}
      \  Log To Console  \nStarting node: ${_n}
      \  Start Screen Session  ${_n}
      \  SSH Run  cd ~
      \  ${_m}=  Get Substring  ${_n}  -1
      \  ${_c}=  catenate  SEPARATOR=${SPACE}
      \  ...  ${TESTLIBDIR}/scripts/start-vm
      \  ...  --diskimage ~/images/${_n}.img --tap ${_n}
      \  ...  --diskimagesize ${MISTIFY_SDK_IMAGE_SIZE}
      \  ...  --uuid `uuidgen`
      \  ...  --mac ${MISTIFY_DEFAULT_MAC}${_m}
      \  ...  --rammb ${MISTIFY_SDK_MEMORY}
      \  ssh.Write  ${_c}
      \  ssh.Read Until  random: nonblocking
      \  Detach Screen
    ssh.Set Client Configuration  timeout=3s

Login To VMs
    :FOR  ${_n}  IN  @{MISTIFY_SDK_NODES}
      \  Log To Console  \nLogin to node: ${_n}
      \  Attach Screen  ${_n}
      \  Login To Mistify
      \  Detach Screen

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

