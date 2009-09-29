#!/bin/sh
#
# 2009/Sep/05 @ Zdenek Styblik
#
# Simple back-up script for backing-up from misc openwrt devices
# all around the network
#
# This script is being called from back-up server via ssh
# Place this at node which should be backed-up along with file 
# '2backup.txt' which is full-path list of files/dirs to back-up
#
# License? What?! Who would have use this crap anyway?! :)
#

LIST=''
for item in `cat 2backup.txt`; do
	LIST="${LIST} ${item}";
done

tar czf - ${LIST} 2>/dev/null

exit 0

