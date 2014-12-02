# README file for net-bak:

net-bak is a set of very simple scripts for backing-up OpenWRT devices over
the network.

## Requirements

* ssh ~ at server
* mailx ~ at server
* tar ~ at OpenWRT node


## How-to use it

1. run ``% net-bak.sh -n mynode;`` and answer questions
2. upload user's key, files2backup.txt, net-bak-node.sh to node
3. you may test configuration either by:
  3. running ``% net-bak.sh -t;`` which is going to try to connect to node
  3. running ``% net-bak.sh -1 mynode;`` which is going to try to backup given node
4. set-up cron for given user


## Directory structure:

```
\
|- mynode
|  `- .node
|- logs
|  `- logfile-date.log
|
|- files2backup.txt
|- net-bak-node.sh
|- net-bak.sh
`- nodes2backup.txt
```

* files2backup.txt ~ files to back-up from node
* net-bak-node.sh ~ upload this script to node; executed via SSH
* net-bak.sh ~ main script executed at server
* nodes2backup.txt ~ list of names of nodes which corresponds with dir struct.


## .node file

Structure:
```shell
NODEIP='1.2.3.4'
NODEWR='n'
NODEADMIN='root@domain.tld'
```

* NODEIP ~ IP address or FQDN of the node
* NODEWR ~ whether node is running OpenWRT White Russian or not
* NODEADMIN ~ whom to contact in case of problems (unused)
