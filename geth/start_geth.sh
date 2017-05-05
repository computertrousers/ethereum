#!/bin/bash
set -e

_BASENAME="$(basename $0)"
_DIRNAME="$(dirname $0)"
_ALLARGS="$@"

[ ! -O "${0}" ] && echo "[${_BASENAME}] ERROR: Only owner of this script can execute it" && exit 1

# common regex
positive_percentage='^[1-9][0-9]{0,1}$'
single_digit='^[0-9]$'
double_digit='^[0-9]{1,2}$'
valid_port='^[1-6][0-9][0-9][0-9]{1,2}$'

# default properties
_CLUSTERID=0
_NODEID=0
_RPCBASEPORT=3000
_BASEPORT=4000
_INTERFACE=eth0
cpulimit_limit=
geth_commands=

while [[ $# -gt 0 ]]; do
	key="$1"
	case $key in
		-h|--help)
		echo "USAGE:"
		echo "	$0 [options] [geth arguments....] "
		echo ""
		echo "OPTIONS:"
		echo "	-c, --clusterid	value	Cluster id, 0-9 (default = ${_CLUSTERID}); numbered directory under ${_DIRNAME}"
		echo "	-n, --nodeid	value	Node id, 0-99 (default = ${_NODEID}); numbered directory under relevant cluster"
		echo "	-a, --address	label	Network interface to accept incomming connections on (default = ${_INTERFACE})"
		echo "	-p, --baseport	value	Start of port range for inter-node connection (default = ${_BASEPORT})"
		echo "	-r, --rpcbase	value	Start of port range for RPC connection (default = ${_RPCBASEPORT})"
#		echo "	-l, --cpulimit	value	Percentage limit (1-100) of CPU for geth to use; requires cpulimit package"
		echo "	-i, --init		Initialise a new node; will overwrite previous version if it exists"
		echo "	-g, --genesis	file	Genesis file to bootstrap a new cluster; ignored in favour of cluster file if it already exists"
		echo ""
		echo "This script will optionally (-i) create a new node along with a the relevant cluster if it does not already exist.  It will then spin up the node using the start.sh script created in the node directory.  The enode string for each new node will be added to a static nodes file in the cluster directory and if existing nodes are restarted they will pick up these changes.  The ports used are calculated as:"
		echo ""
		echo "(100 * clusterid) + nodeid + base"
		echo ""
		echo "Additional geth arguments can be included anywhere on the command line.  For example, to enable worldwide RPC access add --netrestrict 0.0.0/0 --rpccorsdomain '*' (or something more prescriptive if you can!) and if you plan to connect miners to the node you will need to set --etherbase."
		echo ""
		echo "You may rename any cluster or node directory to add a meaningfull suffix (e.g. cluster-0-test, node-1-master) but be sure to leave the prefix unchanged."
		exit 1
		;;
		-i|--init)
		geth_commands=init
		;;
		-c|--clusterid)
		_CLUSTERID="$2"
		! [[ "${_CLUSTERID}" =~ $single_digit ]] && echo "[${_BASENAME}] ERROR: ---clusterid must be an integer between 0 and 9: [${_CLUSTERID}]" && exit 1
		shift
		;;
		-n|--nodeid)
		_NODEID="$2"
		! [[ "${_NODEID}" =~ $double_digit ]] && echo "[${_BASENAME}] ERROR: --nodeid must be an integer between 0 and 99: [${_NODEID}]" && exit 1
		shift
		;;
		-r|--rpcbase)
		_RPCBASEPORT="$2"
		! [[ "${_RPCBASEPORT}" =~ $valid_port ]] && echo "[${_BASENAME}] ERROR: --rpcbaseport must be an integer between 1024i and 65535: [${_RPCBASEPORT}]" && exit 1
		shift
		;;
		-p|--baseport)
		_BASEPORT="$2"
		! [[ "${_BASEPORT}" =~ $valid_port ]] && echo "[${_BASENAME}] ERROR: --baseport must be an integer between 1024 and 65535: [${_BASEPORT}]" && exit 1
		shift
		;;
		-l|--cpulimit)
		_cpulimit_limit="$2"
		! [[ "${_cpulimit_limit}" =~ $positive_percentage ]] && echo "[${_BASENAME}] ERROR: --cpulimt must be an integer percentage between 1 and 100: [${_cpulimit_limit}]" && exit 1
		shift
		;;
		-g|--genesis)
		_GENESIS="$2"
		[ ! -r ${_GENESIS} ] && echo "[${_BASENAME}] ERROR: Genesis file does not exist: [${_GENESIS}]" && exit 1
		shift
		;;
		-a|--interface)
		_INTERFACE="$2"
		shift
		;;
		--netrestrict)
		geth_netrestrict="${2}"
		shift
		;;
		--rpcaddr)
		geth_rpcaddr="${2}"
		shift
		;;
		*)
		geth_user_args="${geth_user_args} ${1}"
		;;
	esac
	shift
