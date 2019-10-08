#!/bin/sh
##
# Script to deploy a Kubernetes project with a StatefulSet running a MongoDB Ops Manager Cluster, to GKE.
##

# Create new GKE Kubernetes cluster (using host node VM images based on Ubuntu
# rather than default ChromiumOS & also use slightly larger VMs than default)
echo "Creating GKE Cluster"
gcloud container clusters create "gke-ops-manager-demo-cluster" --image-type=UBUNTU --machine-type=n1-standard-2

# Configure host VM using daemonset to disable hugepages
echo "Deploying GKE Daemon Set"
kubectl apply -f ../resources/hostvm-node-configurer-daemonset.yaml


# Define storage class for dynamically generated persistent volumes
# NOT USED IN THIS EXAMPLE AS EXPLICITLY CREATING DISKS FOR USE BY PERSISTENT
# VOLUMES, HENCE COMMENTED OUT BELOW
#kubectl apply -f ../resources/gce-ssd-storageclass.yaml


# Register GCE Fast SSD persistent disks and then create the persistent disks 
echo "Creating GCE disks"
# disks for Ops Manager (i.e. Versions/Binaries and Head Database directories)
#
# https://docs.opsmanager.mongodb.com/current/core/requirements/#backup-daemon-hardware-requirements
#   Typically, each host on which you activate the Backup Daemon needs to store 2.0 to 2.5 times the sum of the size on disk of all the backed-up replica sets.
for i in 1 2 3 4
do
    # 4GB disks
    gcloud compute disks create --size 4GB --type pd-ssd opsmgr-pd-ssd-disk-4g-$i --zone northamerica-northeast1-a
done
# disks for App DB, Oplog DB and Blockstore DB replica sets
for i in 1 2 3 4 5 6 7 8 9
do
    # 8 GB disks
    gcloud compute disks create --size 8GB --type pd-ssd opsmgr-pd-ssd-disk-8g-$i --zone northamerica-northeast1-a
done
sleep 3


# Create persistent volumes using disks that were created above
echo "Creating GKE Persistent Volumes"
for i in 1 2 3 4
do
    # Replace text stating volume number + size of disk (set to 4)
    sed -e "s/INST/${i}/g; s/SIZE/4/g" ../resources/xfs-gce-ssd-persistentvolume.yaml > /tmp/xfs-gce-ssd-persistentvolume.yaml
    kubectl apply -f /tmp/xfs-gce-ssd-persistentvolume.yaml
done
for i in 1 2 3 4 5 6 7 8 9
do
    # Replace text stating volume number + size of disk (set to 8)
    sed -e "s/INST/${i}/g; s/SIZE/8/g" ../resources/xfs-gce-ssd-persistentvolume.yaml > /tmp/xfs-gce-ssd-persistentvolume.yaml
    kubectl apply -f /tmp/xfs-gce-ssd-persistentvolume.yaml
done
rm /tmp/xfs-gce-ssd-persistentvolume.yaml
sleep 3

