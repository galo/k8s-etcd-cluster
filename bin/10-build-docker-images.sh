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
MYVOLUMESDIR="${MYDIR}/../volumes"

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
for PROJECT in ${NODE_PROJECTS}; do
	docker::lib::build_node_project "${MYDIR}/../containers/${PROJECT}"

	DOCKER_NAME=$(cat "${MYDIR}/../containers/${PROJECT}/package.json" | jq '.name' | tr -d '"')
	DOCKER_VERSION=$(cat "${MYDIR}/../containers/${PROJECT}/package.json" | jq '.version' | tr -d '"')

	docker::lib::push_to_gke_registry "${PROJECT_ID}/${DOCKER_NAME}:${DEFAULT_OS}-${DOCKER_VERSION}"

	# DOCKER_NAME="$(readlink -f "${LINE}")"
	# DOCKER_DIR="$(dirname "${DOCKER_NAME}")"
	# DOCKER_IMAGE="$(basename "${DOCKER_NAME}")"
	# DOCKER_VERSION="$(grep "LABEL" "${DOCKER_NAME}" | grep "version" | cut -f2 -d"=" | tr -d "\"")"
	# DOCKER_APP="$(grep "LABEL" "${DOCKER_NAME}" | grep "app" | cut -f2 -d"=" | tr -d "\"")"

	# # Checking if that image is already managed
	# AM_I="$(grep "${DOCKER_APP}" "${MYDIR}/../etc/${IMAGE_LIST}" | wc -l)" 

	# if [ "${AM_I}" = "0" ]; then
	# 	bash::lib::log debug Adding ${DOCKER_APP} to the list of managed images
	# 	echo "${DOCKER_APP}=${DOCKER_VERSION}" | tee -a "${MYDIR}/../etc/${IMAGE_LIST}"
	# 	LAST_VERSION=""
	# else
	# 	LAST_VERSION="$(grep "${DOCKER_APP}" "${MYDIR}/../etc/${IMAGE_LIST}" | cut -f2 -d'=')" 
	# fi

	# if [ "${LAST_VERSION}" != "${DOCKER_VERSION}" ]; then
	# 	bash::lib::log debug Building ${DOCKER_IMAGE}
	# 	cd "${DOCKER_DIR}"
	# 	echo docker build -t "${DOCKER_APP}-${DOCKER_VERSION}" .	
	# 	cd -
	# 	sed -i s/^"${DOCKER_APP}=${LAST_VERSION}"/"${DOCKER_APP}=${DOCKER_VERSION}"/ "${MYDIR}/../etc/${IMAGE_LIST}"
	# fi
done #< /tmp/socius-docker

# Cleaning up
rm -r /tmp/socius-docker

