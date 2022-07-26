#!/usr/bin/env bash
#
# Copyright 2021-2022 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#

set -eu

#################################################
# execute script with bash if loaded with other shell interpreter
#################################################
if [ -z "${BASH_VERSINFO:-}" ]; then /usr/bin/env bash "$0" "$@"; exit; fi

set -o pipefail


#################################################
# configure logging/error reporting
#################################################
trap 'rc=$?; echo >&2 "$(date +%H:%M:%S) Error - exited with status $rc in [$BASH_SOURCE] at line $LINENO:"; cat -n $BASH_SOURCE | tail -n+$((LINENO - 3)) | head -n7' ERR

# if TRACE_SCRIPTS=1 or  TRACE_SCRIPTS contains a glob pattern that matches $0
if [[ ${TRACE_SCRIPTS:-} == "1" || ${TRACE_SCRIPTS:-} == "$0" ]]; then
   if [[ $- =~ x ]]; then
      # "set -x" was specified already, we only improve the PS4 in this case
      PS4='+\033[90m[$?] $BASH_SOURCE:$LINENO ${FUNCNAME[0]}()\033[0m '
   else
      # "set -x" was not specified, we use a DEBUG trap for better debug output
      set -T

      __trace() {
         if [[ ${FUNCNAME[1]} == "log" && ${BASH_SOURCE[1]} == ${BASH_SOURCE[0]} ]]; then
            # don't log internals of log() function
            return
         fi
         printf "\e[90m#[$?] ${BASH_SOURCE[1]}:$1 ${FUNCNAME[1]}() %*s\e[35m%s\e[m\n" "$(( 2 * ($BASH_SUBSHELL + ${#FUNCNAME[*]} - 2) ))" "$BASH_COMMAND" >&2
      }
      trap '__trace $LINENO' DEBUG
   fi
fi

function log() {
   # to prefix stdout and stderr of a command: the_command 2> >(log ERROR >&2) | log INFO &
   level=${1:-INFO}
   level=${level^^}
   case $level in
      INFO|WARN|ERROR) ;;
      *) log ERROR "Unsupported log-level $level"; exit 1 ;;
   esac

   prefix="$(date "+%Y-%m-%d %H:%M:%S") $level [${BASH_SOURCE[1]}:$BASH_LINENO]"
   if [ -p /dev/stdin ]; then
      while read line; do
         echo "$prefix $line"
      done
   else
      echo "$prefix ${@:2}"
   fi
}

function interpolate() {
   # Bash based envsubst (https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html)
   # based on https://stackoverflow.com/a/40167919
   # USAGE: interpolated=$(interpolate < template.file)
   local line lineEscaped
   while IFS= read -r line || [ -n "$line" ]; do  # the `||` clause ensures that the last line is read even if it doesn't end with \n
      # escape all chars that could trigger an expansion
      IFS= read -r lineEscaped < <(echo "$line" | tr '`([$' '\1\2\3\4')
      # selectively re-enable ${ references
      lineEscaped=${lineEscaped//$'\4'{/\${}
      # escape back slashes to preserve them
      lineEscaped=${lineEscaped//\\/\\\\}
      # escape embedded double quotes to preserve them
      lineEscaped=${lineEscaped//\"/\\\"}
      eval "printf '%s\n' \"$lineEscaped\"" | tr '\1\2\3\4' '`([$'
   done
}
