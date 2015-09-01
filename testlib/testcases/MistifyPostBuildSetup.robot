*** Settings ***
Documentation	This script is designed to setup a test run for a newly completed
...		build.
...
...	If the command line parameter "SETUP" equals "reset" then
...	images are downloaded from the build server and	installed into
...	the test container to be booted by the nodes involved in the
...	test run. Otherwise previously installed images are used.
...
...	Command line options (passed by testmistify using '-- -v <OPTION>:<value>')
...	SETUP
...	  reset		Reset a node to initial states during testsuite setup

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

Suite Teardown	Stop Tests If Failed

*** Variables ***

*** Test Cases ***
Prepare For New Test Run
    Get Command Line Options
    Use Cluster Container

# The following is to record the container states for diagnostic purposes.
Setup Container Network
    [Documentation]  Run the network setup script. Some services may have
    ...  been shut down in a previous run. Make sure they've been restarted.
    SSH Run  ${TESTLIBDIR}/scripts/vm-network

The Cluster Bridge Exists And Has Expected IP Addresses
    [Documentation]  The cluster nodes communicate with each other via a bridge
    ...  in the container context. Verify the bridge exists.
    ${_o}=  SSH Run And Get Output  ip addr show dev ${MISTIFY_BRIDGE}
    Should Contain  ${_o}  ${MISTIFY_BRIDGE}
    Should Contain  ${_o}  ${MISTIFY_BRIDGE_IP}/${MISTIFY_NET_MASK_BITS}
    Should Contain  ${_o}  ${MISTIFY_CLUSTER_GATEWAY_IP}/${MISTIFY_CLUSTER_NET_MASK_BITS}

Node Interfaces Exist And Are Part Of Bridge
    [Documentation]  From the container perspective connection to each container
    ...  is via a TAP interface. These need to exist and be part of the cluster
    ...  brigdge before cluster verifications can be performed.
    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
      \  ${_o}=  SSH Run And Get Key Line  LINE:  ip addr show dev ${_n}
      \  Should Contain  ${_o}  ${MISTIFY_BRIDGE}

The DHCP Server Is Running
    [Documentation]  When beginning a series of tests nodes need a DHCP server
    ...  to be running in the container. This verifies the DHCP server is
    ...  running.
    ...
    ...  NOTE: Because a cluster will provide its own DHCP service this may
    ...  be shut down by some tests. This verifies the server has been
    ...  started or restarted before beginning a new series of tests.
    ${_o}=  SSH Run And Get Key Line  DHCP:  ps aux \| grep dhcpd
    Should Contain  ${_o}  testmistify/vm-network-dhcpd-pid

The HTTP Server Is Running To Serve Guest Images
    [Documentation]  Nodes require an http server for downloading and installing
    ...  guest images. To save download time and to isolate nodes a http server
    ...  runs in the container environment. This vereifies the http server is
    ...  running.
    ${_o}=  SSH Run And Get Key Line  HTTP:  ps aux \| grep Simple
    Should Contain  ${_o}  SimpleHTTPServer

The Screen Sessions Exist And Are Detached
    [Documentation]  Many of the test cases rely upon having a screen session
    ...  for each node. This verifies the screen sessions exist and are
    ...  detached.
    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
      \  ${_o}=  SSH Run And Get Key Line  LINE:  screen -ls ${_n} \| grep ${_n}
      \  Should Contain  ${_o}  Detached

Install New Images
    [Documentation]  Copy new images to the container for testing.
    Update Mistify Images

Restart Nodes Using New Images
    [Documentation]  This restarts the node VMs so they are booted using the
    ...  new images. This is necessary in order to ensure everything is reset
    ...  to the Mistify-OS defaults for an initial boot.
    # Test cases assume already logged into the nodes.
    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
      \  Reset Node  ${_n}  clean
      \  Use Node  ${_n}
      \  Login To Mistify
      \  Release Node

Recollect Node Attributes
    [Documentation]  Collect the node attributes for use by the other tests.
    ...  The node attributes are recaptured at this point in case they have
    ...  changed since initially captured during initial setup.
    ...
    ...  NOTE: Since "Collect Attributes" creates a global scope variable
    ...  (Nodes) any test suites following this one will be able to access
    ...  the already collected atributes for each of the test nodes.
    Collect Attributes

Generate The Node Attribute List
    [Documentation]	Using the Nodes variable a shell script is generated
    ...			containing variables needed by the cluster-init
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
    ...  \# nodes.sh: Generated by: ${SUITE NAME}
    ...  \n\# This is designed to be copied to cluster-init-config
    ...  \n\# which is used by cluster-init.\n
    ...  \nnm=${MISTIFY_CLUSTER_NET_MASK_BITS}
    ...  \ngw=${MISTIFY_CLUSTER_GATEWAY_IP}\n
    ...  \n${_iflist} ${_uuidlist} ${_iplist} ${_maclist} ${_clusteriplist}\n
    ...  \nETCD_HEARTBEAT_INTERVAL=${ETCD_HEARTBEAT_INTERVAL}
    ...  \nETCD_ELECTION_TIMEOUT=${ETCD_ELECTION_TIMEOUT}

    # copy in the container.
    ${_of}=  catenate
    ...  mkdir -p tmp; cat >tmp/${MISTIFY_NODES_CONFIG_FILE} << EOF\n
    ...  ${NodesScript}
    ...  \nEOF
    SSH Run  ${_of}
    Set Suite Variable  ${NodesScript}

Install Node Attribute List On The Primary Node
    Use Node  @{MISTIFY_CLUSTER_NODES}[0]
    ${_of}=  catenate
    ...  cat >/root/${MISTIFY_NODES_CONFIG_FILE} << EOF\n
    ...  ${NodesScript}
    ...  \nEOF
    SSH Run  ${_of}
    Release Node

Install Json Parser On The Primary Node
    ${_o}=  Run Command On Node  @{MISTIFY_CLUSTER_NODES}[0]
    ...  mkdir -p ${MISTIFY_USER_HOME}/${MISTIFY_TEST_SCRIPTS_DIR}
    Copy File To Node  @{MISTIFY_CLUSTER_NODES}[0]
    ...  ${TESTLIBDIR}/scripts/${MISTIFY_JSON_PARSER}
    ...  ${MISTIFY_USER_HOME}/${MISTIFY_TEST_SCRIPTS_DIR}
    ${_o}=  Run Command On Node  @{MISTIFY_CLUSTER_NODES}[0]
    ...  ls ${MISTIFY_USER_HOME}/${MISTIFY_TEST_SCRIPTS_DIR}
    ${_o}=  Should Contain  ${_o}  ${MISTIFY_JSON_PARSER}

*** Keywords ***
Stop Tests If Failed
    Release Cluster Container
    Run Keyword If Any Tests Failed  Fatal Error
    ...  Container is not configured properly. Stopping test execution.
