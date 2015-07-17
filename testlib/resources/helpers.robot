*** Settings ***
Documentation    A number of helper keywords for common patterns in test scripts.

Library	String
Library	Collections

*** Variables ***
${ssh_options}	-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

*** Keywords ***
Get Command Line Options
    ${ts_setup}=  Get Variable Value  ${SETUP}  none
    Set Suite Variable  ${ts_setup}

Log Output
    [Arguments]  ${_output}
    ${_e}=  Evaluate  chr(int(0x1b))
    ${_o}=  Replace String  ${_output}  ${_e}  ESC
    Log  \nConsole output: \n++++\n${_o}\n----  console=true

Log Message
    [Arguments]  ${_message}
    Log  \n${_message}  console=true

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
    Log Output  ${_o}

SSH Run And Get Output
    [Documentation]	This runs a command using an active ssh session and
    ...			returns the output.
    ...
    ...	The output is accumulated at .5 second intervals until no more output
    ...	or a timeout occurs.
    [Arguments]	${_command}
    ssh.Write  ${_command}
    ${_o}=  ssh.Read	delay=0.5s
    Log Output  ${_o}
    [Return]  ${_o}

SSH Run And Get First Line
    [Documentation]	This runs a command using an active ssh session and
    ...			returns the first line of the output.
    ...
    ...	The output is accumulated at .5 second intervals until no more output
    ...	or a timeout occurs.
    [Arguments]	${_command}
    ssh.Write  ${_command}
    ${_o}=  ssh.Read	delay=0.5s
    Log Output  ${_o}
    ${_l}=  Get Line  ${_o}  1
    [Return]  ${_l}

SSH Run And Get Key Line
    [Documentation]	This runs the command using a key to indicate the output
    ...			and returns the line containing the key.
    [Arguments]	${_key}  ${_command}
    ${_o}=  SSH Run And Get Output  echo ${_key}`${_command}`
    ${_l}=  Get Lines Containing String  ${_o}  ${_key}
    ${_r}=  Remove String  ${_l}  ${_key}
    [Return]  ${_r}

SSH Run And Get Return Code
    [Documentation]	This runs a command using an active ssh session and
    ...			returns the return code as an ASCII string.
    ...
    ...	The output is accumulated at .5 second intervals until no more output
    ...	or a timeout occurs.
    [Arguments]	${_command}
    ssh.Write  ${_command}
    ssh.Read	delay=0.5s
    ssh.Write  echo RC=$?
    ${_o}=  ssh.Read	delay=0.5s
    Log Output  ${_o}
    ${_l}=  Get Lines Containing String  ${_o}  RC=
    # Ensure only the return code is used.
    ${_r}=  Remove String Using Regexp  ${_l}  \\D
    Log Message  Return code: ${_r}
    ${_r}=  Convert To Integer  ${_r}
    [Return]  ${_r}

Consume Console Output
    [Documentation]     This consumes and ignores all the console output so
    ...			the next step can have a console which is in sync.
    ${_o}=  ssh.Read  delay=0.5s
    Log Output  ${_o}
    [Return]  ${_o}

${_file} Should Contain ${_pattern}
    Log Message  \nSearching ${_file} for "${_pattern}"
    ${_l}=  SSH Run And Get Key Line  GREP:
    ...  grep '${_pattern}' ${_file}

Files Should Be Same
    [Arguments]  ${_file1}  ${_file2}
    Log Message  \nComparing: \n\t${_file1}\n\t${_file2}
    ${_r}=  SSH Run And Get Return Code  diff ${_file1} ${_file2}
    Log Message  The return code is: ${_r}
    Should Be Equal As Integers  ${_r}  ${0}

Files Should Be Different
    [Arguments]  ${_file1}  ${_file2}
    Log Message  \nComparing: \n\t${_file1}\n\t${_file2}
    ${_r}=  SSH Run And Get Return Code  diff ${_file1} ${_file2}
    Log Message  The return code is: ${_r}
    Should Not Be Equal As Integers  ${_r}  ${0}

