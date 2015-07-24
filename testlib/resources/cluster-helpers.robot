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

Reboot Node
    [Documentation]	Reboot a node. It's assumed already logged in.
    ...	This waits until the node has booted.
    [Arguments]  ${_n}
    Log To Console  Rebooting node: ${_n}
    Attach Screen  ${_n}
    ssh.Write  reboot
    ssh.Set Client Configuration  timeout=4m
    ${_o}=  ssh.Read Until  nonblocking pool is initialized
    ssh.Set Client Configuration  timeout=3s

    Detach Screen
    [Return]  ${_o}

Shutdown Node
    [Documentation]	Shutdown a node's VM and wait for it to shutdown.
    ...	This waits until the node has booted.

    [Arguments]  ${_n}

    Log To Console  Shutting down VM for node: ${_n}
    Attach Screen  ${_n}
    Exit VM In Screen
    ssh.Set Client Configuration  timeout=15s
    ssh.Read Until  QEMU: Terminated
    ssh.Set Client Configuration  timeout=3s
    Detach Screen

Start Node
    [Documentation]	Start a node's VM by running the the node's start script
    ...			created by ClusterInitialization.robot.
    ...	This waits until the node has booted.

    [Arguments]  ${_n}
    Log To Console  Starting VM for node: ${_n}
    Attach Screen  ${_n}

    ssh.Write  ~/tmp/start-${_n}
    ssh.Set Client Configuration  timeout=4m
    Log To Console  \nWaiting for node ${_n} to boot.
    ${_o}=  ssh.Read Until  nonblocking pool is initialized
    ssh.Set Client Configuration  timeout=3s

    Detach Screen
    [Return]  ${_o}

Restart Node
    [Documentation]	Restart a node by shutting down the node's VM and
    ...			restart the VM using the node's startup script created
    ...			by ClusterInitialization.robot.
    ...	This waits until the node has booted.

    [Arguments]  ${_n}

    Log To Console  Restarting VM for node: ${_n}
    Shutdown Node  ${_n}
    ${_o}=  Start Node  ${_n}
    [Return]  ${_o}

Reset Node
    [Documentation]	Reset a node by shutting down the node's VM and
    ...			restart the VM using the node's initial disk image and
    ...			startup script created by ClusterInitialization.robot.
    ...	This waits until the node has booted.

    [Arguments]  ${_n}

    Log To Console  Resetting VM for node: ${_n}
    Shutdown Node  ${_n}
    Attach Screen  ${_n}
    ssh.Write  cp ~/images/${_n}.img.initial ~/images/${_n}.img
    Detach Screen
    ${_o}=  Start Node  ${_n}
    [Return]  ${_o}

Reset All Nodes
    [Documentation]	This resets all nodes to their initial states.
    ...
    ...	NOTE: This can take some time because each node is completely reset
    ...	before the next node is reset.

    :FOR  ${_n}  IN  @{MISTIFY_CLUSTER_NODES}
      \  Reset Node  ${_n}

Get Cluster Container IP Address
    Log To Console	\n
    ${_o}=	Container IP Address	${containername}
    Log To Console	\nContainer IP address: ${_o}
    Should Contain X Times	${_o}  \.  3
    Set Suite Variable	${ip}  ${_o}
    Log To Console	\nContainer IP address is: ${ip}

Login To Cluster Container
    Log To Console  \nLogging in as ${USER} to container at IP: ${ip}
    Login to SUT  ${ip}  ${USER}  ${USER}
    ${_o}=  SSH Run And Get Output  pwd
    ${homedir}=  Get Line  ${_o}  0
    Should Contain  ${homedir}  /home/${USER}
    Set Suite Variable  ${homedir}
    Log To Console  Home directory is: ${homedir}

Use Cluster Container
    Get Command Line Options
    ${containername}=	Container Name
    Set Suite Variable  ${containername}
    Set Suite Variable  ${rootprompt}  root\@${containername}
    Set Suite Variable  ${userprompt}  ${USER}\@${containername}
    Log To Console  containername = ${containername}
    Log To Console  rootprompt = ${rootprompt}
    Log To Console  userprompt = ${userprompt}
    ${_rc}=	Is Container Running	${containername}
    Should Be Equal As Integers	${_rc}	1
    Get Cluster Container IP Address
    Login To Cluster Container
    Run Keyword If  '${ts_setup}'=='reset'  Update Mistify Images

Release Cluster Container
    Release Node
    Disconnect From SUT
    # Leave the container running for other tests which may need the VMs in
    # their current state.

Use Node
    [Documentation]  This prepares a node for a test run.
    ...
    ...  The variable ${node} is set to the node being used.
    ...
    ...	This optionally resets the node if ${_ts_setup} equals "reset".
    [Arguments]  ${_node}  ${_ts_setup}=none
    Set Suite Variable  ${node}  ${_node}
    Log To Console  Using node: ${node}
    Run Keyword If  '${_ts_setup}'=='reset'  Reset Node  ${node}
    Attach Screen  ${node}
    Run Keyword If  '${_ts_setup}'=='reset'  Login To Mistify
    SSH Run  \n\n

Release Node
    [Documentation]  Detaches the active screen.
    Run Keyword If  '${node}'!='none'  Detach Screen
    Log To Console  Released node: ${node}
    Set Suite Variable  ${node}  none
