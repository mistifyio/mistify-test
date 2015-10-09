*** Settings ***
Documentation           Mistify cluster related helper keywords.
...
...	This assumes the cluster has been previously initialized using
...	ClusterInitialization.robot. All of the nodes have been created and
...	have been started with their startup scripts in ~/tmp and disk images
...	in ~/images. Also this is assumed to be running in the context of an
...	lxc container and one screen session per node is available.
...	NOTE: Some of the features provided by this script depend upon the
...	helpers.robot resource.

Library	String
Library	Collections

*** Variables ***

*** Keywords ***
Collect SDK Attributes
    [Documentation]	This collects the attributes of each of the running
    ...			nodes and makes them available in a global collection.
    ...
    ...  NOTE: This requires different screen sessions for each of the nodes and
    ...  each session is named after the node.
    ...
    ...  This creates a collection of collections. The top collection is used
    ...  to access the individual node attributes and is keyed by node name.
    ${Nodes}=	Create Dictionary  node  dictionary
    :FOR  ${_n}  IN  @{MISTIFY_SDK_NODES}
      \  Attach Screen  ${_n}
      \  Log To Console  \nCollecting attributes for node: ${_n}
      \  ${_if}=  Learn Test Interface
      \  Log To Console  \nNode ${_n} interface: ${_if}
      \  ${_ip}=  Learn IP Address  ${_if}
      \  Log To Console  \nNode ${_n} IP address: ${_ip}
      \  ${_mac}=  Learn MAC Address  ${_if}
      \  Log To Console  \nNode ${_n} MAC address: ${_mac}
      \  ${_uuid}=  Learn UUID
      \  Log To Console  \nNode ${_n} UUID: ${_uuid}
      \  ${_a}=  Create Dictionary  uuid  ${_uuid}  if  ${_if}  ip  ${_ip}  mac  ${_mac}
      \  Set To Dictionary  ${Nodes}  ${_n}  ${_a}
      \  Detach Screen
    Log Dictionary  ${Nodes}
    Set Global Variable  ${Nodes}

Collect Attributes
    [Documentation]	This collects the attributes of each of the running
    ...			nodes and makes them available in a global collection.
    ...
    ...  NOTE: This requires different screen sessions for each of the nodes and
    ...  each session is named after the node.
    ...
    ...  This creates a collection of collections. The top collection is used
    ...  to access the individual node attributes and is keyed by node name.
    ${Nodes}=	Create Dictionary  node  dictionary
    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
      \  Attach Screen  ${_n}
      \  Log To Console  \nCollecting attributes for node: ${_n}
      \  ${_if}=  Learn Test Interface
      \  Log To Console  \nNode ${_n} interface: ${_if}
      \  ${_ip}=  Learn IP Address  ${_if}
      \  Log To Console  \nNode ${_n} IP address: ${_ip}
      \  ${_mac}=  Learn MAC Address  ${_if}
      \  Log To Console  \nNode ${_n} MAC address: ${_mac}
      \  ${_uuid}=  Learn UUID
      \  Log To Console  \nNode ${_n} UUID: ${_uuid}
      \  ${_a}=  Create Dictionary  uuid  ${_uuid}  if  ${_if}  ip  ${_ip}  mac  ${_mac}
      \  Set To Dictionary  ${Nodes}  ${_n}  ${_a}
      \  Detach Screen
    Log Dictionary  ${Nodes}
    Set Global Variable  ${Nodes}

Get Node IP Address
    [Documentation]	Returns a node's IP address from the Nodes attribute
    ...			collection.
    [Arguments]	${_node}
    ${_a}=  Get From Dictionary  ${Nodes}  ${_node}
    ${_r}=  Get From Dictionary  ${_a}  ip
    [Return]  ${_r}

Get Node UUID
    [Documentation]	Returns a node's UUID from the Nodes attribute
    ...			collection.
    [Arguments]	${_node}
    ${_a}=  Get From Dictionary  ${Nodes}  ${_node}
    ${_r}=  Get From Dictionary  ${_a}  uuid
    [Return]  ${_r}

SSH To Node
    [Documentation]	This logs into a node using ssh.
    ...
    ...	NOTE: This uses the configured mistify user (typically root).
    ...	NOTE: This uses the running ssh session to run ssh to login to the
    ...	node and therefore does not require switching ssh sessions.
    [Arguments]	${_node}
    ${_ip}=  Get Node IP Address  ${_node}
    ${_uuid}=  Get Node UUID  ${_node}
    ${_c}=  catenate
    ...  sshpass -p ${MISTIFY_PASSWORD}
    ...  ssh ${ssh_options}
    ...  ${MISTIFY_USERNAME}@${_ip}
    ${_o}=  SSH Run And Get Output  ${_c}
    Should Contain  ${_o}  ${MISTIFY_USERNAME}@${_uuid}
    Should Not Contain  ${_o}  Permission denied

