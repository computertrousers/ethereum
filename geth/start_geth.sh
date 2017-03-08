#!/bin/bash
set -e

_BASENAME="$(basename $0)"
_DIRNAME="$(dirname $0)"
_ALLARGS="$@"

# common regex
positive_percentage='^[1-9][0-9]{0,1}$'
single_digit='^[0-9]$'
double_digit='^[0-9]{1,2}$'
valid_port='^[1-6][0-9][0-9][0-9]{1,2}$'

# default properties
_CLUSTERID=0
_NODEID=0
_RPCBASEPORT=60000
_BASEPORT=50000
_INTERFACE=eth0
cpulimit_limit=
geth_commands=

while [[ $# -gt 0 ]]; do
	key="$1"
	case $key in
		-h|--help)
		echo "USAGE:"
		echo "	$0 [options] [geth arguments....] "
		echo "OPTIONS:"
		echo "	--clusterid, -c	value	Cluster id, 0-9 (defaultr = ${_CLUSTERID}); numbered directory under ${_DIRNAME}"
		echo "	--nodeid, -n	value	Node id, 0-99 (default =${_NODEID}); numbered directory under relevant cluster"
		echo "	--init, -i		Initialise a new node; will overwrite previous version if it exists;"
		echo "				Requires genesis file to be supplied (-g option) if first node of a cluster"
		echo "	--genesis, -g	file	Genesis file to bootstrap a new cluster; ignored if cluster already exists"
		echo "	--address, -a	label	Network interface to accept incomming connections on (default = ${_INTERFACE})"
		echo "	--baseport, -p	value	Start of port range for inter-node connection"
		echo "	--rpcbase, -r	value	Start of port range for RPC connection"
		echo "	--cpulimit, -l	value	Percentage limit (1-100) of CPU for geth to use; requires cpulimit package"
		echo ""
		echo "This script will optionally (-init) create a new node along with a new cluster if no nodes have"
		echo "previously been created.  It will always spin up the node. The ports used are calculated as:"
		echo "(100 * clusterid) + nodeid + base"
		echo ""
		echo "Additional geth arguments can be included anywhere on the command line.  For example, to enable"
		echo "worldwide RPC access add --netrestrict 0.0.0/0 --rpccorsdomain '*' (or something more prescriptive"
		echo "if you can!)"
		echo ""
		echo "You may rename any cluster or node directory to add a meaningfull suffix (e.g. cluster-0-test, node-1-master)"
		echo "but be sure to leave the prefix unchanged."
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

_NODENAME="Geth-Cluster${_CLUSTERID}-Node${_NODEID}"
_LOGFILE="${_NODENAME}.log"
_IPCIDR="$(ip addr show ${_INTERFACE} | grep 'inet ' | sed -e 's#^.*inet ##g' -e 's# brd .*##g')"
[ "${geth_netrestrict}" == "" ] && geth_netrestrict="$(echo ${_IPCIDR} | sed -e 's#[0-9]\{1,3\}\.[0-9]\{1,3\}/..#0.0/16#g')"
[ "${geth_rpcaddr}" == "" ] && geth_rpcaddr="$(echo ${_IPCIDR} | sed -e 's#/.*##g')"
STATICLOCAL="${geth_datadir}/static-nodes.json"

geth_ethereum_args="--datadir ${geth_datadir} --networkid ${geth_networkid} --identity ${_NODENAME}"
geth_api_args="--rpc --rpcaddr ${geth_rpcaddr} --rpcport ${geth_rpcport} --rpcapi db,eth,net,web3 --ipcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3"
geth_network_args="--nodiscover --port ${geth_port}"
geth_security_args="--netrestrict ${geth_netrestrict} -nat any"

echo "[${_BASENAME}] Running with args: [${_ALLARGS}]" | tee ${_LOGFILE}
if [ "$geth_commands" = "init" ]; then
	if [ ! -d "${_CLUSTERDIR}" ]; then
		echo "${_BASENAME}] Cluster directory[${_CLUSTERDIR}] does not exist; creating ..." | tee -a ${_LOGFILE}
		if [ "${_GENESIS}" == "" ]; then
			echo "[${_BASENAME}] ERROR: Genesis file rquired for new cluster; re-run command with -g parameter" | tee -a ${_LOGFILE}
			exit 1
		fi
		mkdir -p ${_CLUSTERDIR}
		cp ${_GENESIS} ${_CLUSTERGENESIS}
		echo "	Copied supplied genesis file [${_GENESIS}] to cluster: [${_CLUSTERGENESIS}]" | tee -a ${_LOGFILE}
		echo "[" > ${_STATICNODES}
		echo "	Created static nodes file in cluster: [${_STATICNODES}]" | tee -a ${_LOGFILE}
	fi
	echo "[${_BASENAME}] Initialising new node: [${geth_datadir}] ..." | tee -a ${_LOGFILE}
	if [ -d "$geth_datadir" ]; then
		echo "	Found existing copy of node [${geth_datadir}]; deleting ...]" | tee -a ${_LOGFILE}
		rm -rf "${geth_datadir}"
	fi
	mkdir -p "$geth_datadir"
	echo "	Created new node directory: [${geth_datadir}]" | tee -a ${_LOGFILE}
		
	ln -s -r -f ${_STATICNODES} ${STATICLOCAL}
	echo "	Linked local static nodes file [${STATICLOCAL}] to cluster: [${_STATICNODES}]" | tee -a ${_LOGFILE}

	_CMDSTRING="geth ${geth_ethereum_args} ${geth_api_args} ${geth_network_args} ${geth_user_args} --netrestrict ${_IPCIDR} init ${_CLUSTERGENESIS}"
	echo "	Using cluster level genesis file: [${_CLUSTERGENESIS}]" | tee -a ${_LOGFILE}
	echo "	Running geth command ..." | tee -a ${_LOGFILE}
	echo "${_CMDSTRING}" | tee -a ${_LOGFILE}
	if ! (${_CMDSTRING}); then
		echo "[${_BASENAME}] ERROR: command did not exit cleanly: [${_CMDSTRING}]; you may need to remove the cluster genesis file to fix: [${_CLUSTERGENESIS}]" | tee -a ${_LOGFILE}
		exit 2
	fi
fi

if [ ! -d "$geth_datadir" ]; then
	echo "[${_BASENAME}] ERROR: Data directory [$geth_datadir] does not exist; rerun with following command to create:" | tee -a ${_LOGFILE}
	echo "	${0} ${_ALLARGS} -i" | tee -a ${_LOGFILE}
	exit 3;
fi
echo "[${_BASENAME}] Found matching node in [${geth_datadir}]; continuing ..." | tee -a ${_LOGFILE}

_OLDLOGFILE=${_LOGFILE}
_LOGFILE="${geth_datadir}/${_NODENAME}.log"
mv -f ${_OLDLOGFILE} ${_LOGFILE}

_CMDSTRING="geth ${geth_ethereum_args} ${geth_api_args} ${geth_network_args} ${geth_security_args} ${geth_user_args} &>> ${_LOGFILE} &"

echo "[${_BASENAME}] Running transient geth console [geth --verbosity 0 --exec admin.nodeInfo --datadir ${geth_datadir} console] to discover enode string ..." | tee -a ${_LOGFILE}
ENODE=$(geth --verbosity 0 --exec admin.nodeInfo ${geth_ethereum_args} ${geth_network_args} --netrestrict ${_IPCIDR} console | grep "enode://" | sed -e "s#.*enode://#enode://##g" -e "s#\[::\]#${geth_rpcaddr}#g" -e "s#[\",]*##g")
if [ "${ENODE}" == "" ]; then
	echo "[${_BASENAME}] ERROR: Cannot establish enode of [${_NODENAME}]" | tee -a ${_LOGFILE}
	exit 10
else
	if grep -Fq "${ENODE}" "${_STATICNODES}"; then
		echo "[${_BASENAME}] Found existing enode [${ENODE}] in static nodes file: [${_STATICNODES}]; nothing more to do" | tee -a ${_LOGFILE}
	else
		echo "[${_BASENAME}] Adding enode [${ENODE}] to static nodes file: [${_STATICNODES}] ..." | tee -a ${_LOGFILE}
		sed -i "s#]##g" ${_STATICNODES} 
		grep -Fq "enode://" "${_STATICNODES}" && echo "," >> ${_STATICNODES}
		echo "\"${ENODE}\"" >> ${_STATICNODES}
		echo "]" >> ${_STATICNODES}
	fi
fi
echo "[${_BASENAME}] Running GETH command ..." | tee -a ${_LOGFILE}
echo "${_CMDSTRING}" | tee -a ${_LOGFILE}

eval "$_CMDSTRING" 

echo "[${_BASENAME}] SUCCESS; Geth output available in [$_LOGFILE]"
