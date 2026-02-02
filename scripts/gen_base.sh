#!/usr/bin/env bash

set -x

script_directory="$(cd -P "$(dirname "$0")"; pwd)"
current_directory="$(cd -P "$script_directory/../"; pwd)"

function run_in_context() (
   cd "$current_directory/docker/${1}/"
   "${@:2}"
)

run_in_context "arch" docker  build --tag dev-env-base .
