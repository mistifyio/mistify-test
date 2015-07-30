*** Settings ***
Documentation	\nThis prepares a container for testing Mistify-OS within the
...		container.
...
...	This test suite creates an LXC container then provisions the
...	container with tools needed to test multiple Mistify-OS nodes within
...	the container.
...
...	WARNING: Currently this supports only Debian based containers.

Library		String

#+
# NOTE: The variable TESTLIBDIR is passed from the command line by the testmistify
# script. There is no default value for this variable.
#-
Resource	${TESTLIBDIR}/resources/mistify.robot
Resource	${TESTLIBDIR}/resources/ssh.robot
Resource	${TESTLIBDIR}/resources/lxc.robot

Suite Setup             Setup Testsuite
Suite Teardown          Teardown Testsuite


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

Connect To Container
    Login To Localhost
    ssh.Write  lxc-attach -n ${containername}
    ${_o}=  ssh.Read Until  ${prompt}
    Log To Console  \nAttach:\n${_o}
    Should Contain  ${_o}  ${prompt}

Define Package List
    [Documentation]	This is the list of packages needed to support running
    ...			multiple VMs in the container which can communicate with
    ...			each other.
    ${packages}=  catenate  SEPARATOR=${SPACE}
    ...  git isc-dhcp-server uml-utilities screen qemu qemu-kvm uuid-runtime
    ...  curl tcpdump mtr
    Set Suite Variable  ${packages}

Update APT Database
    [Documentation]	The package database needs to be updated
    ...			before the packages can be installed.
    Log To Console  \nThis works only for debian based distros!!
    Log To Console  \nInstalling: ${packages}
    ssh.Write  ls /
    ${_o}=  ssh.Read Until  ${prompt}  loglevel=INFO
    Log To Console  \nUpdating the package database.
    ssh.Set Client Configuration  timeout=1m
    ssh.Write  apt-get update
    ${_o}=  ssh.Read Until  ${prompt}  loglevel=INFO

Install Key Tools
    ssh.Write  apt-get install -y ${packages}
    ssh.Set Client Configuration  timeout=20m
    ${_o}=  ssh.Read Until  ${prompt}  loglevel=INFO
    Log To Console  \napt-get returned:\n${_o}
    ssh.Set Client Configuration  timeout=3m

Verify Key Tools Installed
    Log To Console  \nThis works only for debian based distros!!
    Log To Console  \nPackage list: ${packages}
    ssh.Write  dpkg -l \| awk '/^[hi]i/{print $2}'
    ${_o}=	ssh.Read Until	${prompt}
    Log To Console  \nInstalled packages:\n${_o}
    @{_packages}=	Split String  ${packages}
    :FOR  ${_p}  IN  @{_packages}
    	\	Should Contain  ${_o}  ${_p}

Detach From Container
    ssh.Write  exit
    ${_o}=  ssh.Read Until  exit
    Should Contain  ${_o}  exit

Configure Container To Run VMs
    [Documentation]	To run VMs in an unprivileged container it is necessary
    ...			create the kvm node in the container's /dev directory
    ...			and to configure the container to enable the device.
    ...
    ...	NOTE: This requires the user be configured in sudo for no password.
    ...	This can be done by creating a file in /etc/sudoers.d as root:
    ...		echo "$USER ALL=(ALL) NOPASSWD:ALL">/etc/sudoers.d/$USER
    ...	Then run visudo and exit to enable the configuration.

    # Need to add a sudo test to verify no password is required.
    Log To Console  \nEnabling the kvm device in ${CONTAINER_DIR}/${containername}/config
    SSH Run  cd ${CONTAINER_DIR}/${containername}
    Log To Console  Updating config in: ${CONTAINER_DIR}/${containername}
    SSH Run  grep 10:232 config; if [ $? -gt 0 ]; then echo "lxc.cgroup.devices.allow = c 10:232 rwm" >>config; fi
    SSH Run  grep 10:232 config; if [ $? -gt 0 ]; then echo "lxc.cgroup.devices.allow = c 10:200 rwm" >>config; fi
    ssh.Write  cat config
    ${_o}=  ssh.Read Until  ${localprompt}
    Log To Console  ${_o}
    Should Contain  ${_o}  10:232

