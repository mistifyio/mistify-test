*** Settings ***
Documentation	This series of keywords provide some Mistify specific helpers.

Library	String
Library	Collections

*** Variables ***

*** Keywords ***
#### systemd ####
Start Service ${_service}
    SSH Run  systemctl start ${_service}

Stop Service ${_service}
    SSH Run  systemctl stop ${_service}

Restart Service ${_service}
    SSH Run  systemctl restart ${_service}

Service ${_service} Should Be ${_state}
    [Documentation]	Uses systemctl to see if the service is in the desired
    ...			state.
    ...	This is designed to be used with "Wait Until Keyword Succeeds".
    ${_l}=  SSH Run And Get Key Line  NCD=  systemctl is-active ${_service}
    Log Message  ${_service} state: \n${_l}
    Should Contain  ${_l}  ${_state}

Service ${_service} Should Not Be ${_state}
    [Documentation]	Uses systemctl to see if the service is NOT in the
    ...			given state.
    ...	This is designed to be used with "Wait Until Keyword Succeeds".
    ${_l}=  SSH Run And Get Key Line  NCD=  systemctl is-active ${_service}
    Log Message  ${_service} state: \n${_l}
    Should Not Contain  ${_l}  ${_state}

Wait ${_seconds} Seconds Until Service ${_service} Is ${_state}
    Wait Until Keyword Succeeds  ${_seconds} s  1 s
    ...  Service ${_service} Should Be ${_state}

Get List Of ${_state} Services
    ${_o}=  SSH Run And Get Output  systemctl --no-pager --state=${_state}
    [Return]  ${_o}

#### etcd ####
Set Etcd Data
    [Arguments]  ${_path}  ${_data}
    ${_o}=  SSH Run And Get Output  etcdctl set ${_path} '${_data}'
    [Return]  ${_o}

Get Etcd Data
    [Arguments]  ${_path}
    ${_d}=  SSH Run And Get Key Line  DATA:
    ...  etcdctl get ${_path}
    [Return]  ${_d}

Download Etcd Data
    [Arguments]  ${_path}  ${_output}  ${_host}=localhost
    ${_c}=  catenate
    ...  curl http://${_host}:4001/v2/keys/${_path} --create-dirs -o ${_output}
    SSH Run  ${_c}

Is Etcd Healthy
    ${_o}=  SSH Run And Get Output  etcdctl cluster-health
    Log Message  Cluster health: \n${_o}
    Should Contain  ${_o}  is healthy

Is Etcd Listening On Port ${_ip} ${_port}
    Log Message  Verifying etcd is listening at: ${_ip}:${_port}
    ${_o}=  SSH Run And Get Output  netstat -lpn \| grep etcd \| grep ${_port}
    Should Contain  ${_o}  ${_ip}:${_port}
    Should Contain  ${_o}  LISTEN
    Should Contain  ${_o}  /etcd

#### nconfigd ####
Enable Hypervisor For Service
    [Arguments]  ${_node}  ${_service}
    ${_u}=  Get Node UUID  ${_node}
    SSH Run  etcdctl set /lochness/hypervisors/${_u}/config/${_service} true
    Verify Hypervisor Service Enabled  ${_node}  ${_service}

Verify Hypervisor Service Enabled
    [Arguments]  ${_node}  ${_service}
    ${_u}=  Get Node UUID  ${_node}
    ${_d}=  Get Etcd Data  /lochness/hypervisors/${_u}/config/${_service}
    Should Contain  ${_d}  true
    Log Message  Service state: ${_node} ${_service} ${_d}

#### journalctl ####
Get ${_unit} Log Since ${_time}
    ${_o}=  SSH Run And Get Output  journalctl --no-pager -u ${_unit} --since ${_time}
    [Return]  ${_o}

#### misc. ####
Get Json Field
    [Arguments]  ${_file}  ${_field}
    ${_o}=  SSH Run And Get Output  testlib/scripts/${MISTIFY_JSON_PARSER} ${_file} ${_field}
    [Return]  ${_o}

Update Mistify Images
    [Documentation]	Copy the images from a Mistify-OS build to the test
    ...			environment.
    ...
    ...  This assumes already logged into the test environment.

    Log Message  Updating Mistify Images
    SSH Run  cd ~
    ssh.Put File  ${BUILDDIR}/images/${MISTIFY_KERNEL_IMAGE}  images/
    ssh.Put File  ${BUILDDIR}/images/${MISTIFY_INITRD_IMAGE}  images/
    ${_o}=  SSH Run And Get Output  ls -l images
    Log Message  Mistify Images:\n${_o}
    Should Contain  ${_o}  ${MISTIFY_KERNEL_IMAGE}
    Should Contain  ${_o}  ${MISTIFY_INITRD_IMAGE}

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
    Fix Serial Console Wrap

