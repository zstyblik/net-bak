#!/bin/sh
# Desc:
# ---
# This script is being called from back-up server via ssh
# Place this at node which should be backed-up along with file 
# '2backup.txt' which is full-path list of files/dirs to back-up
# ---
# 2009/Sep/05 @ Zdenek Styblik
#
# Simple back-up script for backing-up from misc openwrt devices
# all around the network
#
# License? What?! Who would have use this crap anyway?! :)
#

FILESTOBAK="files2backup.txt"

if [ ! -e "${FILESTOBAK}" ]; then
	exit 100
fi

cat "${FILESTOBAK}" | tr '\n' ' ' | xargs tar czf - 2>/dev/null

exit 0

