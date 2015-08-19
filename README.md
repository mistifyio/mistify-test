# mistify-test
Mistify Test Suite

This repository contains scripts and tools for testing Mistify and the underlying Mistify-OS.

NOTE: This is a living document and subject to change without notice.

## Repository master and feature branches
The **master** branch of this repository contains the latest stable test suites. The **feature** branch is where new features are added and test test suites are updated for new versions of Mistify-OS. Additional branches can be created for different reasons but are merged into the **feature** branch for verification before releasing into the **master** branch.

## Repository tags
When a release of Mistify-OS occurs its repository is tagged for the release. Because different Mistify-OS releases can behave differently the corresponding test suites must change as well. In order to ensure the correct test suite is executed against a particular Mistify-OS release a corresponding tag having the same name as the Mistify-OS release is created.

## Test Suites

*  **basicsystemtests**:<br>
   This suite is intended to be run as a smoke test following a build of Mistify-OS. On the Jenkins server the project *Container-Build* is configured so that on a successful build it triggers another job named *Artifact-Testing/basicsystemtests*. This in turn uses a Jenkins slave running on dev-2 to execute the tests. The test suite assumes an *lxc* container is running for each Jenkins executor and within the container *qemu/kvm* virtual machines are running. The build artifacts, *bzImage.mistify* and *initrd.mistify* are downloaded from the build and booted using the virtual machines. All tests are then executed against the Mistify-OS images running in the VMs. Currently, three VMs are running and booted but only one is used for the smoke tests.
   
*  **setuptestcontainer**:<br>
   This suite initializes a container for running the **basicsystemtests**.
   
*  **buildtests**:<br>
   This suite builds **Mistify-OS** in a container. The build process is monitored by the test suite. The output of this build is used to run **basicsystemtests**.
   
*   **setupbuildcontainer**:<br>
   This suite initializes a container for running the **buildtests**.

## Test Suite Documentation

Most of the documentation for the test suites and supporting keywords is included in the source using **[Documentation]** sections. The script *gendoc* can be run to generate the documentation and place the output in a directory named *doc*.

## Automated test runs using Jenkins

Two jobs on [the Jenkins server](http://54.175.251.254:8080/) are configured to run Robot Framework tests. The first, [**Container-Build**](http://54.175.251.254:8080/job/Mistify/job/Container-Build/), runs the test suite which builds Mistify-OS in a container environment (**buildtests**). This test suite creates the build container if necessary before starting the build.  The second, [**basicsystemtests**](http://54.175.251.254:8080/job/Mistify/job/Artifact-Testing/job/basicsystemtests/), is triggered by **Container-Build** upon successful completion of a build.

The build artifactcs from **Container-Build** are published to an Amazon S3 bucket in a correspondingly named [directory](http://omniti-mystify-artifacts.s3.amazonaws.com/index.html?prefix=jobs/Container-Build/). Subdirectories correspond to the individual builds. The artifacts include the *bzImage.mistify* kernel image, the *initrd.mistify* root file system image along with their corresponding signature files and the corresponding build logs.

The test results from **basissystemtests** are also published to the **Container-Build** directory on S3 corresponding to the build which produced the artifacts which were tested. These test results are published to a sub-directory named **testresults/basicsystemtests** in the **Container-Build** artifact directory. At the beginning of a test run (**basicsystemtests**) the [documentation](http://54.175.251.254:8080/job/Mistify/job/Artifact-Testing/job/basicsystemtests/ws/doc/) is generated for that run which is also published to the same directory as the test results.

**NOTE:** Unfortunately, there is a bug in the S3 publish plugin for Jenkins which mangles some of the file names and directory names in a directory tree. Because of this the test results and the corresponding documentation are placed into the same directory. Fortunately, naming conventions have so far prevented a naming conflict. 

To view the test retults for a given test run use an URL like *http://omniti-mystify artifacts.s3.amazonaws.com/index.html?prefix=jobs/Container-Build/**buildnumber**/testresults/basissystemtests/report.html* (replace **buildnumber** with the number of the build you want to view). 

To view the documentation for the tests or the supporting **Robot Framework** scripts use an URL like *http://omniti-mystify artifacts.s3.amazonaws.com/index.html?prefix=jobs/Container-Build/**buildnumber**/testresults/basissystemtests/testlib.html* (replace **buildnumber** with the number of the build you want to view).

Even though the Jenkins server is running on an [AWS instance](http://54.175.251.254:8080/) the **Container-Build** and **basicsystemtests** jobs run using a Jenkins slave on *dev-2*. This is for two reasons. For the build, container builds on AWS are both relatively slow and unstable. Building on *dev-2* saves about an hour build time and has resulted in fewer false failures due to container related issues. The test run requires standing up another container which support *qemu/kvm* virtual machines in which to run instances of Mistify-OS. These also need to support virtual machine nesting so that Mistify itself can create virtual machines for guests. AWS doesn't support virtual machines.

**NOTE:** A known problem is interrupting a test run can result in the test container and node virtual machines being in an ambigous state. Once a test run has started interrupting it is not recommended. To help recover from this problem the **basicsystemtests** job has a parameter named *fresh_container*. Setting this to "yes" will cause the test run to destroy the existing container and stand up a new one.

For the sake of time build containers are stopped at the end of a build but not destroyed. This way they can be re-used for subsequent runs.

In contrast and again for the sake of time test containers and the internal VMs are left running. When testing a new build the VMs are shutdown and restarted to boot using the new images but having the exact same options as before (e.g. MAC address, UUID).

