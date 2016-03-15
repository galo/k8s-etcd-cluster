#!/bin/bash
#####################################################################
#
# This script deploys a 3 node etcd service on GKE for Couchbase
#
# Notes:
#   *
#
# Maintainer: Samuel Cozannet <samuel@blended.io>, http://blended.io 
#
#####################################################################

# Validating I am running on debian-like OS
[ -f /etc/debian_version ] || {
	echo "We are not running on a Debian-like system. Exiting..."
	exit 0
}

# Load Configuration
MYNAME="$(readlink -f "$0")"
MYDIR="$(dirname "${MYNAME}")"

for file in $(find ${MYDIR}/../etc -name "*.conf") $(find ${MYDIR}/../lib -name "*lib*.sh" | sort) ; do
    echo Sourcing ${file}
    source ${file}
    sleep 1
done 

#  Setup
gce::lib::switch_project

gce::lib::switch_gke_cluster "${APP_CLUSTER_ID}"

# Create discovery URL for etcd cluster
bash::lib::log debug Creating a discovery URL for etcd
bash::lib::ensure_cmd_or_install_package_apt curl curl
ETCD_DISCOVERY_URL=""

while [ "x${ETCD_DISCOVERY_URL}" = "x" ]; do
	ETCD_DISCOVERY_URL="$(curl -s ${ETCD_URL} -d "size=${APP_CLUSTER_SIZE}")"
	bash::lib::log debug Found URL "${ETCD_DISCOVERY_URL}"
	sleep 1
done

ETCD_VERSION=$(cat "${MYDIR}/../containers/etcd/package.json" | jq '.version' | tr -d '"')

# Note we are using a different pattern in sed as the URL can contain slashes.
for UNIT_TYPE in seed unit; do
	sed -e s,ETCD_DISCOVERY_URL,"${ETCD_DISCOVERY_URL}",g \
		-e s,PROJECT_ID,"${PROJECT_ID}",g \
		-e s,DEFAULT_REGISTRY,"${DEFAULT_REGISTRY}",g \
		-e s,ETCD_VERSION,"${ETCD_VERSION}",g \
		${MYDIR}/../rc/etcd-"${UNIT_TYPE}".controller.json.template > ${MYDIR}/../tmp/etcd-"${UNIT_TYPE}".controller.json
	echo ${MYDIR}/../tmp/etcd-"${UNIT_TYPE}".controller.json >> ${MYDIR}/../${TMP_FILES}
done

bash::lib::log debug Using ${ETCD_CLUSTER_ID} as cluster name

# Create the pods for etcd
kubectl create -f "${MYDIR}/../tmp/etcd-seed.controller.json" \
	1>/dev/null 2>/dev/null \
	&& bash::lib::log info Successfully created etcd seed replication controller \
	|| bash::lib::die Could not create etcd seed replication controller

# Create the service for etcd
kubectl create -f "${MYDIR}/../services/etcd.service.json" \
	1>/dev/null 2>/dev/null \
	&& bash::lib::log info Successfully created etcd service \
	|| bash::lib::die Could not create etcd service

while [ "$(kubectl describe service etcd-service | grep "LoadBalancer Ingress" | wc -l)" = "0" ]; do
	bash::lib::log info Service etcd-service not ready. Waiting.
	sleep 10;
done

# Now we need to add the etcd additional nodes and kill the seed
kubectl create -f "${MYDIR}/../tmp/etcd-unit.controller.json" \
	1>/dev/null 2>/dev/null \
	&& bash::lib::log info Successfully created etcd unit replication controller \
	|| bash::lib::die Could not create etcd unit replication controller

# Let's wait a little bit until containers are running
bash::lib::log debug Sleeping a little bit to let containers spin
sleep 20

# Now we get rid of our seed nodes and leave only the scale out
kubectl delete rc etcd-seed-controller \
	1>/dev/null 2>/dev/null \
	&& bash::lib::log info Successfully deleted etcd seed replication controller \
	|| bash::lib::die Could not delete etcd seed replication controller

# Setting the IP Address for the the cluster discovery (couchbase deployment)
export CLUSTER_ETCD_SERVICE_SERVICE_HOST="$(kubectl describe service etcd-service | grep "LoadBalancer Ingress" | cut -f2 -d":" | tr -d '\t')"
export CLUSTER_ETCD_SERVICE_SERVICE_PORT_CLIENT="2379"
bash::lib::log debug Found etcd Service Ingress Load Balancer at ${CLUSTER_ETCD_SERVICE_SERVICE_HOST} on port ${CLUSTER_ETCD_SERVICE_SERVICE_PORT_CLIENT}
bash::lib::log debug Cluster version is $(curl -sL http://${CLUSTER_ETCD_SERVICE_SERVICE_HOST}:${CLUSTER_ETCD_SERVICE_SERVICE_PORT_CLIENT}/version)