Add Node In Container For KVM
    [Documentation]	Create a node in the container rootfs for the kvm device.
    ...
    ...  WARNING! This requires sudo access! I hate taking this risk but don't
    ...  know of a better option at this point.
    # Because of the previous test we're already in the container directory.
    ${_m}=  catenate  SEPARATOR=${SPACE}
    ...	\nWARNING: This step requires sudo with no password. To enable sudo with
    ...	no password one method is to create a sudoers file in /etc/sudoers.d for
    ...	the user running this test suite.
    ...	\ne.g. <user> ALL=(ALL) NOPASSWD:ALL
    ...	\nOnce this test has successfully run sudo access can then be disabled
    ...	since the existing node will be used.
    Log To Console  ${_m}
    ssh.Set Client Configuration  timeout=3s
    SSH Run  cd ${CONTAINER_DIR}/${containername}/rootfs/dev
    ${_o}=  SSH Run And Get Output  pwd
    ${_l}=  Get Line  ${_o}  0
    Log To Console  \nCreating kvm node in: ${_l}
    ${_c}=  catenate  SEPARATOR=${SPACE}
    ...  if [ ! -e kvm ]; then
    ...    sudo mknod kvm c 10 232;
    ...    sudo chmod 0666 kvm;
    ...    sudo chown 100000.100000 kvm;
    ...  fi
    SSH Run  ${_c}
    ${_o}=  SSH Run And Get Output  ls -l
    ${_l}=  Get Lines Containing String  ${_o}  kvm
    Should Contain  ${_l}  10, 232
    Log To Console  \nDevices:\n${_o}

Add Node In Container For Tunnel
    [Documentation]	Create a node in the container rootfs for the tun device.
    ...
    ...  WARNING! This requires sudo access! I hate taking this risk but don't
    ...  know of a better option at this point.
    # Because of the previous test we're already in the container directory.
    ${_m}=  catenate  SEPARATOR=${SPACE}
    ...	\nWARNING: This step requires sudo with no password. To enable sudo with
    ...	no password one method is to create a sudoers file in /etc/sudoers.d for
    ...	the user running this test suite.
    ...	\ne.g. <user> ALL=(ALL) NOPASSWD:ALL
    ...	\nOnce this test has successfully run sudo access can then be disabled
    ...	since the existing node will be used.
    Log To Console  ${_m}
    ssh.Set Client Configuration  timeout=3s
    SSH Run  cd ${CONTAINER_DIR}/${containername}/rootfs/dev
    ${_o}=  SSH Run And Get Output  pwd
    ${_l}=  Get Line  ${_o}  0
    Log To Console  \nCreating net directory in: ${_l}
    ${_c}=  catenate  SEPARATOR=${SPACE}
    ...  if [ ! -e net/tun ]; then
    ...    sudo mkdir -p net;
    ...    sudo chown 100000.100000 net;
    ...  fi
    SSH Run  ${_c}
    SSH Run  cd ${CONTAINER_DIR}/${containername}/rootfs/dev/net
    ${_o}=  SSH Run And Get Output  pwd
    ${_l}=  Get Line  ${_o}  0
    Log To Console  \nCreating tun node in: ${_l}
    ${_c}=  catenate  SEPARATOR=${SPACE}
    ...  if [ ! -e tun ]; then
    ...    sudo mknod tun c 10 200;
    ...    sudo chmod 0666 tun;
    ...    sudo chown 100000.100000 tun;
    ...  fi
    SSH Run  ${_c}
    ${_o}=  SSH Run And Get Output  ls -l
    ${_l}=  Get Lines Containing String  ${_o}  tun
    Should Contain  ${_l}  100000 100000 10, 200
    Log To Console  \nNet Devices:\n${_o}

*** Keywords ***
Setup Testsuite
    ${containername}=	Container Name
    Set Suite Variable  ${containername}
    Set Suite Variable  ${prompt}  root\@${containername}
    Set Suite Variable  ${localprompt}  ${USER}@

    ${_rc}=	Use Container
    ...	${containername}  ${DISTRO_NAME}
    ...	${DISTRO_VERSION_NAME}	${DISTRO_ARCH}
    Log To Console	\nUsing container: ${containername}
    Run Keyword Unless  ${_rc} == 0
    ...	Log To Console	\nContainer could not be created.
    ...		WARN

Teardown Testsuite
    Disconnect From Localhost
    Stop Container	${containername}

