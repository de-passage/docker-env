#!/usr/bin/env bash 

set -euo pipefail

docker build -t git.sylvainleclercq.com/depassage/ci-node-docker:22-bookworm -f forgejo/Dockerfile forgejo/
docker push git.sylvainleclercq.com/depassage/ci-node-docker:22-bookworm
