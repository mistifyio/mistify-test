*** Settings ***
Documentation	Common definitions and keywords for tesing Mistify-OS.
...
...	This contains variables and keywords common to all Mistify-OS
...	builds. It also brings in the test bed specific information so
...	that test suites need not repeat those lines.

#+
# NOTE: The variable TESTLIBDIR is passed from the command line by the testmistify
# script. There is no default value for this variable.
#-
Resource	${TESTLIBDIR}/resources/helpers.robot
Resource	${TESTLIBDIR}/resources/mistify-helpers.robot

#+
# NOTE: The variable TESTBED is passed from the command line by the testmistify
# script. There is no default value for this variable.
#-
Resource	${TESTBED}

#+
# NOTE: The variable TESTDISTRO is passed from the command line by the testmistify
# script. There is no default value for this variable.
#-
Resource	${TESTDISTRO}

*** Variables ***
# For login to a running instance of Mistify-OS
${MISTIFY_USERNAME}	root
${MISTIFY_PASSWORD}	LetMeIn2
${MISTIFY_USER_HOME}	/root

# Mistify-OS when running on hardware uses a UUID as part of the prompt.
${MISTIFY_PROMPT}	${MISTIFY_USERNAME}@
# When running in a development machine in a VM the prompt is localhost.
${MISTIFY_VM_PROMPT}	root@localhost

${MISTIFY_GREETING}	Welcome to Mistify-OS
${MISTIFY_LOGIN_PROMPT}	login:

# To clone the Mistify-OS repo for building.
${MISTIFY_OS_REPO}	mistify-os
${MISTIFY_GIT_URL}	git@github.com:mistifyio/${MISTIFY_OS_REPO}.git
${MISTIFY_CLONE_DIR}	${MISTIFY_OS_REPO}

# To build the Lochness admin tools.
${LOCHNESS_VERSION}	20150424
${LOCHNESS_CMD_PATH}	${BUILDDIR}/build/lochness-${LOCHNESS_VERSION}/cmd
${LOCHNESS_CMD_BIN_PATH}  ${BUILDDIR}/tmp/GOPATH/src/github.com/mistifyio/
@{LOCHNESS_ADMIN_TOOLS}	hv  guest

# For testing Mistify-OS.
${MISTIFY_TEST_SCRIPTS_DIR}  testlib/scripts
${MISTIFY_GUEST_IMAGE}	ubuntu-14.04-server-mistify-amd64-disk1.zfs.gz
${MISTIFY_GUEST_IMAGE_URL}	http://builds.mistify.io/guest-images

${MISTIFY_KERNEL_IMAGE}	bzImage.mistify
${MISTIFY_INITRD_IMAGE}	initrd.mistify

${MISTIFY_BRIDGE}	mosbr0
${MISTIFY_BRIDGE_SUBNET}  10.0.2.
${MISTIFY_BRIDGE_IP}	${MISTIFY_BRIDGE_SUBNET}2
${MISTIFY_NET_MASK_BITS}	24

${MISTIFY_DEFAULT_MAC}	de:ad:be:ef:02:0	# Last digit is appended when
						# the VM is started.
${MISTIFY_VM_ETH_INTERFACE}	enp0s3

### Testing a Cluster Running in VMs ###
# Cluster nodes  -- NOTE: These need to end with an hex digit because they are
# also used to construct MAC addresses.
@{MISTIFY_CLUSTER_NODES}	node0  node1
${MISTIFY_CLUSTER_NODE_BRIDGE}	br0
${MISTIFY_CLUSTER_SUBNET}	192.168.200
${MISTIFY_CLUSTER_GATEWAY_IP}	${MISTIFY_CLUSTER_SUBNET}.1
${MISTIFY_CLUSTER_PRIMARY_IP}	${MISTIFY_CLUSTER_SUBNET}.200
${MISTIFY_CLUSTER_IP_LIST}	\n'${MISTIFY_CLUSTER_SUBNET}.200'\n'${MISTIFY_CLUSTER_SUBNET}.201'\n'${MISTIFY_CLUSTER_SUBNET}.202'
${MISTIFY_CLUSTER_NET_MASK_BITS}  24

# Options for running the cluster-init script.
${ETCD_HEARTBEAT_INTERVAL}	1000
${ETCD_ELECTION_TIMEOUT}	10000

# Helpers
${MISTIFY_NODES_CONFIG_FILE}	nodes-config
${MISTIFY_JSON_PARSER}		parsejson

### Using Mistify-OS to Build Mistify-OS ###
${MISTIFY_SEEDTOOLCHAIN}	crosstool-ng-1.21.0.tgz
${MISTIFY_SEEDTOOLCHAIN_URL}	http://builds.mistify.io/guest-images
@{MISTIFY_SDK_NODES}		sdk0
${MISTIFY_SDK_SUBNET}		10.0.2
${MISTIFY_SDK_GATEWAY_SUBNET}	10.0.3
${MISTIFY_SDK_CONTAINER_IP}	${MISTIFY_SDK_SUBNET}.2
${MISTIFY_SDK_GATEWAY_IP}	${MISTIFY_SDK_GATEWAY_SUBNET}.1
${MISTIFY_SDK_PRIMARY_IP}	${MISTIFY_SDK_SUBNET}.100
${MISTIFY_SDK_NET_MASK_BITS}	24
# To build Mistify-OS a really large disk is needed. This is enough to build
# one variation.
${MISTIFY_SDK_IMAGE_SIZE}	25G

# In Mistify-OS the typical user IDs in the range 1000 are already taken.
# This makes it impossible to match IDs. So use an arbitrary ID.
${MISTIFY_SDK_USER_ID}		2000


