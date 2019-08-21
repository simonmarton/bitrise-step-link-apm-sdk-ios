#!/bin/bash
set -ex

# replace preinstalled bundler on build VM
if [ $CI -eq "true" ]; then
    gem uninstall bundler
    gem install bundler --force
fi  

#install step dependencies
bundle install

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
bundle exec ruby $THIS_SCRIPT_DIR/step.rb "$BITRISE_PROJECT_PATH" "$BITRISE_SCHEME"