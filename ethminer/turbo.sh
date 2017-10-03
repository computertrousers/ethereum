#!/bin/bash
_DIRNAME=$(dirname $0)
_BASENAME=$(basename $0)

[ ! -O "${0}" ] && echo "[${_BASENAME}] ERROR: Only owner of this script can execute it" && exit 1

[[ $# -lt 2 ]] && echo "[${_BASENAME}] USAGE: $0 <pid> <logfile>" && exit 1

nohup tail -f ${2} 2>&1 | grep --line-buffered "Pooled new future transaction" | while read line ; do timeout 20s cpulimit -l 150 -p ${1} ; done &

exit 0
