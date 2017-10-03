#!/bin/bash
_DIRNAME=$(dirname $0)
_BASENAME=$(basename $0)

[ ! -O "${0}" ] && echo "[${_BASENAME}] ERROR: Only owner of this script can execute it" && exit 1

_IP=$(ip addr show | grep -v 'inet 127.0.0.1' | grep 'inet ' | sed -e 's#^.*inet ##g' -e 's#/.*##g')
_MASTER=http://${_IP}:3009

positive_percentage='^[1-9][0-9]{0,1}$'

while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
                -h|--help)
                echo "USAGE:"
                echo "  $0 [options]"
                echo ""
                echo "OPTIONS:"
		echo "  -F,--farm <url>    Put into mining farm mode with the work server at URL (default: ${_MASTER})"
                echo "  -l, --cpulimit <n> Percentage limit (1-100) of CPU for ethminer to use; requires cpulimit package"
                echo "  -h, --help         This message"
                exit 1
                ;;
                -F|--farm)
                _MASTER="$2"
                shift
                ;;
                -l|--cpulimit)
                _CPULIMIT=$2
		_CPUTHREADS=1
                ! [[ "${_CPULIMIT}" =~ $positive_percentage ]] && echo "[${_BASENAME}] ERROR: --cpulimt must be an integer percentage between 1 and 100: [${_CPULIMIT}]" && exit 1
		shift
                ;;
        esac
        shift
done

_TODAY=$(date --iso-8601)
_IP_LAST=$(echo ${_IP} | sed -e 's#.*\.\([0-9]*\)#\1#g')
_LOGBASE=${_DIRNAME}/logs/${_TODAY}
_LOGFILEC=${_IP}-C.log

mkdir -p ${_LOGBASE}
chmod g+w ${_LOGBASE}

_CMD_EXTRA="--farm-recheck 200"
[ "$_CPUTHREADS" = "" ] && _CPUTHREADS=$(($(cat /proc/cpuinfo | grep "^processor" | tail -5 | head -2 | tail -1 | sed -e "s#proc.*:.##g") + 1))
echo "[${_BASENAME}][INFO] Limiting CPU usage to ${_CPUTHREADS} threads" | tee ${_LOGBASE}/${_LOGFILEC}

_CMD="-F ${_MASTER} --disable-submit-hashrate"
_CMDC="ethminer -C -t ${_CPUTHREADS} ${_CMD_EXTRA} ${_CMD} &>> ${_LOGBASE}/${_LOGFILEC} &"

echo "[${_BASENAME}] Running [${_CMDC}] ..." | tee ${_LOGBASE}/${_LOGFILEC}
eval "${_CMDC}"
_PIDC=$!
#_PIDC=$(ps -ef | grep '[e]thminer -C' | awk '{print $2}')
sleep 2

echo "[${_BASENAME}] Child PIDs: CPU:[${_PIDC}]" | tee -a ${_LOGBASE}/${_LOGFILEC}

mv ${_LOGBASE}/${_LOGFILEC} ${_LOGBASE}/${_PIDC}_${_LOGFILEC}
if [ "$_CPULIMIT" != "" ]; then
	echo "[${_BASENAME}][INFO] Limiting CPU usage to ${_CPULIMIT}% ..." | tee ${_LOGBASE}/${_PIDC}_${_LOGFILEC}
	cpulimit -l ${_CPULIMIT} -b -p ${_PIDC}
fi
echo "[${_BASENAME}] Logfile: [${_LOGBASE}/${_PIDC}_${_LOGFILEC}]"

exit 0
