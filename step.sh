#!/bin/bash
set -ex

# replace preinstalled bundler on build VM
if [ "$CI" == "true" ]; then
    gem uninstall bundler
    gem install bundler --force
fi  

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
GEMFILE="--gemfile=${THIS_SCRIPT_DIR}/Gemfile"

#install step dependencies
bundle install $GEMFILE

bundle exec $GEMFILE ruby $THIS_SCRIPT_DIR/step.rb "$BITRISE_PROJECT_PATH" "$BITRISE_SCHEME"

