*** Settings ***
Documentation    This does some of the work for preparing a container for running
...  cluster related tests.
...
...	The test is executed using a container which was previously prepared
...	using the ProvisionTestContainer.robot script.
...
...	NOTE: This requires a build of Mistify-OS exists from which to obtain
...	the kernel and initrd images used for the test. Also, guest images
...	need to have been previously downloaded.
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
Resource	${TESTLIBDIR}/resources/mistify.robot
Resource	${TESTLIBDIR}/resources/ssh.robot
Resource	${TESTLIBDIR}/resources/lxc.robot

Suite Setup             Setup Testsuite
Suite Teardown          Teardown Testsuite

*** Variables ***
${httpserverdir}	http
${guestimagedir}	guest-images

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

Install Guest Image
    [Documentation]	If the guest image exists in the download directory
    ...			then copy it to the container which will make it
    ...			unnecessary to download the image there (next test).
    SSH Run  mkdir -p ${httpserverdir}/${guestimagedir}
    ${_s}  ${_o}=  Run Keyword And Ignore Error
    ...	ssh.Put File  ${DOWNLOADDIR}/${MISTIFY_GUEST_IMAGE}
    ...	${httpserverdir}/${guestimagedir}/
    Run Keyword If  '${_s}' == 'PASS'
    ...	Log Message  Image file ${MISTIFY_GUEST_IMAGE} copied to container.

Download Guest Image
    [Documentation]	Download a guest image to use with the test.
    ...
    ...  NOTE: The download occurs only if the file doesn't exist.
    SSH Run  cd ${httpserverdir}/${guestimagedir}
    ${_o}=  SSH Run And Get Output  pwd
    Log To Console  \nDownloading guest image from: \n${MISTIFY_GUEST_IMAGE_URL}/${MISTIFY_GUEST_IMAGE}
    Log To Console  \nDownloading guest image to: ${_o}
    ${_c}=  catenate  SEPARATOR=${SPACE}
    ...  if [ ! -f ${MISTIFY_GUEST_IMAGE} ]; then
    ...    wget ${MISTIFY_GUEST_IMAGE_URL}/${MISTIFY_GUEST_IMAGE};
    ...  else
    ...    echo "The guest image file exists.";
    ...  fi
    ssh.Set Client Configuration  timeout=20m
    ssh.Write  ${_c}
    ssh.Read Until  ${userprompt}
    ssh.Set Client Configuration  timeout=3s
    Log To Console  ${_o}
    SSH Run  cd ${homedir}
    ${_o}=  SSH Run And Get Output  ls ${httpserverdir}/${guestimagedir}
    Should Contain  ${_o}  ${MISTIFY_GUEST_IMAGE}

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
    ...	${TESTLIBDIR}/scripts/vm-network --bridge ${MISTIFY_BRIDGE}
    ...	--bridgeip ${MISTIFY_BRIDGE_IP}
    :FOR  ${_i}  IN  @{MISTIFY_CLUSTER_NODES}
    	\	${_o}=  SSH Run And Get Output  ${TESTLIBDIR}/scripts/vm-network --tap ${_i}
    	\	Log To Console  ${_o}
    	\	${_o}=  SSH Run And Get Output  ifconfig
    	\	Should Contain  ${_o}  ${_i}

Setup NAT For HTTP
    [Documentation]  Downloading guest images can be time consuming if from
    ...  the internet. To save time a HTTP server is run inside the container
    ...  and the port 80 accesses from the VMs are rerouted from the VMs to
    ...  the server running inside the container.
    # This is to avoid having to repond to a prompt regarding these files.
    SSH Run  echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
    SSH Run  echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
    ssh.Write  sudo apt-get install -y iptables-persistent
    ssh.Set Client Configuration  timeout=1m
    ssh.Read Until  ${userprompt}  loglevel=WARN

    ssh.Set Client Configuration  timeout=3s
    ${_o}=  SSH Run And Get Output  which iptables
    Should Contain  ${_o}  /iptables
    ${_c}=  catenate  SEPARATOR=${SPACE}
    ...	sudo iptables -t nat -I PREROUTING --src 0/0 --dst ${MISTIFY_BRIDGE_IP}
    ...	-p tcp --dport 80 -j REDIRECT --to-ports 8080
    SSH Run  ${_c}

