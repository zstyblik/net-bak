#!/bin/sh
# Desc:
# ---
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
# ---
# 2009/Sep/05 @ Zdenek Styblik
# 
# License? What?! Who would have use this crap anyway?! :)
#
set -e
set -u

DATE=$(date +%F)
PREFIX='./'
VERSION='0.3'
NODESFILE="nodes2backup.txt"
SSHOPTS=" -oPubkeyAuthentication=yes -oPasswordAuthentication=no"
NOTIFY="root@localhost"

# Desc: Adds node to back-up
addnode() {
	NODENAME=${1:-''}
	if [ -z "${NODENAME}" ]; then
		echo "[FAIL] No nodename given."
		return 1
	fi

	if ! $(printf "${NODENAME}" | \
		grep -q -E -e '^[a-zA-Z]+[a-zA-Z0-9\_\.\-]+[a-zA-Z0-9]+$'); then
		printf "[FAIL] Nodename '%s' is invalid."
		return 1
	fi

	if [ -d "${NODENAME}" ]; then
		printf "[WARN] Directory '%s' already exists." "${NODENAME}"
		while true; do
			printf "Keep previous config and add node to nodelist only? [y/n]: "
			read -n 1 ANSWER
			if [ "${ANSWER}" = "y" ] || [ "${ANSWER}" = "n" ]; then
				break
			fi
			printf "\n"
		done
		if [ "${ANSWER}" = "n" ]; then
			if ! $(grep -q -e "${NODENAME}" "${NODESFILE}") ; then
				printf "[INFO] Adding node '%s' to list of nodes.\n"
				printf "%s\n" "${NODENAME}" >> "${NODESFILE}"
			fi
			return 0
		fi
	fi

	printf "Node FQDN/IP address: "
	read NODEIP

	while true; do
		printf "Is node running WhiteRussian? [y/n]: "
		read -n 1 NODEWR
		if [ "${NODEWR}" = "y" ] || [ "${NODEWR}" = "n" ]; then
			break
		fi
		printf "\n"
	done


	printf "Contact person in case of back-up failure.\n"
	printf "Space separated list of e-mails.\n"
	printf "Contact anybody? [e-mail]: "
	read NODEADMIN

	rm -rf "${NODENAME}"
	mkdir "${NODENAME}"

	if [ ! -e "${NODESFILE}" ]; then
		cat /dev/null > "${NODESFILE}"
	fi
	if ! $(grep -q -e "${NODENAME}") ; then
		printf "%s\n" "${NODENAME}" >> "${NODESFILE}"
	fi
	printf "NODEIP='%s'\n" "${NODEIP}" > "${NODENAME}/.node"
	printf "NODEADMIN='%s'\n" "${NODEADMIN}" >> "${NODENAME}/.node"
	printf "NODEWR='%s'\n" "${NODEWR}" >> "${NODENAME}/.node"
	return 0
} # addnode()
# Desc: back-up only one node
backupnode() {
	NODENAME=${1:-''}
	if [ -z "${NODENAME}" ]; then
		echo "[FAIL] parameter NODENAME is empty."
		return 1
	fi
	if [ ! -r "${PREFIX}${NODENAME}/.node" ]; then
		printf "[FAIL] File '%s/.node' not found\n" "${NODENAME}"
		return 1;
	fi
	#
  . "${PREFIX}${NODENAME}/.node"
	NODEIP=${NODEIP:-''}
	NODEADMIN=${NODEADMIN:-''}
	NODEWR=${NODEWR:-'n'}
	if [ -z "${NODEIP}" ]; then
		echo "[FAIL] Node IP address not set."
		return 1
	fi
	RC=0
	ssh ${SSHOPTS} -l root "${NODENAME}" 'ls -la net-bak-node.sh' || RC=$?
	case "${RC}" in
		1)
			printf "[INFO] Back-up scripts probably not present at '%s'\n" \
				"${NODENAME}"
			printf "[INFO] Trying to copy 'net-bak-node.sh' to '%s'.\n" \
				"${NODENAME}"
			scp net-bak-node.sh root@${NODENAME}:
			printf "[INFO] Trying to copy 'files2backup.txt' to '%s'.\n" \
				"${NODENAME}"
			scp files2backup.txt root@${NODENAME}:
			;;
		255)
			printf "[FAIL] Node '%s' seems to be unavailable!\n" "${NODENAME}"
			return 1
			;;
		0)
			;;
		*)
			printf "[FAIL] Unexpected RC, node '%s'\n" "${NODENAME}"
			return 1
			;;
	esac

	BAKFILE=$(random_suffix "${PREFIX}${NODENAME}/${NODENAME}-${DATE}.tar.gz")
	if [ -z "${BAKFILE}" ]; then
		echo "[FAIL] BAKFILE is empty. Randomization failed."
		return 2
	fi
	umask 0377
	RC=0
	while true; do
		ssh ${SSHOPTS} -l root "${NODEIP}" \
			'sh net-bak-node.sh' > "${BAKFILE}" || \
			RC=$?
		case "${RC}" in
			0)
				break
				;;
			100)
				printf "[INFO] SCP-ing 'files2backup.txt' to node '%s'.\n" \
					"${NODENAME}"
				scp files2backup.txt root@${NODENAME}:
				;;
			255)
				printf "[FAIL] Connection to node '%s' failed w/ RC '%i'\n" \
					"${NODENAME}" "${RC}"
				break
				;;
			*)
				printf "[FAIL] Unexpected RC '%i' for node '%s'.\n" \
					"${RC}" "${NODENAME}"
				break
				;;
		esac
	done
	if [ -e "${BAKFILE}" ] && [ ! -s "${BAKFILE}" ]; then
		printf "[WARN] It's most likely back-up of node '%s' has failed.\n" \
			"${NODENAME}"
		printf "[WARN] Back-up file '%s' has zero length.\n" "${BAKFILE}"
		printf "[WARN] Please, investigate.\n"
	fi
	# Node is still running WhiteRussian -> back up NVRAM.
	if [ "${NODEWR}" = 'y' ]; then
		NVRAMFILE=$(random_suffix "${PREFIX}${NODENAME}/${NODENAME}-${DATE}.nvram")
		if [ -z "${NVRAMFILE}" ]; then
			echo "[FAIL] NVRAMFILE empty. Randomization failed."
			return 2
		fi
		RC=0
		ssh ${SSHOPTS} -l root ${NODEIP} '/usr/sbin/nvram show' \
			> "${NVRAMFILE}" || RC=$?
		if [ "${RC}" -ne 0 ]; then
			printf "[FAIL] Running 'net-bak-node.sh' at '%s' ended with RC '%i'.\n" \
				"${NODENAME}" "${RC}"
		fi
	fi
	return 0
} # backupnode()
# Desc: back-up all nodes
backupnodes() {
	if [ ! -r "${PREFIX}${NODESFILE}" ]; then
		echo "[FAIL] File '${NODESFILE}' doesn't exist or couldn't be read."
		exit 1;
	fi
	if [ ! -d ./logs ]; then
		mkdir logs
	fi
	LOGFILEPART="./logs/backup-${DATE}.log"
	COUNTER=0
	while [ COUNTER -lt 100 ]; do
		LOGFILE="${LOGFILEPART}.${COUNTER}"
		if [ ! -e "${LOGFILE}" ]; then
			break
		fi
	done
	exec > "${LOGFILE}"
	for NODENAME in $(cat "${PREFIX}${NODESFILE}" | grep -v -e '^#'); do
		backupnode "${NODENAME}"
	done
	cat "${LOGFILE}" | mailx -s "Back-up status on ${DATE}" "${NOTIFY}"
} # backupnodes()
# Desc: removes node from list of nodes to back up
deletenode() {
	NODENAME=${1:-''}
	while true; do
		printf "Do not back-up node '%s' anymore? [y/n]: "
		read -n 1 ANSWER
		if [ "${ANSWER}" = "y" ] || [ "${ANSWER}" = "n" ]; then
			break;
		fi
	done
	if [ "${ANSWER}" = "n" ]; then
		printf "[PASS] Ok, exitting.\n"
		exit 0
	fi
	cp "${NODESFILE}" "${NODESFILE}.bak"
	sed -e "s/${NODENAME}//g" "${NODESFILE}.bak" > "${NODESFILE}"
	return 0
} # deletenode()
# Desc: generate unique back-up filename.
# If file doesn't exist yet, return filename. Otherwise loop and randomize.
random_suffix() {
	FILE=${1:-''}
	if [ -z "${FILE}" ]; then
		return 1
	fi
	if [ ! -e "${FILE}" ]; then
		echo "${FILE}"
		return 0
	fi
	FILENEW="${FILE}"
	while [ -e "${FILENEW}" ]; do
		RANDOM="$(dd if=/dev/urandom count=1 2> /dev/null | cksum | cut -f1 -d' ')"
		FILENEW="${FILE}.${RANDOM}"
	done
	echo "${FILENEW}"
	return 0
} # random_suffix()
# Desc: shows help text
show_help() {
	printf "\n"
	printf "net-bak v%s\n" "${VERSION}"
	printf "Usage: \n"
	printf " -1 <node>\tback-up specified [one] node\n"
	printf " -a\t\tback-up all nodes\n"
	printf " -d <node>\tdo not backup node anymore\n"
	printf " -h\t\tshows help\n"
	printf " -n <node>\tadd new node to backup\n"
	printf " -t\t\ttest connection to nodes\n"
	printf "\n"
	return 0
} # show_help()
# Desc: try to connect to nodes.
test_nodes() {
	if [ ! -e "${NODESFILE}" ]; then
		printf "[FAIL] File '%s' doesn't exist." "${NODESFILE}"
		return 1
	fi
	for NODENAME in $(cat "${NODESFILE}"); do
		if [ ! -e "${PREFIX}${NODENAME}/.node" ]; then
			printf "[FAIL] File '%s' doesn't exist.\n" "${PREFIX}${NODENAME}/.node"
			continue
		fi
		. "${PREFIX}${NODENAME}/.node"
		NODEIP=${NODEIP:-''}
		if [ -z "${NODEIP}" ]; then
			printf "[FAIL] NODEIP not set for node '%s'.\n" "${NODENAME}"
			continue
		fi
		RC=0
		ssh ${SSHOPTS} -l root "${NODENAME}" 'ls >/dev/null' || RC=$?
		if [ ${RC} -eq 0 ]; then
			printf "[PASS] ssh to node '%s' returned 0.\n"
		else
			printf "[FAIL] ssh to node '%s' returned '%i'.\n" "${NODENAME}" "${RC}"
		fi
	done
	return 0
} # test_nodes()
while getopts 1:ahn:t OPT; do
	case "${OPT}" in
		'1')
			backupnode "${OPTARG}"
			;;
		'a')
			backupnodes
			;;
		'h')
			show_help
			;;
		'n')
			new_node "${OPTARG}"
			;;
		't')
			test_nodes
			;;
		\?)
			echo "Unknown option."
			show_help
			exit 1
			;;
		*)
			show_help
			exit 1
			;;
	esac
done
