*** Settings ***
Documentation    A number of helper keywords for common patterns in test scripts.

Library	String
Library	Collections

*** Variables ***
${ssh_options}	-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

*** Keywords ***
Get Command Line Options
    [Documentation]  Robot Framework (pybot) support passing variables to test
    ...  scripts on the command line. This looks for some specific options
    ...  which are intended to setup a test run. Global variables are created
    ...  for these options. They default to "none" if not passed on the command
    ...  line.
    ...  The variables are and their intendende semantics are:
    ...    SETUP    Indicate the actions to take for setting up a new test run.
    ...        reset = Reset to initial states for a test run.
    ...                Refer to other tests scripts to determine what actually
    ...                happens when this is used.
    ...    IMAGESDIR Where images to be tested are located. e.g. This is used
    ...             to indicate where the Mistify-OS kernel and initrd images
    ...             are located.
    ${ts_setup}=  Get Variable Value  ${SETUP}  none
    Set Global Variable  ${ts_setup}
    Log Message  Option ts_setup = ${ts_setup}
    ${ts_imagedir}=  Get Variable Value  ${IMAGESDIR}  ${BUILDDIR}/images
    Set Global Variable  ${ts_imagedir}
    Log Message  Option ts_imagedir = ${ts_imagedir}

Log Output
    [Documentation]  Writes to the test log file and the output is delimited by
    ...  the pattern "++++" at the start and "----" at the end. The output is
    ...  also sent to the console.
    [Arguments]  ${_output}
    # Escape sequences only clutter the output. Remove them.
    ${_o}=  Remove String Using Regexp  ${_output}
    ...  \\x1b\\[([0-9,A-Z]{1,2}(;[0-9]{1,2})?(;[0-9]{3})?)?[m|K]?
    Log  \nConsole output: \n++++\n${_o}\n----  console=true

Log Message
    [Documentation]  Writes the message to the log file and to the console.
    [Arguments]  ${_message}
    Log  \n${_message}  console=true

SSH Run
    [Documentation]	This runs a command using an active ssh session and
    ...			ignores the output.
    ...
    ...  The output is accumulated at .5 second intervals until no more output
    ...  or a timeout occurs. This can be overriden.  If the ${_option} parameter
    ...  is equal to "return" then this keyword immediately returns and doesn't
    ...  consume any of the output.
    [Arguments]	${_command}  ${_option}=none  ${_delay}=0.5s
    ssh.Write  ${_command}
    Return From Keyword If  '${_option}' == 'return'  none
    # Consume all the output.
    ${_o}=  ssh.Read	delay=${_delay}
    Log Output  ${_o}

SSH Run And Get Output
    [Documentation]	This runs a command using an active ssh session and
    ...			returns the output.
    ...
    ...	The output is accumulated at .5 second intervals until no more output
    ...	or a timeout occurs.
    [Arguments]	${_command}  ${_delay}=0.5s
    ssh.Write  ${_command}
    ${_o}=  ssh.Read	delay=${_delay}
    Log Output  ${_o}
    [Return]  ${_o}

SSH Run And Get First Line
    [Documentation]	This runs a command using an active ssh session and
    ...			returns the first line of the output.
    ...
    ...	The output is accumulated at .5 second intervals until no more output
    ...	or a timeout occurs.
    [Arguments]	${_command}  ${_delay}=0.5s
    ssh.Write  ${_command}
    ${_o}=  ssh.Read	delay=${_delay}
    Log Output  ${_o}
    ${_l}=  Get Line  ${_o}  1
    [Return]  ${_l}

SSH Run And Get Key Line
    [Documentation]  This runs the command using a key to indicate the output
    ...  and returns the line containing the key. Using a key helps separate
    ...  the desired output from other previous or following output (e.g.
    ...  prompts).
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
    [Arguments]	${_command}  ${_delay}=0.5s
    ssh.Write  ${_command}
    ssh.Read	delay=${_delay}
    ssh.Write  echo RC=$?
    ${_o}=  ssh.Read	delay=${_delay}
    Log Output  ${_o}
    ${_l}=  Get Lines Containing String  ${_o}  RC=
    # Ensure only the return code is used.
    ${_r}=  Remove String Using Regexp  ${_l}  \\D
    Log Message  Return code: ${_r}
    ${_r}=  Convert To Integer  ${_r}
    [Return]  ${_r}

SSH Wait For Output
    [Documentation]  Reads the ouput until the pattern is detected or a
    ...  timeout occurs.
    [Arguments]  ${_expected}
    ${_o}=  ssh.Read Until  ${_expected}
    [Return]  ${_o}

Consume Console Output
    [Documentation]     This consumes and ignores all the console output so
    ...			the next step can have a console which is in sync.
    [Arguments]  ${_delay}=0.5s
    ${_o}=  ssh.Read  delay=${_delay}
    Log Output  ${_o}
    [Return]  ${_o}

${_file} Should Exist
    [Documentation]  Uses ls to verify a file exists.
    Log Message  \nVerifying ${_file} exists.
    ${_r}=  SSH Run And Get Return Code  ls ${_file}
    Log Message  The return code is: ${_r}
    Should Be Equal As Integers  ${_r}  ${0}

${_file} Should Contain ${_pattern}
    [Documentation]  Uses grep to scan a file for a given pattern and returns
    ...  the output. This is intended to be used when the output will be a
    ...  single line.
    Log Message  \nSearching ${_file} for "${_pattern}"
    ${_l}=  SSH Run And Get Key Line  GREP:
    ...  grep '${_pattern}' ${_file}
    Should Contain  ${_l}  ${_pattern}

Files Should Be Same
    [Documentation]  Uses diff to compare two files and verify they are the
    ...  same by checking the diff return code.
    [Arguments]  ${_file1}  ${_file2}
    Log Message  \nComparing: \n\t${_file1}\n\t${_file2}
    ${_r}=  SSH Run And Get Return Code  diff ${_file1} ${_file2}
    Log Message  The return code is: ${_r}
    Should Be Equal As Integers  ${_r}  ${0}

Files Should Be Different
    [Documentation]  Uses diff to compare two files and verify they are NOT
    ...  the same by checking the diff return code.
    [Arguments]  ${_file1}  ${_file2}
    Log Message  \nComparing: \n\t${_file1}\n\t${_file2}
    ${_r}=  SSH Run And Get Return Code  diff ${_file1} ${_file2}
    Log Message  The return code is: ${_r}
    Should Not Be Equal As Integers  ${_r}  ${0}

${_process} Is Running
    [Documentation]  Uses pgrep to verify a given process is running.
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
    [Documentation]	Exit a running VM (outside a screen session).
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
    ...  IP address for a given subnet.
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
    [Documentation]  Uses ping to verify a given host is responding.
    ${_o}=  SSH Run And Get Output  ping -c 1 ${_host}
    Should Contain  ${_o}  1 packets transmitted
    Should Contain  ${_o}  1 received
    [Return]  ${_o}

Wait Until Host Responds To Ping
    [Documentation]  Tries to ping a given host until the host responds or a
    ...  timeout occurs.
    [Arguments]  ${_host}  ${_seconds}=10
    Log Message  Waiting ${_seconds} for ${_host} to respond.
    Wait Until Keyword Succeeds  ${_seconds} s  1 s  ${_host} Is Responding To Ping

Wait ${_seconds} Seconds Until ${_host} Responds To Ping
    [Documentation]  A more plain language form of "Wait Until Host Responds To Ping".
    Wait Until Host Responds To Ping  ${_ip}  ${_seconds}

Mark Time
    [Documentation]  Returns the current time and sets the global varaible,
    ...  marker, to the current time. This is handy when looking at events
    ...  since a certain time.
    ${_t}=  SSH Run And Get Key Line  HMS:  date +%T
    Log Message  Time marked at: ${_t}
    Set Suite Variable  ${marker}  ${_t}
    [Return]  ${_t}

Learn MAC Address
    [Documentation]	Returns the MAC address for a network interface.

    [Arguments]	${_interface}
    ${_c}=  catenate
    ...  ifconfig ${_interface} \| grep ether \| awk '{print \$2}'
    ${_r}=  SSH Run And Get Key Line  MAC=  ${_c}
    Log Message  \nLearn MAC Address: ${_r}
    [Return]  ${_r}

Learn UUID
    [Documentation]	Returns the UUDI for the current console device.

    ${_r}=  SSH Run And Get Key Line  UUID=  hostname
    Log Message  \nLearn UUID ${_r}
    [Return]  ${_r}

Fix Serial Console Wrap
    [Documentation]  Change console attributes to avoid automatic wrap on a
    ...              serial console.
    ...  Serial consoles (ttySx) have annoying habit of attempting to wrap lines
    ...  automatically which inserts carriage returns and escape sequences into long lines and
    ...  long lines which wrap to the next line. This  really confuses tests
    ...  which are looking for patterns in those long lines.
    ...  This is a work-around which simply sets the terminal attributes to
    ...  a large number of rows and columns. This allows a console window to
    ...  to control the wrap and scroll.
    ...  Use this keyword after logging in.
    SSH Run  COLUMNS=1000;LINES=1000;export COLUMNS LINES;
    SSH Run  stty rows $LINES columns $COLUMNS
    SSH Run  export TERM=linux

