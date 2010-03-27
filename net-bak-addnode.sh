#!/bin/sh
#
# 2009/Sep/06 @ Zdenek Styblik
#
# adds node to the list, make directory $NODENAME and create config
#
# License? What?! Who would have use this crap anyway?! :)
#

echo -n "Enter name of the node: "
read NODENAME

UPDATE=0
if [ -d ${NODENAME} ]; then
	CHOICE='foobar'
  echo "Directory ${NODENAME} already exists"
	while true; do
    echo -n "Continue and overwrite settings? [n/y]: "
	  read -n 1 CHOICE
		if [ -z ${CHOICE} ]; then
			echo
			continue
		fi
		if [ ${CHOICE} == "n" ] || [ ${CHOICE} == "y" ]; then
		  break;
		fi
	done
  if [ ${CHOICE} == "n" ]; then
		echo
    echo "Terminating"
    exit 2;
  fi
	UPDATE=1
fi

echo -n "Node IP address: "
read NODEIP
echo "Contact person in case of back-up failure"
echo "Space separated list of e-mails"
echo -n "Contact anybody? [e-mail]: "
read NODEADMIN
echo -n "Is node running WhiteRussian? [y/n]: "
read NODEWR
if [ ! -z $NODEWR ]; then
	case $NODEWR in
		y)
		;;
		n)
		;;
		*): NODEWR="n"
		;;
	esac
 if [ $NODEWR != "y" ] || [ $NODEWR != "n" ]; then
	NODEWR="n"
 fi
else
	NODEWR="n";
fi

if [ $UPDATE -eq 0 ]; then
  mkdir ${NODENAME}
  echo ${NODENAME} >> nodes2backup;
fi
echo "NODEIP=${NODEIP}" > ${NODENAME}/.node
echo "NODEADMIN='${NODEADMIN}'" >> ${NODENAME}/.node
echo "NODEWR='${NODEWR}'" >> ${NODENAME}/.node

