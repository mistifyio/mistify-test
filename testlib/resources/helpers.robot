*** Settings ***
Documentation    A number of helper keywords for common patterns in test scripts.

Library	String
Library	Collections

*** Variables ***
${ssh_options}	-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

*** Keywords ***
SSH Run
    [Documentation]	This runs a command using an active ssh session and
    ...			ignores the output.
    ...
    ...	The output is accumulated at .5 second intervals until no more output
    ...	or a timeout occurs.
    [Arguments]	${_command}
    ssh.Write  ${_command}
    # Consume all the output.
    ${_o}=  ssh.Read	delay=0.5s

SSH Run And Get Output
    [Documentation]	This runs a command using an active ssh session and
    ...			returns the output.
    ...
    ...	The output is accumulated at .5 second intervals until no more output
    ...	or a timeout occurs.
    [Arguments]	${_command}
    ssh.Write  ${_command}
    ${_o}=  ssh.Read	delay=0.5s
    [Return]  ${_o}

SSH Run And Get Return Code
    [Documentation]	This runs a command using an active ssh session and
    ...			returns the return code as an ASCII string.
    ...
    ...	The output is accumulated at .5 second intervals until no more output
    ...	or a timeout occurs.
    [Arguments]	${_command}
    ssh.Write  ${_command}
    ssh.Read	delay=0.5s
    ssh.Write  echo $?
    ${_o}=  ssh.Read	delay=0.5s
    ${_l}=  Get Line  ${_o}  0
    [Return]  ${_l}

Consume Console Output
    [Documentation]     This consumes and ignores all the console output so
    ...			the next step can have a console which is in sync.
    ${_o}=  ssh.Read  delay=0.5s
    [Return]  ${_o}

Start Screen Session
    [Documentation]	Start a new screen session with a given name.
    [Arguments]	${_name}
    SSH Run  screen -S ${_name}

Attach Screen
    [Documentation]	Attach to an existing screen session.
    ...
    ...	Because re-attaching a screen session can result in a bunch of
    ...	console spew the output is consumed and ignored.
    [Arguments]	${_name}
    Log To Console  \nConnecting to screen session: ${_name}
    SSH Run  screen -r ${_name}

Detach Screen
    [Documentation]	Detach from the active screen.
    ...
    ...	This is provided because of the funky control character handling.
    ...
    ...  NOTE: This assumes that the session is active.
    ${_c_a}=  Evaluate  chr(int(1))
    ssh.Write Bare  ${_c_a}d

Exit VM In Screen
    [Documentation]	Exit a running VM which was started in a screen session.
    ...
    ...	This is provided because of the funky control character handling.
    ...
    ...  NOTE: This assumes the VM is actually running inside a screen session.
    ${_c_a}=  Evaluate  chr(int(1))
    ssh.Write Bare  ${_c_a}ax

Exit VM
    [Documentation]	Exit a running VM.
    ...
    ...	This is provided because of the funky control character handling.
    ...
    ...  NOTE: This assumes the VM is actually running inside a screen session.
    ${_c_a}=  Evaluate  chr(int(1))
    ssh.Write Bare  ${_c_a}x

Learn Test Interface
    [Documentation]	Discover which interface is up and on the test network.
    ${_c}=  catenate  SEPARATOR=${SPACE}
    ...  ifconfig \| grep 'inet ${MISTIFY_BRIDGE_SUBNET}' -B 1 \|
    ...  grep flags \| cut -d ':' -f 1
    ${_o}=  SSH Run And Get Output  ${_c}
    Log To Console  \nLearn Active Interface: ${_o}
    ${_r}=  Get Line  ${_o}  -2
    [Return]  ${_r}

Learn IP Address
    [Documentation]	Get the IP address for a network interface.
    ...
    ...	WARNING: This is very basic at the moment.
    [Arguments]	${_interface}
    ${_c}=  catenate  SEPARATOR=${SPACE}
    ...  ifconfig ${_interface} \| grep 'inet ' \| awk '{print \$2}'
    ${_o}=  SSH Run And Get Output  ${_c}
    Log To Console  \nLearn IP Address: ${_o}
    ${_r}=  Get Line  ${_o}  -2
    [Return]  ${_r}

Learn MAC Address
    [Documentation]	Get the MAC address for a network interface.

    [Arguments]	${_interface}
    ${_c}=  catenate  SEPARATOR=${SPACE}
    ...  ifconfig ${_interface} \| grep ether \| awk '{print \$2}'
    ${_o}=  SSH Run And Get Output  ${_c}
    Log To Console  \nLearn MAC Address: ${_o}
    ${_r}=  Get Line  ${_o}  -2
    [Return]  ${_r}

Learn UUID
    [Documentation]	Get the UUDI for the current console device.

    [Arguments]	${_interface}
    ${_o}=  SSH Run And Get Output  hostname
    Log To Console  \nLearn UUID: ${_o}
    ${_r}=  Get Line  ${_o}  -2
    [Return]  ${_r}

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
      \  ${_uuid}=  Learn UUID  ${_if}
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

Login To Mistify
    [Documentation]	Login to Mistify using the current console.

    Consume Console Output
    ssh.Set Client Configuration  timeout=15s
    ssh.Write  \r
    ssh.Read Until  Welcome to Mistify-OS
    ssh.Write  \r
    ${_o}=  ssh.Read Until  ${MISTIFY_LOGIN_PROMPT}
    Should Contain  ${_o}  ${MISTIFY_LOGIN_PROMPT}
    ssh.Write  ${MISTIFY_USERNAME}
    ${_o}=  ssh.Read Until  Password:
    Should Contain  ${_o}  Password:
    ssh.Write  ${MISTIFY_PASSWORD}
    ${_o}=  ssh.Read Until  ${MISTIFY_PROMPT}
    Should Contain  ${_o}  ${MISTIFY_PROMPT}
    ssh.Set Client Configuration  timeout=3s

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
    [Arguments]  ${_n}
    Log To Console  Rebooting node: ${_n}
    Attach Screen  ${_n}
    ssh.Write  reboot
    Detach Screen
