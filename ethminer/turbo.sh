#!/bin/bash
_DIRNAME=$(dirname $0)
_BASENAME=$(basename $0)

[[ $# -lt 2 ]] && echo "[${_BASENAME}] USAGE: $0 <pid> <logfile> [<cpulimit>]" && exit 1

_CPULIMIT=$(($(cat /proc/cpuinfo | grep "^processor" | tail -5 | head -2 | tail -1 | sed -e "s#proc.*:.##g") *100 + 80))
[ "${3}" != "" ] && _CPULIMIT=${3}
echo "_CPULIMIT=[$_CPULIMIT]"

nohup tail -f ${2} 2>&1 | grep --line-buffered "Pooled new future transaction" | while read line ; do timeout 20s cpulimit -l $_CPULIMIT -p ${1} ; done &

exit 0
