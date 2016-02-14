# Running an etcd cluster at scale in k8s
## Purpose

This project explains how to run an etcd cluster in Docker containers in a Kubernetes cluster. 

## Introduction

The first question a reader could have is "why?". k8s already provides an etcd service as part of the implementation. That is undeniable. However, the etcd cluster is part of the infrastructure layer of k8s, and is not available to the containers running as "guests". 
As a consequence, if you want to run an SOA and use a service registry, you are pretty stuck unless you build if yourself. There are quite a few choices around between Consul, etcd and so on. 

The reason we picked etcd in this context is that... k8s runs an etcd cluster. Using anything else would add one technology thus complexity to the design. 
Arguably Consul offers more options than etcd and especially an implementation of a DNS for units of service. However this a toolbox also offered by k8s, hence functionally speaking k8s + etcd will be similar to a separate Consul system. 

## Usage
### Cloning the repository

First you need to make sure you cloned this repo: 

	sudo apt-get update && sudo apt-get install git-core
	[ ! -d ~/src ] && mkdir -p ~/src
	cd ~/src
	git clone https://github.com/SaMnCo/k8s-etcd-cluster etcd
	cd etcd

### Selecting your version

Pick the branch matching the version you want to work with: 

	git checkout VERSION

where version can be 2.0.1, 2.2.5 or any other available in the branches. 

### Configuring Google Cloud Platform & project

First you need to create a project in your Google Cloud Platform, then configure the following settings in **etc/project.conf**: 

	# Project Settings
	PROJECT_ID=<PUT YOUR GCP PROJECT ID HERE>
	REGION=us-central1
	ZONE=${REGION}-f
	DEFAULT_MACHINE_TYPE="n1-standard-2"

	# Cluster Settings
	APP_CLUSTER_ID=<PUT YOUR K8S CLUSTER NAME HERE>
	APP_CLUSTER_SIZE=3

As you can imagine, the first part refers to where you want to deploy your GKE cluster. 

The second part is about specific informations about your GKE cluster itself. For the APP_CLUSTER_ID, we recommend using only alphanumerical values (and NO special characters) 

### Configuring the discovery URL for etcd

If you run your own etcd discovery cluster, you can point these scripts to it in the **etc/etcd.conf** file. 

By default this will use the etcd.discovery.io URL provided for free by CoreOS. 

### Bootstrapping

You just need to run the bootstrap script

	./bin/00-bootstrap.sh

**Note**: You need to be sudoer for this. Anyway the code will tell you if you can't run it. 

This will 

* Install all requirements for the whole project if needed
* Install the gcloud command line, and update it to the latest version if needed
* Create a new cluster on GKE using the provided settings
* Download the cluster credentials for the kubectl CLI

### Creating your own Docker Image

As you know, you should only docker with your close friends. Containers run with high privileges on the host machine, you should know what they intend to do. While this image is publicly available I encourage you do build it yourself, then upload it to your Google Account

	cd containers/etcd
	# This is where you review the code!! 
	docker build -q -t docker-etcd --force-rm=true .
	# Image gets built
	docker tag docker-etcd us.gcr.io/<PUT YOUR GCP PROJECT ID HERE>/etcd:VERSION
	gcloud docker push us.gcr.io/<PUT YOUR GCP PROJECT ID HERE>/etcd:VERSION
	cd ../..

### Deploying on your new GKE cluster

Run the second script

	./bin/01-deploy-etcd.sh

This will: 

* Create a discovery URL on the etcd.discovery.io service given (for free) by CoreOS (Thanks guys!), for an initial 3-node cluster
* Spin 3 "seed" containers using this URL in your previously spawned Kubernetes cluster
* Create a service Load Balancing URL on k8s
* After the service is up, spin 3 more "unit" containers that do not rely on the discovery URL anymore, but join the cluster by themselves
* Finally, kill the seed nodes

You now have a cluster that doesn't depend on the discovery anymore. It can scale up & down easily. 

### Destroying your environment

Just run ./bin/99-cleanup.sh to destroy the cluster and temporary files. Be warned that if you run something else  in your cluster, it will also be deleted. 

### Tips & Tricks

I have seen clusters where one node gets in permanent reboot state. You can just kill the container, and k8s will spin a fresh new image. There is a prestop script that unregisters the container from the cluster, hence you should be safe. Otherwise, the service will in any case only target running nodes so you won"t have issues. 

## Some details about the project architecture 

This project is the first of an attempt to standardize and make repeatable deployments of core components of infrastructure, at scale. 

We have a set of folders that will contain available resources for the project layed out as: 

	./
	├── bin
	├── containers
	├── doc
	├── etc
	├── lib
	├── rc
	└── services

Each folder has a role and will contain specific files. 

### Default folders