done

let geth_networkid=${_CLUSTERID}*10+9990
let geth_rpcport=${_CLUSTERID}*100+${_NODEID}+${_RPCBASEPORT}
let geth_port=${_CLUSTERID}*100+${_NODEID}+${_BASEPORT}

_CLUSTERDIR=$(find ${_DIRNAME} -name "cluster-${_CLUSTERID}*" -type d)
[ "${_CLUSTERDIR}" != "" ] && geth_datadir=$(find ${_CLUSTERDIR} -name "node-${_NODEID}*" -type d)
_CLUSTERDIR=${_CLUSTERDIR:=${_DIRNAME}/cluster-${_CLUSTERID}}
geth_datadir=${geth_datadir:=${_CLUSTERDIR}/node-${_NODEID}}
_CLUSTERGENESIS="${_CLUSTERDIR}/genesis.json"
_STATICNODES="${_CLUSTERDIR}/static-nodes.json"

_NODENAME="cluster-${_CLUSTERID}-node-${_NODEID}"
_LOGFILE="${_NODENAME}.log"
_IPCIDR="$(ip addr show ${_INTERFACE} | grep 'inet ' | sed -e 's#^.*inet ##g' -e 's# brd .*##g')"
[ "${geth_netrestrict}" == "" ] && geth_netrestrict="${_IPCIDR}"
[ "${geth_rpcaddr}" == "" ] && geth_rpcaddr="$(echo ${_IPCIDR} | sed -e 's#/.*##g')"
STATICLOCAL="${geth_datadir}/static-nodes.json"

geth_ethereum_args="--networkid ${geth_networkid} --identity ${_NODENAME}"
#geth_api_args="--rpc --rpcaddr ${geth_rpcaddr} --rpcport ${geth_rpcport} --rpcapi db,eth,net,web3 --ipcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3"
geth_api_args="--rpc --rpcaddr ${geth_rpcaddr} --rpcport ${geth_rpcport}"
geth_network_args="--nodiscover --port ${geth_port}"
geth_security_args="--netrestrict ${geth_netrestrict} -nat any"

