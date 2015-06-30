*** Settings ***
Documentation   This uses the collected node attributes to generate a node list
...		which is then copied to the the first node.
...
...	This leaves with the container still running and the node VMs running
...	in the context of the container.
...
...	Scripts were generated in ~/tmp for starting nodes with the same
...	attributes.
...	The disk images following the initial boot are saved so that states can
...	be restored simply by copying the node initial disk image to the node
...	running disk image.

Library		String
Library		Collections

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
${guestimagedir}	guest-images
${clusterinitscript}	mistify-cluster-init

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

Generate The Node Attribute List
    [Documentation]	Using the Nodes variable a shell script is generated
    ...			containing variables needed by the cluster-init.sh
    ...			script.
    ${_iflist}=  catenate  \nifs=(
    ${_uuidlist}=  catenate  \nuuids=(
    ${_iplist}=  catenate  \ninitialips=(
    ${_maclist}=  catenate  \nmacs=(
    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
    \  ${_a}=  Get From Dictionary  ${Nodes}  ${_n}
    \  ${_uuid}=  Get From Dictionary  ${_a}  uuid
    \  ${_if}=  Get From Dictionary  ${_a}  if
    \  ${_ip}=  Get From Dictionary  ${_a}  ip
    \  ${_mac}=  Get From Dictionary  ${_a}  mac
    \  Log To Console  \nNode ${_n}
    \  Log To Console  uuid: ${_uuid}
    \  Log To Console  network interface: ${_if}
    \  Log To Console  ip: ${_ip}
    \  Log To Console  mac: ${_mac}
    \  ${_iflist}=  catenate  ${_iflist}  \n'${_if}'
    \  ${_uuidlist}=  catenate  ${_uuidlist}  \n'${_uuid}'
    \  ${_iplist}=  catenate  ${_iplist}  \n'${_ip}'
    \  ${_maclist}=  catenate  ${_maclist}  \n'${_mac}'
    ${_clusteriplist}=  catenate  \nips=( ${MISTIFY_CLUSTER_IP_LIST} \n)\n
    ${_iflist}=  catenate  ${_iflist}  \n)\n
    ${_uuidlist}=  catenate  ${_uuidlist}  \n)\n
    ${_iplist}=  catenate  ${_iplist}  \n)\n
    ${_maclist}=  catenate  ${_maclist}  \n)\n
    Log To Console  ${_uuidlist} ${_iplist} ${_maclist} ${_clusteriplist}
    ${NodesScript}=  catenate
    ...  \# nodes.sh: Generated by: ClusterInitialization.robot\n
    ...  \ngw=${MISTIFY_CLUSTER_GATEWAY_IP}\n
    ...  \n${_iflist} ${_uuidlist} ${_iplist} ${_maclist} ${_clusteriplist}
    # local copy
    Create File  tmp/nodes.sh  ${NodesScript}
    # copy in the container.
    ${_of}=  catenate
    ...  mkdir -p tmp; cat >tmp/nodes.sh << EOF\n
    ...  ${NodesScript}
    ...  \nEOF
    SSH Run  ${_of}
    Set Suite Variable  ${NodesScript}

Install Node Attribute List On The Primary Node
    Attach Screen  @{MISTIFY_CLUSTER_NODES}[0]
    ${_of}=  catenate
    ...  cat >/root/nodes.sh << EOF\n
    ...  ${NodesScript}
    ...  \nEOF
    SSH Run  ${_of}
    Detach Screen

Install Cluster Init Script On The Primary Node
    Copy File To Node  @{MISTIFY_CLUSTER_NODES}[0]
    ...  ${TESTLIBDIR}/scripts/${clusterinitscript}  ${MISTIFY_USER_HOME}
    ${_o}=  Run Command On Node  @{MISTIFY_CLUSTER_NODES}[0]  ls
    ${_o}=  Should Contain  ${_o}  ${clusterinitscript}

Restart Nodes
    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
    \  ${_a}=  Get From Dictionary  ${Nodes}  ${_n}
    \  ${_uuid}=  Get From Dictionary  ${_a}  uuid
    \  ${_mac}=  Get From Dictionary  ${_a}  mac
    \  Restart Node With New MAC Address  ${_n}  ${_uuid}  ${_mac}

