#!/bin/bash
_DIRNAME=$(dirname $0)
_BASENAME=$(basename $0)

[ ! -O "${0}" ] && echo "[${_BASENAME}] ERROR: Only owner of this script can execute it" && exit 1

_TODAY=$(date --iso-8601)
_IP=$(ip addr show eth0 | grep 'inet ' | sed -e 's#^.*inet ##g' -e 's#/.*##g')
_IP_LAST=$(echo ${_IP} | sed -e 's#.*\.\([0-9]*\)#\1#g')
_LOGBASE=${_DIRNAME}/logs/${_TODAY}
_LOGFILEC=${_IP}-C.log

_MASTER=http://${_IP}:8545
if [ "$1" != "" ]; then
_MASTER=${1}
fi
mkdir -p ${_LOGBASE}
chmod g+w ${_LOGBASE}

_CMD_EXTRA="--no-precompute --farm-recheck 1000"
_CPUTHREADS=$(($(cat /proc/cpuinfo | grep "^processor" | tail -5 | head -2 | tail -1 | sed -e "s#proc.*:.##g") + 1))

_CMD="-F ${_MASTER} --disable-submit-hashrate"
_CMDC="ethminer -C -t ${_CPUTHREADS} ${_CMD_EXTRA} ${_CMD} &>> ${_LOGBASE}/${_LOGFILEC} &"

echo "[${_BASENAME}] Running [${_CMDC}] ..." | tee ${_LOGBASE}/${_LOGFILEC}
eval "${_CMDC}"
_PIDC=$(ps -ef | grep '[e]thminer -C' | awk '{print $2}')
sleep 2

echo "[${_BASENAME}] Child PIDs: CPU:[${_PIDC}]" | tee -a ${_LOGBASE}/${_LOGFILEC}

exit 0
