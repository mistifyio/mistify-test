*** Settings ***
Documentation	This test creates a Linux Container (lxc) in which to
...		run test builds and more.
...
...	Part of testing Mistify-OS is verfiying it will build under
...	different configurations. It has been shown that buildroot
...	is not a perfect solution for build isolation. For example
...	there have been instances where a distro's installed
...	libraries or header files have been used when they shouldn't
...	have. This has created situations where a build works fine
...	on one distro but fails on another. This component is intended
...	to create a container based upon a specific distro to verify
...	a Mistify-OS build.
...
...	NOTE: This creates an unprivileged container.

Library		OperatingSystem

*** Variables ***
${LXC_BRIDGE}	lxcbr0

*** Keywords ***
Container Name
    [Documentation]  This returns a name to associate with a container based
    ...		     upon the container distribution and and ID from the
    ...		     the command line.
    ...
    ...	NOTE: The optional variable CONTAINER_ID is passed on the command line
    ...	which is used to uniquely identify containers and avoid collisions
    ...	between concurrent test runs.
    ...	e.g. ./testmistify -- -v CONTAINER_ID:=<id>

    ${_id}=  Get Variable Value  ${CONTAINER_ID}  ${EMPTY}
    ${_n}=  catenate  SEPARATOR=  ${DISTRO_LONG_NAME}  ${_id}
    [Return]  ${_n}

Test LXC Is Installed
    ${_o}=	Run	lxc-create --help
    Should Contain	${_o}	lxc-create creates a container

Create Unprivileged Container
    [Arguments]	${_container_name}  ${_distro_name}
    ...		${_distro_version_name}  ${_distro_arch}
    Log To Console	\nCreating container: ${_container_name} in ${CONTAINER_DIR}
    ${_c}=	catenate	SEPARATOR=${SPACE}
    ...  lxc-create -t download
    ...  -n ${_container_name}
    ...  -- -d ${_distro_name} -r ${_distro_version_name}
    ...  -a ${_distro_arch}
    ${_rc}	Run And Return Rc	${_c}
    [Return]	${_rc}

Container List
    ${_o}=	Run	lxc-ls -f
    [Return]	${_o}

Start Container
    [Arguments]	${_container_name}
    ${_rc}=	Run And Return Rc	lxc-start -d -n ${_container_name}
    # Some time is needed for the container to obtain an IP address.
    ${_o}=	Run	sleep 5
    [Return]	${_rc}

Does Container Exist
    [Documentation]	Tests to see if the container exists.
    ...
    ...		Returns 1 if the container exists and 0 if it doesn't.
    [Arguments]	${_container_name}
    ${_rc}=	Run And Return Rc
	...	lxc-ls -f --running --stopped \| grep \'${_container_name}\\s\'
    Return From Keyword If	${_rc} == ${0}	${1}
    [Return]	${0}

Is Container Running
    [Documentation]	Tests to see if the container is running.
    ...
    ...		Returns 1 if the container is running and 0 if it isn't.
    [Arguments]	${_container_name}
    ${_rc}=	Run And Return Rc
	...	lxc-ls -f --running \| grep \'${_container_name}\\s\'
    Return From Keyword If	${_rc} == ${0}	${1}
    [Return]	${0}

Container IP Address
    [Documentation]	This assumes lxc assigns ip addresses in the 10.0.3 range.
    [Arguments]	${_container_name}
    ${_o}=	Run	lxc-ls -f --running
    Log To Console	\nRunning containers:\n${_o}
    ${_c}=	catenate
    	...	ip addr show dev ${LXC_BRIDGE} \|
    	...	grep 'inet ' \| awk '{print $2}' \|
    	...	awk -F'.' '{print $1 "." $2 "." $3}'
    ${_subnet}=	Run	${_c}
    # A running container can have more than one network interface. Select the
    # interface which is part of the lxc bridge.
    Log To Console	\nContainer subnet is: ${_subnet}
    ${_s}=	Replace String  ${_subnet}  .  \\.
    ${_c}=	catenate
	...	lxc-info -n ${_container_name} -iH \|
	...	grep ${_s}
    Log To Console	Running command: ${_c}
    ${_o}=	Run	${_c}
    Log To Console	\nContainer IP address is: ${_o}
    [Return]	${_o}

Use Container
    [Documentation]	This starts an existing container.
    ...
    ...		If the container doesn't exist one is created.
    [Arguments]	${_container_name}  ${_distro_name}
    ...		${_distro_version_name}  ${_distro_arch}
    ${_rc}=	Does Container Exist  ${_container_name}
    ${_rc}=	Run Keyword If  ${_rc} == 0  # 0 indicates no
    ...	Create Unprivileged Container
    ...		${_container_name}	${_distro_name}
    ...		${_distro_version_name}	${_distro_arch}
    ${_rc}=	Run Keyword Unless  ${_rc} == 1  # 1 indicates fail
    ...	Start Container  ${_container_name}
    [Return]  ${_rc}

Stop Container
    [Arguments]	${_container_name}
    ${_rc}	Run And Return Rc	lxc-stop -n ${_container_name}
    [Return]	${_rc}

Destroy Container
    [Arguments]	${_container_name}
    ${_rc}=	Run And Return Rc	lxc-destroy -n ${_container_name}
    [Return]	${_rc}
