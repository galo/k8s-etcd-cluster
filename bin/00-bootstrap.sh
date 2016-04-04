#!/bin/bash
#####################################################################
#
# Initialize Socius Live environment
#
# Notes: 
#   * GCloud Disk Doc: https://cloud.google.com/compute/docs/disks/#comparison_of_disk_types
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
MYCONF="${MYDIR}/../etc/project.conf"

if [ $(grep "YOUR_PROJECT_NAME" "${MYCONF}" | wc -l ) -eq 1 ]
then
    echo "You did not set your project in etc/project.conf. Please do and restart"
    # exit 0
fi

for file in $(find ${MYDIR}/../etc -name "*.conf") $(find ${MYDIR}/../lib -name "*lib*.sh" | sort) ; do
    echo Sourcing ${file}
    source ${file}
    sleep 1
done 

# Check if we are sudoer or not
if [ $(bash::lib::is_sudoer) -eq 0 ]; then
    bash::lib::die "You must be root or sudo to run this script"
fi

[ ! -d "${MYDIR}/../tmp" ] && mkdir "${MYDIR}/../tmp"
echo "" > "${MYDIR}/../tmp/tmp_files"

# Check install of all dependencies
bash::lib::ensure_cmd_or_install_package_apt jq jq
bash::lib::ensure_cmd_or_install_package_apt awk awk
 # This is to install json (node)
bash::lib::ensure_cmd_or_install_package_apt node nodejs npm
sudo ln -sf /usr/bin/nodejs /usr/local/bin/node
bash::lib::ensure_cmd_or_install_package_npm json json
bash::lib::ensure_cmd_or_install_package_npm yaml2json yaml2json
bash::lib::ensure_cmd_or_install_package_npm json2yaml json2yaml
# sudo npm install json

# Check install Google Cloud SDK 
gce::lib::ensure_gcloud_or_install
bash::lib::log debug ready to start...

gce::lib::switch_project

# Create a small k8s cluster on GKE
gcloud container clusters create -q "${APP_CLUSTER_ID}" \
    --num-nodes "${APP_CLUSTER_SIZE}" \
    --quiet \
    --machine-type "${DEFAULT_MACHINE_TYPE}" \
    2>/dev/null 1>/dev/null \
    && bash::lib::log info GKE Cluster Created \
    || bash::lib::die Could not create GKE Cluster

sleep 5

# Use this cluster & set creds for k8s
gce::lib::switch_gke_cluster "${APP_CLUSTER_ID}" 

# Finish
bash::lib::log info Bootstrap finished. You can now install the application

