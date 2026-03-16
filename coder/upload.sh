#!/usr/bin/env bash


target_dir="${1:-.}"
if ![[ -d "$target_dir" ]]; then
  echo "'$target_dir' is not a directory"
fi

cd "$target_dir"
template_name="$(basename "$(pwd)")"

coder templates push "${template_name}" --variable namespace=workspaces -y
