#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-shared

# shellcheck source=SCRIPTDIR/../lib/bash-init.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bash-init.sh"

image_name=${1:?Usage: $0 IMAGE_NAME}


#################################################
# perform security audit using https://github.com/aquasecurity/trivy
#################################################
if [[ "$OSTYPE" == cygwin* || "$OSTYPE" == msys* ]]; then
   log WARN "Skipping scan of image [$image_name] on Windows..."
   exit 0
fi

log INFO "Scanning [$image_name]..."

# Prepare Trivy cache directory
trivy_cache_dir="${TRIVY_CACHE_DIR:-$HOME/.trivy/cache}"
trivy_cache_dir="${trivy_cache_dir/#\~/$HOME}"
mkdir -p "$trivy_cache_dir"

# choose Trivy image based on environment
if [[ -n ${GITHUB_ACTIONS:-} ]]; then
  trivy_image="ghcr.io/aquasecurity/trivy"
else
  trivy_image="aquasec/trivy"
fi

# Specifying TRIVY_DB_REPOSITORY as workaround for TOOMANYREQUESTS
# see https://github.com/aquasecurity/trivy/discussions/7668#discussioncomment-10884984
export GITHUB_TOKEN=${TRIVY_GITHUB_TOKEN:-${GITHUB_TOKEN:-}}
trivy_args=(
  --rm
  -v /var/run/docker.sock:/var/run/docker.sock:ro
  -v "$trivy_cache_dir:/root/.cache/"
  -e GITHUB_TOKEN
  -e "TRIVY_DB_REPOSITORY=ghcr.io/aquasecurity/trivy-db,public.ecr.aws/aquasecurity/trivy-db"
  -e "TRIVY_JAVA_DB_REPOSITORY=ghcr.io/aquasecurity/trivy-java-db,public.ecr.aws/aquasecurity/trivy-java-db"
  "$trivy_image" image --no-progress --severity "HIGH,CRITICAL"
)

# 1) Initial scan (non-failing)
(set -x; docker run "${trivy_args[@]}" --exit-code 0 "$image_name")

# 2) Failing scan with ignore-unfixed (and optional .trivyignore)
trivy_ignore_args=(--ignore-unfixed)
if [[ -f "$PWD/.trivyignore" ]]; then
  trivy_args=("-v" "$PWD/.trivyignore:/tmp/.trivyignore:ro" "${trivy_args[@]}")
  trivy_ignore_args+=(--ignorefile "/tmp/.trivyignore")
fi
(set -x; docker run "${trivy_args[@]}" "${trivy_ignore_args[@]}" --exit-code 1 "$image_name")

# Ensure cache ownership for user
sudo chown -R "$USER:$(id -gn)" "$trivy_cache_dir" || true
