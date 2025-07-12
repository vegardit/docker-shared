#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-shared

# shellcheck source=SCRIPTDIR/../lib/bash-init.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bash-init.sh"

echo "#################################################"
echo "Installing latest OS updates..."
echo "#################################################"
apt-get update
# https://github.com/phusion/baseimage-docker/issues/319
apt-get install --no-install-recommends -y apt-utils 2> >( grep -v 'debconf: delaying package configuration, since apt-utils is not installed' >&2 || true)
apt-get upgrade -y