Setup NAT For Guests
    [Documentation]  Guest images need to access the outside internet.
    ${_c}=  catenate  SEPARATOR=${SPACE}
    ...	sudo iptables -t nat -A POSTROUTING
    ...	-s ${MISTIFY_BRIDGE_SUBNET}0/24 !
    ...	-d ${MISTIFY_BRIDGE_SUBNET}0/24 -j MASQUERADE
    SSH Run  ${_c}

Start Guest Image Server
    [Documentation]	The http server is started to listen on port 8080.
    ...			NAT is used to redirect incoming port 80 requests to
    ...			port 8080.
    SSH Run  cd http
    SSH Run  screen -S http
    ${_o}=  SSH Run And Get Output  python -m SimpleHTTPServer 8080 &
    Should Contain  ${_o}  Serving HTTP on 0.0.0.0 port 8080
    Detach Screen

Start The Nodes
    [Documentation]	Starts each of the configured nodes in VMs.
    ...
    ...	This uses named screen sessions, one for each node. The session name
    ...	is the same as the interface name for the node.
    ssh.Set Client Configuration  timeout=4m
    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
      \  Log To Console  \nStarting node: ${_n}
      \  Start Screen Session  ${_n}
      \  SSH Run  cd ~
      \  ${_m}=  Get Substring  ${_n}  -1
      \  ${_c}=  catenate  SEPARATOR=${SPACE}
      \  ...  ${TESTLIBDIR}/scripts/start-vm
      \  ...  --diskimage ~/images/${_n}.img --tap ${_n}
      \  ...  --uuid `uuidgen`
      \  ...  --mac ${MISTIFY_DEFAULT_MAC}${_m}
      \  ssh.Write  ${_c}
      \  ssh.Read Until  random: nonblocking
      \  Detach Screen
    ssh.Set Client Configuration  timeout=3s

Login To VMs
    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
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

###### Disabled tests ######
Verify Current Build
    [Documentation]	Verify the Mistify-OS directory exists and a build has
    ...			completed.
    # [Tags]  update-lochness
    OperatingSystem.File Should Exist  ${MISTIFYOSDIR}/buildgopackage
    ...	msg=The Mistify-OS script "buildgopackage" does not exist at:\n${MISTIFYOSDIR}
    ${_c}=  catenate
    ...	ls -d ${BUILDDIR}/build/lochness-* \| grep -v ansible \| cut -d '-' -f 2
    ${_v}=  Run  ${_c}
    Log Message  Lochness version is: ${_v}
    Set Suite Variable  ${lochnessversion}  ${_v}
    Set Suite Variable  ${lochnesscmdpath}  ${BUILDDIR}/build/lochness-${lochnessversion}/cmd
    OperatingSystem.Directory Should Exist  ${lochnesscmdpath}
    ...	msg=The Lochness cmd directory does not exist at:\n${lochnesscmdpath}

Build The Lochness Admin Tools
    [Documentation]  Build the tools needed to administer a Mistify-OS cluster.
    ...	This uses the build in ${BUILDDIR} to determine the version.
    # [Tags]  update-lochness
    :FOR  ${_t}  IN  @{LOCHNESS_ADMIN_TOOLS}
      \  ${_c}=  catenate  SEPARATOR=${SPACE}
      \  ...  cd ${MISTIFYOSDIR} &&
      \  ...  ./buildgopackage
      \  ...  --gopackagedir  ${lochnesscmdpath}/${_t}
      \  ...  --gopackagename  ${_t}
      \  ${_rc}  ${_o}=  Run And Return Rc And Output  ${_c}
      \  Should Be Equal As Integers  ${_rc}  0
      \  Log To Console  ${_o}

Copy Admin Tools To Container
    [Documentation]	A couple of tools are needed in the container for
    ...			administering a cluster.
    :FOR  ${_t}  IN  @{LOCHNESS_ADMIN_TOOLS}
      \  ${_f}=  catenate
      \  ...  ${LOCHNESS_CMD_BIN_PATH}/${_t}/${_t}
      \  Log To Console  Copying ${_f} to container bin.
      \  ssh.Put File  ${_f}  bin/

