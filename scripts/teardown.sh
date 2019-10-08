#!/bin/sh
##
# Script to remove/undepoy all project resources from GKE & GCE.
##

# Delete mongod stateful set + mongodb service + secrets + host vm configuer daemonset
kubectl delete statefulsets mongod-appdb
kubectl delete statefulsets mongod-oplogdb
kubectl delete statefulsets mongod-blockstoredb
kubectl delete statefulsets mongo-opsmgr
kubectl delete services mongodb-appdb-service
kubectl delete services mongodb-oplogdb-service
kubectl delete services mongodb-blockstoredb-service
kubectl delete services mongo-opsmgr-service
kubectl delete secret shared-bootstrap-data
kubectl delete secret shared-opsmgr-data
kubectl delete configmap conf-mms
kubectl delete daemonset hostvm-configurer
sleep 3

# Delete persistent volume claims
kubectl delete persistentvolumeclaims -l role=mongo-appdb
kubectl delete persistentvolumeclaims -l role=mongo-oplogdb
kubectl delete persistentvolumeclaims -l role=mongo-blockstoredb
kubectl delete persistentvolumeclaims -l app=mongo-opsmgr
sleep 3

# Delete persistent volumes
for i in 1 2 3 4
do
    kubectl delete persistentvolumes opsmgr-data-volume-4g-$i
done
for i in 1 2 3 4 5 6 7 8 9
do
    kubectl delete persistentvolumes opsmgr-data-volume-8g-$i
done
sleep 20

# Delete GCE disks
for i in 1 2 3 4
do
    gcloud -q compute disks delete opsmgr-pd-ssd-disk-4g-$i
done
for i in 1 2 3 4 5 6 7 8 9
do
    gcloud -q compute disks delete opsmgr-pd-ssd-disk-8g-$i
done

# Delete whole Kubernetes cluster (including its VM instances)
gcloud -q container clusters delete "gke-ops-manager-demo-cluster"

