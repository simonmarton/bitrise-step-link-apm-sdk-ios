#!/bin/bash
set -ex

# replace preinstalled bundler on build VM
if [ $CI -eq "true" ]; then
    gem uninstall bundler
    gem install bundler --force
fi  

#install step dependencies
bundle install

# copy universal library for static linking
git clone git@github.com:bitrise-io/apm-cocoa-sdk.git
cp apm-cocoa-sdk/libMonitor.a "$BITRISE_PROJECT_PATH/.."
rm -rf apm-cocoa-sdk

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
bundle exec ruby $THIS_SCRIPT_DIR/step.rb "$BITRISE_PROJECT_PATH" "$BITRISE_SCHEME"