${_process} Is Running
    ${_r}=  SSH Run And Get Return Code  pgrep ${_process}
    Log Message  The return code is: ${_r}
    Should Be Equal As Integers  ${_r}  ${0}

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
    Log Message  \nConnecting to screen session: ${_name}
    SSH Run  screen -r ${_name}

Detach Screen
    [Documentation]	Detach from the active screen.
    ...
    ...	This is provided because of the funky control character handling.
    ...
    ...  NOTE: This assumes that the session is active.
    Log Message  \nDetaching from screen session.
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
    ${_r}=  SSH Run And Get Key Line  IF=  ${_c}
    Log Message  \nLearn Active Interface: ${_r}
    [Return]  ${_r}

Learn IP Address
    [Documentation]	Get the IP address for a network interface.
    ...
    ...	WARNING: This is very basic at the moment.
    [Arguments]	${_interface}
    ${_c}=  catenate
    ...  ifconfig ${_interface} \| grep 'inet ' \| awk '{print \$2}'
    ${_r}=  SSH Run And Get Key Line  IP=  ${_c}
    Log Message  \nLearn IP Address: ${_r}
    [Return]  ${_r}

Learn IP Address For Subnet
    [Documentation]	Get the IP address for a subnet on a given interface.
    ...
    ...  An interface can have more than one IP address. This returns the IP
    ...  IP address for a subnet.
    [Arguments]	${_interface}  ${_subnet}
    ${_c}=  catenate
    ...  ip addr show dev ${_interface} \| grep ${_subnet}
    ${_o}=  SSH Run And Get Key Line  IP=  ${_c}
    Should Contain  ${_o}  ${_subnet}
    @{_ls}=  Split String  ${_o}
    @{_f}=  Split String  @{_ls}[1]  /
    ${_r}=  Set Variable  @{_f}[0]
    Log Message  \nLearn IP Address: ${_r}
    [Return]  ${_r}

${_host} Is Responding To Ping
    ${_o}=  SSH Run And Get Output  ping -c 1 ${_host}
    Should Contain  ${_o}  1 packets transmitted
    Should Contain  ${_o}  1 received
    [Return]  ${_o}

Wait Until Host Responds To Ping
    [Arguments]  ${_host}  ${_seconds}=10
    Log Message  Waiting ${_seconds} for ${_host} to respond.
    Wait Until Keyword Succeeds  ${_seconds} s  1 s  ${_host} Is Responding To Ping

Wait ${_seconds} Seconds Until ${_host} Responds To Ping
    Wait Until Host Responds To Ping  ${_ip}  ${_seconds}

Mark Time
    [Documentation]  Get the current time.
    ${_t}=  SSH Run And Get Key Line  HMS:  date +%T
    Log Message  Time marked at: ${_t}
    Set Suite Variable  ${marker}  ${_t}
    [Return]  ${_t}

Learn MAC Address
    [Documentation]	Get the MAC address for a network interface.

    [Arguments]	${_interface}
    ${_c}=  catenate
    ...  ifconfig ${_interface} \| grep ether \| awk '{print \$2}'
    ${_r}=  SSH Run And Get Key Line  MAC=  ${_c}
    Log Message  \nLearn MAC Address: ${_r}
    [Return]  ${_r}

Learn UUID
    [Documentation]	Get the UUDI for the current console device.

    ${_r}=  SSH Run And Get Key Line  UUID=  hostname
    Log Message  \nLearn UUID ${_r}
    [Return]  ${_r}

Fix Serial Console Wrap
    [Documentation]  Change console attributes to avoid automatic wrap on a
    ...              serial console.
    ...	Serial consoles (ttySx) have annoying habit of attempting to wrap lines
    ...	automatically which inserts carriage returns into long lines and
    ...	really confuses tests which are looking for patterns in those long lines.
    ...	This is a work-around which simply sets the terminal attributes to
    ...	a large number of rows and columns. This allows a console window to
    ...	to control the wrap and scroll.
    ...	Use this keyword after logging in.
    SSH Run  COLUMNS=1000;LINES=1000;export COLUMNS LINES;
    SSH Run  stty rows $LINES columns $COLUMNS
    SSH Run  export TERM=linux

