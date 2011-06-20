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
PREFIX="./"
VERSION='0.3'
NODESFILE="nodes2backup.txt"
SSHOPTS="-oPubkeyAuthentication=yes -oPasswordAuthentication=no"
NOTIFY="root@localhost"

# Desc: back-up all nodes
backup_everything() {
	if [ ! -r "${PREFIX}${NODESFILE}" ]; then
		echo "[FAIL] File '${NODESFILE}' doesn't exist or couldn't be read."
		exit 1;
	fi
	if [ ! -d "${PREFIX}/logs" ]; then
		mkdir "${PREFIX}/logs"
	fi
	LOGFILEPART="${PREFIX}/logs/backup-${DATE}.log"
	COUNTER=0
	while [ $COUNTER -lt 1000 ]; do
		LOGFILE="${LOGFILEPART}.${COUNTER}"
		if [ ! -e "${LOGFILE}" ]; then
			break
		fi
		COUNTER=$(($COUNTER+1))
	done
	if [ -e "${LOGFILE}" ]; then
		printf "[FAIL] Unable to create logfile."
		exit 1
	fi
	exec > "${LOGFILE}"
	for NODENAME in $(cat "${PREFIX}${NODESFILE}" | grep -v -e '^#'); do
		backup_node "${NODENAME}" || true
	done
	cat "${LOGFILE}" | mailx -s "Back-up status on ${DATE}" "${NOTIFY}"
} # backup_everything()
# Desc: back-up only one node
backup_node() {
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
	SSHOUT=$(ssh ${SSHOPTS} -l root "${NODEIP}" 'ls -la net-bak-node.sh' 2>&1 || true)
	if $(printf "%s" "${SSHOUT}" | grep -q -e 'No route'); then
		printf "[FAIL] Node '%s' seems to be unavailable!\n" "${NODENAME}"
		return 1
	fi
	if $(printf "%s" "${SSHOUT}" | grep -q -e 'No such file'); then
		printf "[INFO] Back-up scripts probably not present at '%s'\n" \
			"${NODENAME}"
		printf "[INFO] Trying to copy 'net-bak-node.sh' to '%s'.\n" \
			"${NODENAME}"
		scp net-bak-node.sh root@${NODEIP}:
		printf "[INFO] Trying to copy 'files2backup.txt' to '%s'.\n" \
			"${NODENAME}"
		scp files2backup.txt root@${NODEIP}:
	fi

	BAKFILE=$(random_suffix "${PREFIX}${NODENAME}/${NODENAME}-${DATE}.tar.gz")
	if [ -z "${BAKFILE}" ]; then
		echo "[FAIL] BAKFILE is empty. Randomization failed."
		return 2
	fi
	umask 0377
	ssh ${SSHOPTS} -l root "${NODEIP}" \
		'sh net-bak-node.sh' > "${BAKFILE}" || RC=$?
	if [ ! -e "${BAKFILE}" ]; then
		printf "[FAIL] Backup for node '%s' failed.\n" "${NODENAME}"
	fi
	if [ -e "${BAKFILE}" ] && [ ! -s "${BAKFILE}" ]; then
		printf "[WARN] It's most likely back-up of node '%s' has failed.\n" \
			"${NODENAME}"
		printf "[WARN] Back-up file '%s' has zero length.\n" "${BAKFILE}"
		printf "[WARN] Please, investigate.\n"
	else
		BAKSIZE=$(stat --printf=%s "${BAKFILE}")
		printf "[PASS] Backup created for node '%s' of size %s bytes.\n" \
			"${NODENAME}" "${BAKSIZE}"
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
} # backup_node()
# Desc: removes node from list of nodes to back up
delete_node() {
	NODENAME=${1:-''}
	while true; do
		printf "Do not back-up node '%s' anymore? [y/n]: " "${NODENAME}"
		read -n 1 ANSWER
		printf "\n"
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
} # delete_node()
# Desc: Adds node to back-up
new_node() {
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
			printf "\n"
			if [ "${ANSWER}" = "y" ] || [ "${ANSWER}" = "n" ]; then
				break
			fi
		done
		if [ "${ANSWER}" = "y" ]; then
			if ! $(grep -q -e "${NODENAME}" "${NODESFILE}") ; then
				printf "[INFO] Adding node '%s' to list of nodes.\n" "${NODENAME}"
				printf "%s\n" "${NODENAME}" >> "${NODESFILE}"
			else
				printf "[INFO] Node '%s' already in list.\n" "${NODENAME}"
			fi
			return 0
		fi
	fi

	printf "Node FQDN/IP address: "
	read NODEIP

	while true; do
		printf "Is node running WhiteRussian? [y/n]: "
		read -n 1 NODEWR
		printf "\n"
		if [ "${NODEWR}" = "y" ] || [ "${NODEWR}" = "n" ]; then
			break
		fi
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
	if ! $(grep -q -e "${NODENAME}" "${NODESFILE}") ; then
		printf "%s\n" "${NODENAME}" >> "${NODESFILE}"
	fi
	printf "NODEIP='%s'\n" "${NODEIP}" > "${NODENAME}/.node"
	printf "NODEADMIN='%s'\n" "${NODEADMIN}" >> "${NODENAME}/.node"
	printf "NODEWR='%s'\n" "${NODEWR}" >> "${NODENAME}/.node"
	return 0
} # new_node()
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
	printf " -d <node>\tdo not backup node anymore\n"
	printf " -e\t\tback-up all nodes\n"
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
		ssh ${SSHOPTS} -l root "${NODEIP}" 'ls /etc/ >/dev/null' || RC=$?
		if [ ${RC} -eq 0 ]; then
			printf "[PASS] ssh to node '%s', IP '%s' returned 0.\n" \
				"${NODENAME}" "${NODEIP}"
		else
			printf "[FAIL] ssh to node '%s', IP '%s' returned '%i'.\n" \
				"${NODENAME}" "${NODEIP}" "${RC}"
		fi
	done
	return 0
} # test_nodes()

### MAIN ###

if [ $# -lt 1 ]; then
	show_help
	exit 1
fi

while getopts 1:d:ehn:t OPT; do
	case "${OPT}" in
		'1')
			backup_node "${OPTARG}"
			;;
		'd')
			delete_node "${OPTARG}"
			;;
		'e')
			backup_everything
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
		\*)
			show_help
			exit 1
			;;
	esac
done