Logout From Node
    [Documentation]  Pretty simple. Provided for symmetry.
    ${_o}=  SSH Run And Get Output  \nexit
    Should Contain  ${_o}  logout

Copy File To Node
    [Documentation]  Copy a file to a node using scp.
    ...	NOTE: This uses the configured mistify user (typically root).
    [Arguments]  ${_node}  ${_source}  ${_destination}
    ${_ip}=  Get Node IP Address  ${_node}
    ${_c}=  catenate
    ...  sshpass -p ${MISTIFY_PASSWORD}
    ...  scp ${ssh_options}
    ...  ${_source}  ${MISTIFY_USERNAME}@${_ip}:${_destination}
    Log To Console  \nRunning: ${_c}
    ${_o}=  SSH Run And Get Output  ${_c}
    Should Not Contain  ${_o}  No such file or directory
    Should Not Contain  ${_o}  Is a directory
    Should Not Contain  ${_o}  Permission denied

Run Command On Node
    [Documentation]	This uses ssh to run a command on the node and then
    ...			return the output.
    ...	NOTE: This uses the configured mistify user (typically root).
    [Arguments]	${_node}  ${_command}
    ${_ip}=  Get Node IP Address  ${_node}
    ${_c}=  catenate
    ...  sshpass -p ${MISTIFY_PASSWORD}
    ...  ssh ${ssh_options}
    ...  ${MISTIFY_USERNAME}@${_ip} ${_command}
    Log To Console  \nRunning: ${_c}
    ${_o}=  SSH Run And Get Output  ${_c}
    Log To Console  Result: ${_o}
    Should Not Contain  ${_o}  Permission denied
    [Return]  ${_o}

SSH As User To Node
    [Documentation]	This logs into a node as a non-mistify user using ssh.
    ...
    ...	NOTE: The user needs to be setup for no password login. This can be
    ...	either a null password or using preshared keys.
    ...	NOTE: This uses the running ssh session to run ssh to login to the
    ...	node and therefore does not require switching ssh sessions.
    [Arguments]	${_user}  ${_node}
    ${_ip}=  Get Node IP Address  ${_node}
    ${_uuid}=  Get Node UUID  ${_node}
    ${_c}=  catenate
    ...  ssh ${ssh_options}
    ...  ${_user}@${_ip}
    ${_o}=  SSH Run And Get Output  ${_c}
    Should Contain  ${_o}  ${_user}@${_uuid}
    Should Not Contain  ${_o}  Permission denied

Copy File As User To Node
    [Documentation]  Copy a file as a non-mistify user to a node using scp.
    ...	NOTE: The user needs to be setup for no password login. This can be
    ...	either a null password or using preshared keys.
    [Arguments]  ${_user}  ${_node}  ${_source}  ${_destination}
    ${_ip}=  Get Node IP Address  ${_node}
    ${_c}=  catenate
    ...  scp ${ssh_options}
    ...  ${_source}  ${_user}@${_ip}:${_destination}
    Log To Console  \nRunning: ${_c}
    ${_o}=  SSH Run And Get Output  ${_c}
    Should Not Contain  ${_o}  No such file or directory
    Should Not Contain  ${_o}  Is a directory
    Should Not Contain  ${_o}  Permission denied

Copy Directory As User To Node
    [Documentation]  Copy a directory as a non-mistify user to a node using scp.
    ...	NOTE: The user needs to be setup for no password login. This can be
    ...	either a null password or using preshared keys.
    [Arguments]  ${_user}  ${_node}  ${_source}  ${_destination}
    ${_ip}=  Get Node IP Address  ${_node}
    ${_c}=  catenate
    ...  scp ${ssh_options} -r
    ...  ${_source}  ${_user}@${_ip}:${_destination}
    Log To Console  \nRunning: ${_c}
    ${_o}=  SSH Run And Get Output  ${_c}
    Should Not Contain  ${_o}  No such file or directory
    Should Not Contain  ${_o}  Is a directory
    Should Not Contain  ${_o}  Permission denied

Run Command As User On Node
    [Documentation]	This uses ssh to run a command as a non-mistify user on
    ...  the node and then return the output.
    ...	NOTE: The user needs to be setup for no password login. This can be
    ...	either a null password or using preshared keys.
    [Arguments]	${_user}  ${_node}  ${_command}
    ${_ip}=  Get Node IP Address  ${_node}
    ${_c}=  catenate
    ...  ssh ${ssh_options}
    ...  ${_user}@${_ip} ${_command}
    Log To Console  \nRunning: ${_c}
    ${_o}=  SSH Run And Get Output  ${_c}
    Log To Console  Result: ${_o}
    Should Not Contain  ${_o}  Permission denied
    [Return]  ${_o}