echo "[${_BASENAME}] Running with args: [${_ALLARGS}]" | tee ${_LOGFILE}
if [ "$geth_commands" = "init" ]; then
	if [ ! -d "${_CLUSTERDIR}" ]; then
		echo "[${_BASENAME}] Cluster directory[${_CLUSTERDIR}] does not exist; creating ..." | tee -a ${_LOGFILE}
		if [ "${_GENESIS}" == "" ]; then
			echo "[${_BASENAME}] ERROR: Genesis file rquired for new cluster; re-run command with -g parameter" | tee -a ${_LOGFILE}
			exit 1
		fi
		mkdir -p ${_CLUSTERDIR}
		cp ${_GENESIS} ${_CLUSTERGENESIS}
		echo "	Copied supplied genesis file [${_GENESIS}] to cluster: [${_CLUSTERGENESIS}]" | tee -a ${_LOGFILE}
		echo "[" > ${_STATICNODES}
		echo "]" >> ${_STATICNODES}
		echo "	Created static nodes file in cluster: [${_STATICNODES}]" | tee -a ${_LOGFILE}
	fi
	echo "[${_BASENAME}] Initialising new node: [${geth_datadir}] ..." | tee -a ${_LOGFILE}
	if [ -d "$geth_datadir" ]; then
		echo "	Found existing copy of node [${geth_datadir}]; deleting ..." | tee -a ${_LOGFILE}
		rm -rf "${geth_datadir}"
	fi
	mkdir -p "$geth_datadir"
	echo "	Created new node directory: [${geth_datadir}]" | tee -a ${_LOGFILE}
		
	_CMDSTRING="geth --datadir ${geth_datadir} ${geth_ethereum_args} ${geth_api_args} ${geth_network_args} ${geth_user_args} --netrestrict ${_IPCIDR} init ${_CLUSTERGENESIS}"
	echo "	Using cluster level genesis file: [${_CLUSTERGENESIS}]" | tee -a ${_LOGFILE}
	echo "	Running geth command ..." | tee -a ${_LOGFILE}
	echo "${_CMDSTRING}" | tee -a ${_LOGFILE}
	if ! (${_CMDSTRING}); then
		echo "[${_BASENAME}] ERROR: command did not exit cleanly: [${_CMDSTRING}]; you may need to remove the cluster genesis file to fix: [${_CLUSTERGENESIS}]" | tee -a ${_LOGFILE}
		exit 2
	fi

	_CMDSTRING="geth --verbosity 0 --exec admin.nodeInfo --datadir ${geth_datadir} ${geth_ethereum_args} ${geth_network_args} --netrestrict ${_IPCIDR} console"
	echo "[${_BASENAME}] Running transient geth console [${_CMDSTRING}] to discover enode string ..." | tee -a ${_LOGFILE}
	ENODE=$( $_CMDSTRING | grep "enode://" | sed -e "s#.*enode://#enode://##g" -e "s#\[::\]#${geth_rpcaddr}#g" -e "s#[\",]*##g")
	if [ "${ENODE}" == "" ]; then
		echo "[${_BASENAME}] ERROR: Cannot establish enode of [${_NODENAME}]" | tee -a ${_LOGFILE}
		exit 10
	else
		if grep -q "enode://.*:${geth_port}" "${_STATICNODES}"; then
			echo "[${_BASENAME}] Removing existing enode entry for this node from static nodes file: [${_STATICNODES}] ..." | tee -a ${_LOGFILE}
			sed -i "s#enode://.*:${geth_port}#NEWNODE#g" ${_STATICNODES}
		else
			sed -i "s#]##g" ${_STATICNODES} 
			grep -Fq "enode://" "${_STATICNODES}" && echo -n ", " >> ${_STATICNODES}
			echo "\"NEWNODE\"" >> ${_STATICNODES}
			echo "]" >> ${_STATICNODES}
		fi
		echo "[${_BASENAME}] Adding enode [${ENODE}] to static nodes file: [${_STATICNODES}] ..." | tee -a ${_LOGFILE}
		sed -i "s#NEWNODE#${ENODE}#g" ${_STATICNODES}
	fi
fi

if [ ! -d "$geth_datadir" ]; then
	echo "[${_BASENAME}] ERROR: Data directory [$geth_datadir] does not exist; rerun with following command to create:" | tee -a ${_LOGFILE}
	echo "	${0} ${_ALLARGS} -i" | tee -a ${_LOGFILE}
	exit 3;
fi

echo "[${_BASENAME}] Found matching node in [${geth_datadir}]; running its start script ..." | tee -a ${_LOGFILE}

_OLDLOGFILE=${_LOGFILE}
_LOGFILE="${geth_datadir}/${_NODENAME}.log"
mv -f ${_OLDLOGFILE} ${_LOGFILE}

geth_args="${geth_ethereum_args} ${geth_api_args} ${geth_network_args} ${geth_security_args} ${geth_user_args}"
cat ${_DIRNAME}/template/start.template | sed -e "s#=:geth_args:#=\"${geth_args}\"#g" -e "s#=:geth_port:#=${geth_port}#g" > ${geth_datadir}/start.sh
chmod +x ${geth_datadir}/start.sh

exec ${geth_datadir}/start.sh


