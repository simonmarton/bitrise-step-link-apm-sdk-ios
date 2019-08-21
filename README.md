# Xcode Link Bitrise APM library

Link the Bitrise APM library during the XCode build process into the resulting artifact.

The step works by modifying the project.pbxproj descriptor to include necessary flags and
variables for linking.

It finds the target project by referencing the $BITRISE_PROJECT_PATH and $BITRISE_SCHEME
variables set during project scanning phase, you do not have to explicitly set these inputs.
