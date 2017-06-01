#!/bin/bash
set -e

_BASENAME=$(basename $0)
_DIRNAME=$(dirname $0)

[[ $EUID -ne 0 ]] && echo "[${_BASENAME}] ERROR: Only root can execute this script" && exit 1

[ $(getent group ether) ] || addgroup ether -gid 1111
[ $(getent passwd ethminer) ] || useradd -b /home -m -N -g ether -u 2222 ethminer

chown ethminer:ether ${_DIRNAME}
chown ethminer:ether ${_DIRNAME}/*
chmod 2755 ${_DIRNAME}

chown root:root $0
chmod 540 $0

add-apt-repository -y ppa:ethereum/ethereum-qt
add-apt-repository -y ppa:ethereum/ethereum
apt-get update
apt-get -y install cpp-ethereum
# Make sure we dont spin trying to access non-exist GPUs
ethminer --list-devices 2>&1 | grep "modprobe: ERROR" && udevadm control --stop-exec-queue