Login To VMs
    [Documentation]	The VMs have been restarted. Log back into them.

    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
    \  Attach Screen  ${_n}
    \  Login To Mistify
    \  Detach Screen

Add IP Address To Bridge
    [Documentation]	The cluster runs using a set of IP addresses which are
    ...			currently hardcoded to 192.168 and the gateway is
    ...			assumed to be 192.168.0.1. Add this IP address to the
    ...			bridge used for the VMs.
    ${_c}=  catenate
    ...	sudo ip addr
    ...	add ${MISTIFY_CLUSTER_GATEWAY_IP}/${MISTIFY_NET_MASK_BITS}
    ...	dev ${MISTIFY_BRIDGE}
    ${_o}=  SSH Run And Get Output  ${_c}
    Should Not Contain  ${_o}  Cannot find
    Should Not Contain  ${_o}  Error:
    ${_o}=  SSH Run And Get Output  ip addr show dev ${MISTIFY_BRIDGE}
    Log To Console  \nBridge configuration:\n${_o}

*** Keywords ***
#### disabled keywords
Shutdown The Container DHCP Server
    [Documentation]	The nodes provide dhcp services from this point
    ...			on so shut down the dhcp server running in the
    ...			container.
    ${_o}=  SSH Run And Get Output  ${TESTLIBDIR}/scripts/vm-network --shutdowndhcpd
    Should Contain  ${_o}  The dhcp server is not running

Run Cluster Initialization
    Attach Screen  @{MISTIFY_CLUSTER_NODES}[0]
    ssh.Set Client Configuration  timeout=10m
    ssh.Write  ./${clusterinitscript}
    ${_o}=  ssh.Read Until  ok you can now boot node1 and node2
    Detach Screen
    Reboot Node  @{MISTIFY_CLUSTER_NODES}[1]
    Reboot Node  @{MISTIFY_CLUSTER_NODES}[2]

Verify Cluster Init Is Complete
    Attach Screen  @{MISTIFY_CLUSTER_NODES}[0]
    ${_o}=  ssh.Read Until  Cluster initialization is complete


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

Restart Node With New MAC Address
    [Documentation]	This is a workaround because the current version of
    ...			the Mistify demo where the VM ethernet MAC address
    ...			needs to be the same as the computed br0 MAC
    ...			address for inter-node dhcp to work.
    ...
    ...  No two devices in a network should have the same MAC address but
    ...  because of the way the pre-init works versus using bridges the MAC
    ...  address needed by cluster init has to be the same as the ethernet
    ...  MAC address. This is a workaround for that problem where the VM for
    ...  a node is restarted with the bridge's MAC.
    [Arguments]  ${_n}  ${_uuid}  ${_mac}
    Attach Screen  ${_n}
    # Be sure the disk image is updated.
    ${_o}=  Run Command On Node  @{MISTIFY_CLUSTER_NODES}[0]  sync
    Exit VM In Screen
    ssh.Set Client Configuration  timeout=15s
    ssh.Read Until  QEMU: Terminated
    ${_c}=  catenate  SEPARATOR=${SPACE}
    ...  ${TESTLIBDIR}/scripts/start-vm
    ...  --diskimage ~/images/${_n}.img --tap ${_n}
    ...  --uuid ${_uuid}
    ...  --mac ${_mac}
    Log To Console  Generating node start script for node: ${_n}
    ssh.Write  mkdir -p ~/tmp; echo ${_c} >~/tmp/start-${_n}
    ssh.Write  chmod +x ~/tmp/start-${_n}
    Log To Console  Saving initial disk image for node: ${_n}
    ssh.Write  cp ~/images/${_n}.img ~/images/${_n}.img.initial
    Log To Console  Restarting VM: ${_c}
    ssh.Write  ${_c}
    ssh.Set Client Configuration  timeout=4m
    ssh.Read Until  nonblocking pool is initialized
    ssh.Set Client Configuration  timeout=3s
    Detach Screen

