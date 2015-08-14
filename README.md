# mistify-test
Mistify Test Suite

This repository contains scripts and tools for testing Mistify and the underlying Mistify-OS.

## Test Suites

*  **basicsystemtests**:<br>
   This suite is intended to be run as a smoke test following a build of Mistify-OS. On the
   Jenkins server the project *Container-Build* is configured so that on a successful build
   it triggers another job named *Artifact-Testing/basicsystemtests*. This in turn uses a
   Jenkins slave running on dev-2 to execute the tests. The test suite assumes an *lxc*
   container is running for each Jenkins executor and within the container *qemu/kvm* 
   virtual machines are running. The build artifacts, *bzImage.mistify* and *initrd.mistify*
   are downloaded from the build and booted using the virtual machines. All tests are then
   executed against the Mistify-OS images running in the VMs. Currently, three VMs are 
   running and booted but only one is used for the smoke tests.
   
*  **setuptestcontainer**:<br>
   This suite initializes a container for running the **basicsystemtests**.
   
*  **buildtests**:<br>
   This suite builds **Mistify-OS** in a container. The build process is monitored by the
   test suite. The output of this build is used to run **basicsystemtests**.
   
*   **setupbuildcontainer**:<br>
   This suite initializes a container for running the **buildtests**.
   
