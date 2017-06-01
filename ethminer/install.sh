#!/bin/bash
set -e

_BASENAME=$(basename $0)
_DIRNAME=$(dirname $0)
_FULLPATH=$(readlink -f $_DIRNAME)

[[ $EUID -ne 0 ]] && echo "[${_BASENAME}] ERROR: Only root can execute this script" && exit 1

[ $(getent group ether) ] || addgroup ether -gid 1111
[ $(getent passwd ethminer) ] || useradd -b /home -m -N -g ether -u 2222 ethminer

mkdir ${_FULLPATH}/.ethash
ln -s ${_FULLPATH}/.ethash ~ethminer/.ethash
chown ethminer:ether ${_FULLPATH}
chown ethminer:ether ${_FULLPATH}/*
chown ethminer:ether ${_FULLPATH}/.*
chmod 2755 ${_FULLPATH}

chown root:root $0
chmod 540 $0

add-apt-repository -y ppa:ethereum/ethereum-qt
add-apt-repository -y ppa:ethereum/ethereum
apt-get update
apt-get -y install cpp-ethereum
# Make sure we dont spin trying to access non-exist GPUs
ethminer --list-devices 2>&1 | grep "modprobe: ERROR" && udevadm control --stop-exec-queue

