#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-shared

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

   # specifying TRIVY_DB_REPOSITORY as workaround for TOOMANYREQUESTS
   # see https://github.com/aquasecurity/trivy/discussions/7668#discussioncomment-10884984
   docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock:ro \
      -v "$trivy_cache_dir:/root/.cache/" \
      -e "GITHUB_TOKEN=${TRIVY_GITHUB_TOKEN:-${GITHUB_TOKEN:-}}" \
      -e "TRIVY_DB_REPOSITORY=ghcr.io/aquasecurity/trivy-db,public.ecr.aws/aquasecurity/trivy-db" \
      -e "TRIVY_JAVA_DB_REPOSITORY=ghcr.io/aquasecurity/trivy-java-db,public.ecr.aws/aquasecurity/trivy-java-db" \
      aquasec/trivy image --no-progress \
         --severity HIGH,CRITICAL \
         --exit-code 0 \
         $image_name

   docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock:ro \
      -v "$PWD/.trivyignore":/.trivyignore \
      -v "$trivy_cache_dir:/root/.cache/" \
      -e "GITHUB_TOKEN=${TRIVY_GITHUB_TOKEN:-${GITHUB_TOKEN:-}}" \
      -e "TRIVY_DB_REPOSITORY=ghcr.io/aquasecurity/trivy-db,public.ecr.aws/aquasecurity/trivy-db" \
      -e "TRIVY_JAVA_DB_REPOSITORY=ghcr.io/aquasecurity/trivy-java-db,public.ecr.aws/aquasecurity/trivy-java-db" \
      aquasec/trivy image --no-progress \
         --severity HIGH,CRITICAL \
         --ignore-unfixed \
         $([[ -f "$PWD/.trivyignore" ]] && echo "--ignorefile /.trivyignore" || true) \
         --exit-code 1 \
         $image_name

   sudo chown -R $USER:$(id -gn) "$trivy_cache_dir" || true
else
   log WARN "Skipping scan of image [$image_name] on Windows..."
fi
