#!/bin/bash
set -e

_BASENAME=$(basename $0)
_DIRNAME=$(dirname $0)

[[ $EUID -ne 0 ]] && echo "[${_BASENAME}] ERROR: Only root can execute this script" && exit 1

[ $(getent group ether) ] || addgroup ether -gid 1111
[ $(getent passwd geth) ] || useradd -b /home -m -N -g ether -u 2221 geth

chown geth:ether ${_DIRNAME}
chown geth:ether ${_DIRNAME}/*
chmod 2755 ${_DIRNAME}

chown root:ubuntu $0
chmod 540 $0

apt-get -y install software-properties-common
add-apt-repository -y ppa:ethereum/ethereum
apt-get update
apt-get -y install ethereum
