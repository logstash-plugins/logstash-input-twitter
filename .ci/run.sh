#!/bin/bash
# This is intended to be run inside the docker container as the command of the docker-compose.

# Do not print TWITTER_ (auth) secrets
env | grep -v 'TWITTER_'

set -ex

jruby -rbundler/setup -S rspec -fd
