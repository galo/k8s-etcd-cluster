#!/bin/bash
#####################################################################
#
# Building all docker images from all containers in project
#
# Usage: 
# 	1. list images with versions (tags) in etc/gce-docker-images
# 	2. Configure etc/socius-docker.conf with the repo name
#	3. Launch this file 
# 
# Maintainer: Samuel Cozannet <samuel.cozannet@madeden.com> 
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

# Check install Google Cloud SDK 
gce::lib::switch_project

# Build Docker Images
# find "${MYDIR}/.." -name "Dockerfile" > /tmp/socius-docker
# while read LINE ; do
for PROJECT in ${DOCKER_PROJECTS}; do
	docker::lib::build_project "${MYDIR}/../containers/${PROJECT}"

	DOCKER_NAME=$(cat "${MYDIR}/../containers/${PROJECT}/package.json" | jq '.name' | tr -d '"')
	DOCKER_VERSION=$(cat "${MYDIR}/../containers/${PROJECT}/package.json" | jq '.version' | tr -d '"')

	docker::lib::push_to_gke_registry "${PROJECT_ID}/${DOCKER_NAME}:${DOCKER_VERSION}"
done

# Cleaning up
rm -r /tmp/socius-docker

