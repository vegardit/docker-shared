#!/usr/bin/env bash
#
# Copyright 2021-2022 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#

source $(dirname $0)/../lib/bash-init.sh

image_name=$1


#################################################
# perform security audit using https://github.com/aquasecurity/trivy
#################################################
if [[ $OSTYPE != cygwin ]] && [[ $OSTYPE != msys ]]; then
   log INFO "Scanning [$image_name]..."
   trivy_cache_dir="${TRIVY_CACHE_DIR:-$HOME/.trivy/cache}"
   trivy_cache_dir="${trivy_cache_dir/#\~/$HOME}"
   mkdir -p "$trivy_cache_dir"

   docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock:ro \
      -v "$PWD/.trivyignore":/.trivyignore \
      -v "$trivy_cache_dir:/root/.cache/" \
      -e "GITHUB_TOKEN=${TRIVY_GITHUB_TOKEN:-${GITHUB_TOKEN:-}}" \
      aquasec/trivy image --no-progress \
         --severity HIGH,CRITICAL \
         --exit-code 0 \
         $image_name

   docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock:ro \
      -v "$PWD/.trivyignore":/.trivyignore \
      -v "$trivy_cache_dir:/root/.cache/" \
      -e "GITHUB_TOKEN=${TRIVY_GITHUB_TOKEN:-${GITHUB_TOKEN:-}}" \
      aquasec/trivy image --no-progress \
         --severity HIGH,CRITICAL \
         --ignore-unfixed \
         --ignorefile /.trivyignore \
         --exit-code 1 \
         $image_name

   sudo chown -R $USER:$(id -gn) "$trivy_cache_dir" || true
else
   log WARN "Skipping scan of image [$image_name] on Windows..."
fi
