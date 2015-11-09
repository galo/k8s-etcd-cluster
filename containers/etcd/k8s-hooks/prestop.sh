#!/bin/bash
#####################################################################
#
# This script delete this node (container) from the etcd cluster
# it belongs to.
# 
# Maintainer: Samuel Cozannet <samuel@blended.io>, http://blended.io 
#
#####################################################################

#NODE_ID=$(curl -sL -XGET "${X_ETCD_DISCOVERY}" \
#	| jq -c '.node.nodes[] | select(.value | contains('''\"${HOSTNAME}\"''')) | .key' \
#	| tr -d '\"' \
#	| cut -f 4- -d'/')
NODE_ID=$(etcdctl member list | grep "${HOSTNAME}" | cut -f1 -d":")
X_ETCD_DATA_DIR="/opt/etcd/var/data"


until [ "x${DELETION_TEST}" = "x100" ]
do
	# echo "x${DELETION_TEST}"	
	# curl -sL -XDELETE "${X_ETCD_DISCOVERY}/${NODE_ID}"
	etcdctl member remove "${NODE_ID}" \
		&& DELETION_TEST=100 \
		|| DELETION_TEST=0

	# sleep 3
	# DELETION_TEST="$(curl -sL ${X_ETCD_DISCOVERY}/${NODE_ID} | jq '.errorCode')"
	# sleep 2
done

rm -rf "${X_ETCD_DATA_DIR}/*"

exit 0