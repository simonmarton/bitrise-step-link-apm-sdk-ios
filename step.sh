#!/bin/bash
set -ex

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
GEMFILE="--gemfile=${THIS_SCRIPT_DIR}/Gemfile"

# replace preinstalled bundler on build VM
if [ "$CI" == "true" ]; then
    gem install bundler --force
    gem update --system

    bundle update --bundler $GEMFILE
fi  

#install step dependencies
bundle install $GEMFILE

bundle exec $GEMFILE ruby $THIS_SCRIPT_DIR/step.rb

