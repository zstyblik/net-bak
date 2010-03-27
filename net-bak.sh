#!/bin/sh
#
# 2009/Sep/05 @ Zdenek Styblik
#
# Simple back-up script for backing-up from misc openwrt devices
# all around the network
# 
# nodes2backup:
# - the list of nodes to backup
# - lines beginning with '#' are ignored
#
# It doesn't have to be executed as a root user.
# It's being executed from back-up server.
# It relies on ssh-key auth
# 
# License? What?! Who would have use this crap anyway?! :)
#
# ToDo:
# - backup of single node

DATE=`date +%F`
PREFIX=''
VERSION='0.2'

backupnode() {
	NODENAME=$1
	if [ ! -r ${PREFIX}${NODENAME}/.node ]; then
		echo "$NODENAME/.node not found"
#   config not found
#   echo it ?
		return 10;
	fi
# import ip, etc.
  source ${PREFIX}${NODENAME}/.node
	SUFFIX=''
	while [ -e ${PREFIX}${NODENAME}/${NODENAME}-${DATE}.tar.gz${SUFFIX} ]; 
	do
		SUFFIX='.'$RANDOM;
	done
	BAKFILE=${PREFIX}${NODENAME}/${NODENAME}-${DATE}.tar.gz${SUFFIX}
	umask 0377
	ssh root@${NODEIP} sh net-bak-node.sh > $BAKFILE
	if [ -e $BAKFILE ] && [ ! -s $BAKFILE ]; then
		echo "It's most likely back-up of node ${NODENAME} has failed."
		echo "Back-up file ${NODENAME}-${DATE}.tar.gz${SUFFIX} has "
		echo "zero length."
		echo "Please, investigate.";
	fi
# if node is still running 
# WhiteRussian, then connect again and back it up too.
	if [ -z $NODEWR ]; then
		echo "var NODEWR is not set"
		NODEWR="n"
	fi;
	if [ $NODEWR == 'y' ]; then
#   I admit. Suffix here is a bit of unpredictable
		ssh root@${NODEIP} /usr/sbin/nvram show > \
		${PREFIX}${NODENAME}/${NODENAME}-${DATE}.nvram${SUFFIX}
	fi;
}

backupnodes() {
	if [ ! -r "${PREFIX}nodes2backup" ]; then
		echo "File 'nodes2backup' doesn't exist or couldn't be read."
		echo "Terminating"
		exit 1;
	fi

	for NODENAME in `cat ${PREFIX}nodes2backup | grep -v '^#'`; do
		backupnode $NODENAME
	done
}

help() {
	echo "Net-bak v$VERSION";
	echo "Usage: "
	echo "-1 <node>	back-up specified [one] node"
	echo "-a		back-up all nodes"
	echo "-h		this help"
	echo
}

case $1 in
	-1)
		backupnode $2
		;;
	-a)
		backupnodes
		;;
	-h)
		help
		;;
	*)
		help
		;;
esac