* **etc**: etc on Linux is used to store configuration of services and programs available on a machine. We'll use the same convention and store configuration files in this folder. 
* **bin**: again on linux bin is used to store executable. We'll also use this convention. The files in bin then will be executed in alphabetical order. To make it easy for the reader to run them, we will therefore prefix the names with a number on 2 digits (example: 00-bootstrap.sh). 
* **lib**: Libraries will be stored in this folder. This folder is meant to grow over time. For now we have 3 main libraries: 
  * bashlib regroups standard features from bash we want to abstract
  * gcelib is an abstraction of some Google Cloud Platform commands 
  * dockerlib is an abstraction of some basic Docker commands
* **doc**: for documentation

### Docker specific folders

* **containers** is used to store in separate folders all the containers Dockerfiles we might need, so that we can rebuild them at any point in time

### k8s specific folders

* **rc**: Here we will store json descriptions for all the replication controllers we will need to use in k8s. We can optionaly add a **pods** folder but prefer to use replication controllers with a replication set to 1. 
* **services**: will store all the service descriptions in use in the project as json files
* **secrets**: will store all secrets we will import in k8s as json files

# Docker image
## Architectural thoughts

There are several ways of spinning an etcd cluster. The requirement for spinning the cluster is that all nodes know about each other, so they can create a valid configuration. A common pattern found in the official documentation is to use an external discovery service, such as a pre-existing etcd node, or the official etcd.discovery.io service. 

By doing so, an admin would deliberately fix the number of etcd instances. If one of them was to die, k8s would then respin a new container, and point it to the discovery API. If the previous node was not removed properly, this could lead to a bad state of the cluster, and our new unit not being able to join the cluster. 

As a result, manual intervention would be required, which is exactly what we want to avoid. 

What we need to do is therefore make sure that our cluster doesn't rely on the external service when it's up & running, so that new units of service can join or leave the cluster without endangering the service. 

The idea is to use one of the default service patterns proposed by k8s in the documentation: first we create a "seed" service that contains X nodes of etcd that are part of the first cluster bootstrapped with the discovery service. Then we add units to the cluster and groups them under a secondary service which we call "unit". When the "unit" service has scale to 3 or more nodes, we destroy the first "seed" service. 
Any unit that gets added then joins the cluster using only k8s primitives, and is not aware of the discovery mechanim used to bootstrap the cluster. 
We end up with a scalable, HA service, completely autonomous and horizontally scalable (up & down). 

**Note**: This pattern is used in the Redis cluster implementation in the documentation. 

## Structure of the image
### Docker folder tree

.
├── Dockerfile
├── k8s-hooks
│   └── prestop.sh
└── start-etcd

### Dockerfile

We take the base from Phusion Base Image, which is an Ubuntu image reduced to its bare minimum. 

Then we install etcd following the guides, using an ENV variables to set the version (DOCKER_ETCD_VERSION, see below)

We then copy a startup script, and a pre-stop script. 

The prestop script is meant for the etcd node to unregister itself if it fails for some reason. 

**Note**: This hasn't proved very effective so far as the container seems to be killed before the script is run. Hopefully in the future this will work better from a k8s perspective. 

### Startup script

I found that using environment variables for Docker Containers that conflict with existing envs to be confusing, especially when they are not always set. In this case, I used the same names for variables as the default names in etcd, but prefixed them with X_

Note that many of the default etcd variables will be set in this document. Would you will to change the behavior of the image, you'd need to update this file. 

### Environment Variables

* DOCKER_ETCD_VERSION: As explained before the etcd version can be controled via DOCKER_ETCD_VERSION. It defaults to the branch version
* X_ETCD_DISCOVERY: This is a switch to tell the image that it needs to join an existing cluster, or that it is part of a seeding cluster. The admin shall give it either
  * a URL such as https://discovery.etcd.io/9b492c095380d442f56503174e584a2a:2379, pointing to a discovery URL on the free service by CoreOS;
  * Or a URL pointing to the etcd service within the kubernetes cluster. In our k8s case, this is hard coded in the service definition therefore to http://etcd-service.default.svc.cluster.local:2379


## Conclusion

This project shows how to deploy a scalable etcd cluster to GKE in a couple of simple steps. But it is actually something bigger than that. It shows the basic (yet implicit) practice in k8s to deploy a scalable service. 

Essentially we find that while many projects are scale out (or cloud native), the first node or nodes are effectively different from the next ones. They are "seed nodes", just there to initialize the cluster. As a consequence, from a functional point of view, the cluster is unbalanced as long as these nodes are still up. 

Kubernetes and Docker solve that issue pretty elegantly. First you spin the seed nodes under a replication controler and use this to create a service. Then you add a very similar replication controler for "standard nodes" (unit) of the cluster. Finaly you destroy the seed nodes as soon as enough units are up & running. You now have a scale out, cloud native app running. Your cluster is now balanced. 

We are not saying every scale out app is like this. But when it is, this pattern is useful to make it work nicely in a k8s environment. 

# Final notes

This work was seeded and sponsored by Blended Technologies (www.blended.io) as part of an effort to dockerize a more complex application. We decided to open source the project to show our gratitude to the great folks at Couchbase (special kudos to Traun Leyden) who did a great lot at explaining how to run Couchbase in docker containers. 