Reboot Node
    [Documentation]	Reboot a node. It's assumed already logged in.
    ...	This waits until the node has booted.
    [Arguments]  ${_node}
    Log To Console  Rebooting node: ${_node}
    Attach Screen  ${_node}
    ssh.Write  reboot
    ssh.Set Client Configuration  timeout=4m
    ${_o}=  ssh.Read Until  random: nonblocking
    ssh.Set Client Configuration  timeout=3s

    Detach Screen
    [Return]  ${_o}

Shutdown Node
    [Documentation]	Shutdown a node's VM and wait for it to shutdown.
    ...	This waits until the node has booted.

    [Arguments]  ${_node}

    Log To Console  Shutting down VM for node: ${_node}
    Attach Screen  ${_node}
    Exit VM In Screen
    ssh.Set Client Configuration  timeout=15s
    ssh.Read Until  QEMU: Terminated
    ssh.Set Client Configuration  timeout=3s
    Detach Screen

Start Node
    [Documentation]	Start a node's VM by running the the node's start script
    ...			created by ClusterInitialization.robot.
    ...	This waits until the node has booted.

    [Arguments]  ${_node}
    Log To Console  Starting VM for node: ${_node}
    Attach Screen  ${_node}

    ssh.Write  ~/tmp/start-${_node}
    Log To Console  \nWaiting for node ${_node} to boot.
    # This is emitted some time after a boot (typically 30 to 40 seconds)
    # Wait until this occurs to avoid having it mess up normal output.
    ssh.Set Client Configuration  timeout=4m
    ${_o}=  ssh.Read Until  random: nonblocking
    ssh.Set Client Configuration  timeout=3s
    ${_o}=  SSH Run And Get Output  \r
    Should Contain  ${_o}  ${MISTIFY_GREETING}
    Should Contain  ${_o}  login:
    Detach Screen
    [Return]  ${_o}

Restart Node
    [Documentation]	Restart a node by shutting down the node's VM and
    ...			restart the VM using the node's startup script created
    ...			by ClusterInitialization.robot.
    ...	This waits until the node has booted.

    [Arguments]  ${_node}

    Log To Console  Restarting VM for node: ${_node}
    Shutdown Node  ${_node}
    ${_o}=  Start Node  ${_node}
    [Return]  ${_o}

Restart Node With New MAC Address
    [Documentation]  This restarts a node and saves the disk image as the
    ...  initial disk image and is intended to be used once after a node
    ...  has been brought to a desired state. This helps return a node to
    ...  the known state at a later time.
    [Arguments]  ${_node}  ${_uuid}  ${_mac}  ${_ramdisksize}=200000
    # Be sure the disk image is updated.
    Use Node  ${_node}
    ssh.Set Client Configuration  timeout=5s
    SSH Run  sync; echo "File System sync'd"
    Exit VM In Screen
    ssh.Set Client Configuration  timeout=15s
    ssh.Read Until  QEMU: Terminated
    # Generate a quick start script for the node.
    ${_c}=  catenate  SEPARATOR=${SPACE}
    ...  ${TESTLIBDIR}/scripts/start-vm
    ...  --diskimage ~/images/${_node}.img --tap ${_node}
    ...  --uuid ${_uuid}
    ...  --mac ${_mac}
    ...  --ramdisksize ${_ramdisksize}
    Log To Console  Generating node start script for node: ${_node}
    ssh.Write  mkdir -p ~/tmp; echo ${_c} >~/tmp/start-${_node}
    ssh.Write  chmod +x ~/tmp/start-${_node}
    Log To Console  Saving initial disk image for node: ${_node}
    ssh.Write  cp ~/images/${_node}.img ~/images/${_n}.img.initial
    Log To Console  Restarting VM: ${_c}
    ssh.Write  ${_c}
    ssh.Set Client Configuration  timeout=4m
    ssh.Read Until  random: nonblocking
    ssh.Set Client Configuration  timeout=3s
    Release Node

Reset Node
    [Documentation]  Reset a node by shutting down the node's VM and
    ...  restart the VM using the node's either a new disk image
    ...  initial disk image or a new disk image and the startup script created
    ...  by ClusterInitialization.robot.
    ...  The argument "_diskimage" controls which disk image is used.
    ...    same (default)  Uses the same disk image.
    ...    clean           Uses a new disk image.
    ...    initial         Uses the disk image from when the node was first
    ...                    started.
    ...  This waits until the node has booted.

    [Arguments]  ${_node}  ${_diskimage}=same

    Log Message  Resetting VM for node: ${_node}
    Shutdown Node  ${_node}
    Log Message  Using ${_diskimage} disk image.
    Run Keyword If  '${_diskimage}'=='clean'  ssh.Write  rm ~/images/${_node}.img
    Run Keyword If  '${_diskimage}'=='initial'  ssh.Write  cp ~/images/${_node}.img.initial ~/images/${_node}.img
    ${_o}=  Start Node  ${_node}
    [Return]  ${_o}

