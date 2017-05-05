#!/bin/bash
_DIRNAME=$(dirname $0)
add-apt-repository -y ppa:ethereum/ethereum-qt
add-apt-repository -y ppa:ethereum/ethereum
apt-get update
apt-get -y install cpp-ethereum
# Make sure we dont spin trying to access non-exist GPUs
ethminer --list-devices 2>&1 | grep "modprobe: ERROR" && udevadm control --stop-exec-queue

