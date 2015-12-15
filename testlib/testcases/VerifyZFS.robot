*** Settings ***
Documentation	Verify ZSF is running and the zfs directories have been
...		mounted.

#+
# NOTE: The variable TESTLIBDIR is passed from the command line by the testmistify
# script. There is no default value for this variable.
#-
Resource	${TESTLIBDIR}/config/mistify.robot
Resource	${TESTLIBDIR}/resources/ssh.robot
Resource	${TESTLIBDIR}/resources/lxc.robot

Resource	${TESTLIBDIR}/resources/cluster-helpers.robot

Suite Setup	Use Cluster Container
Suite Teardown	Release Cluster Container

*** Test Cases ***
Select Test Node
    [Documentation]  Select which node to run the tests against.
    Use Node  @{MISTIFY_CLUSTER_NODES}[0]

Check For SPL
    [Documentation]	ZFS requires the SPL kernel module.
    ...
    ...			Verify the spl kernel module is loaded and has
    ...			properly associated with the zfs modules.
    ${_o}=  SSH Run And Get Output  lsmod \| grep spl
    # It may be this can be expressed as a list of patterns but
    # it's not obvious how to do that at the moment so brute force.
    Should Contain
    ...	${_o}	spl
    Should Contain
    ...	${_o}	zfs
    Should Contain
    ...	${_o}	zcommon
    Should Contain
    ...	${_o}	znvpair

Check For ZFS
    [Documentation]	Verify ZFS kernel modules are loaded on the SUT.
    ...
    ...		ZFS includes a number of kernel modules which must be loaded
    ...		before any zfs devices can be mounted.
    ${_o}=  SSH Run And Get Output  lsmod \| grep '^z' \| cut -f 1 -d ' '
    Should Contain
    ...	${_o}	zfs
    Should Contain
    ...	${_o}	zavl
    Should Contain
    ...	${_o}	zunicode
    Should Contain
    ...	${_o}	zcommon
    Should Contain
    ...	${_o}	znvpair

Check ZFS Mounts
    [Documentation]	Verify the ZFS file systems have been mounted.
    ...
    ...		For Mistify-OS a number of zfs mounts must exist in
    ...		known locations or other components may fail.
    ${_o}=  SSH Run And Get Output  mount \| grep 'mistify'
    Should Contain
    ...	${_o}	mistify on /mistify type zfs
    Should Contain
    ...	${_o}	mistify/guests on /mistify/guests type zfs
    Should Contain
    ...	${_o}	mistify/images on /mistify/images type zfs
    Should Contain
    ...	${_o}	mistify/private on /mistify/private type zfs
    Should Contain
    ...	${_o}	mistify/data on /mistify/data type zfs

*** Keywords ***