Reset All Nodes
    [Documentation]	This resets all nodes to their initial states.
    ...
    ...	NOTE: This can take some time because each node is completely reset
    ...	before the next node is reset.

    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
      \  Reset Node  ${_n}

Enable Routing To External Network For Nodes
    [Documentation]	For nodes to access the internet some routing/masquerading
    ...			is needed.
    ...  NOTE: This is not currently being used but is intended to document part
    ...  of what needs to be done.

    ${_c}=  catenate
    ...  sudo iptables -t nat -A POSTROUTING
    ...  -s ${MISTIFY_BRIDGE_SUBNET}.0/${MISTIFY_NET_MASK_BITS}
    ...  -o ${LXC_CONTAINER_DEFAULT_INTERFACE} -j MASQUERADE
    ${_o}=  SSH Run And Get Output  ${_c}

Disable Routing To External Network For Nodes
    [Documentation]	This disables the routing to the internet for nodes.
    ...  NOTE: This is not currently being used but is intended to document part
    ...  of what needs to be done.

    ${_c}=  catenate
    ...  sudo iptables -t nat -D POSTROUTING
    ...  -s ${MISTIFY_BRIDGE_SUBNET}.0/${MISTIFY_NET_MASK_BITS}
    ...  -o ${LXC_CONTAINER_DEFAULT_INTERFACE} -j MASQUERADE
    ${_o}=  SSH Run And Get Output  ${_c}

Get Cluster Container IP Address
    [Documentation]  Returns the IP address of the named container to be used
    ...  as the testbed.
    Log To Console	\n
    ${_o}=	Container IP Address	${containername}
    Log To Console	\nContainer IP address: ${_o}
    Should Contain X Times	${_o}  \.  3
    Set Suite Variable	${ip}  ${_o}
    Log To Console	\nContainer IP address is: ${ip}

Login To Cluster Container
    [Documentation]  Logs in to the cluster container as the user running the
    ...  test.
    ...
    ...  NOTE: This requires the container was created by the same user.

    Log To Console  \nLogging in as ${USER} to container at IP: ${ip}
    Login to SUT  ${ip}  ${USER}  ${USER}
    ${_o}=  SSH Run And Get Output  pwd
    ${homedir}=  Get Line  ${_o}  0
    Should Contain  ${homedir}  /home/${USER}
    Set Suite Variable  ${homedir}
    Log To Console  Home directory is: ${homedir}

Use Cluster Container
    [Documentation]  This verifies a container of the correct name is running and
    ...  logs into the container if so.
    ${containername}=	Container Name
    Set Suite Variable  ${containername}
    Set Suite Variable  ${rootprompt}  root\@${containername}
    Set Suite Variable  ${userprompt}  ${USER}\@${containername}
    Log To Console  containername = ${containername}
    Log To Console  rootprompt = ${rootprompt}
    Log To Console  userprompt = ${userprompt}
    ${_rc}=	Is Container Running	${containername}
    # Kill the run if this fails.
    Should Be Equal As Integers	${_rc}	1
    Get Cluster Container IP Address
    Login To Cluster Container

Release Cluster Container
    [Documentation]  Releases a container by first releasing the active node and
    ...  then logging out from the container. The container is left running with
    ...  the node virtual machines in their current states. This saves time for
    ...  subsequent test suites.
    Release Node
    Disconnect From SUT
    # Leave the container running for other tests which may need the VMs in
    # their current state.

Use Node
    [Documentation]  This prepares a node for a test run. A named screen session
    ...  for the node is assumed to exist and is used.
    ...
    ...  The variable ${node} is set to the node being used.
    ...
    ...  This optionally resets the node if "_setup" equals "reset".
    [Arguments]  ${_node}  ${_setup}=none
    Set Suite Variable  ${node}  ${_node}
    Log To Console  Using node: ${node}
    Run Keyword If  '${_setup}'=='reset'  Reset Node  ${node}  initial
    Attach Screen  ${node}
    Run Keyword If  '${_setup}'=='reset'  Login To Mistify
    SSH Run  \n\n

Release Node
    [Documentation]  Detaches the active screen.
    Run Keyword If  '${node}'!='none'  Detach Screen
    Log To Console  Released node: ${node}
    Set Suite Variable  ${node}  none
