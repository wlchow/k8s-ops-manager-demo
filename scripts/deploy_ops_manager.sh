#!/bin/sh
##
# Script to deploy a Kubernetes project with a StatefulSet running a MongoDB Replica Set, to GKE.
##

NEW_PASSWORD="abc123"

# Create keyfile for the MongoD cluster as a Kubernetes shared secret
TMPFILE=$(mktemp)
/usr/bin/openssl rand -base64 741 > $TMPFILE
kubectl create secret generic shared-bootstrap-data --from-file=internal-auth-mongodb-keyfile=$TMPFILE
rm $TMPFILE

# For Ops Manager, create the gen.key file manually as a Kubernetes shared secret
TMPFILE=$(mktemp)
/usr/bin/openssl rand 24 > $TMPFILE
kubectl create secret generic shared-opsmgr-data --from-file=gen.key=$TMPFILE
rm $TMPFILE

# Create ConfigMap to hold the Ops Manager configuration properties file (i.e. conf-mms.properties)
kubectl create configmap conf-mms --from-file ../resources/conf-mms.properties

# Create mongodb appdb service with mongod stateful-set
kubectl apply -f ../resources/mongodb-appdb-service.yaml
# Create mongodb oplogdb service with mongod stateful-set
kubectl apply -f ../resources/mongodb-oplogdb-service.yaml
# Create mongodb blockstoredb service with mongod stateful-set
kubectl apply -f ../resources/mongodb-blockstoredb-service.yaml
echo

# Wait until the mongod has started properly
echo "Waiting for the 2 containers to come up (`date`)..."
echo " (IGNORE any reported not found & connection errors)"
sleep 30
echo -n "  "
until kubectl --v=0 exec mongod-appdb-2 -c mongod-appdb-container -- mongo --quiet --eval 'db.getMongo()'; do
    sleep 5
    echo -n "  "
done
until kubectl --v=0 exec mongod-oplogdb-0 -c mongod-oplogdb-container -- mongo --quiet --eval 'db.getMongo()'; do
    sleep 5
    echo -n "  "
done
until kubectl --v=0 exec mongod-blockstoredb-0 -c mongod-blockstoredb-container -- mongo --quiet --eval 'db.getMongo()'; do
    sleep 5
    echo -n "  "
done
echo "...appdb, oplogdb and blockstoredb mongod containers are now running (`date`)"
echo


# Initiate MongoDB Replica Set configuration
echo "Configuring the AppDB MongoDB Replica Set"
kubectl exec mongod-appdb-0 -c mongod-appdb-container -- mongo --eval 'rs.initiate({_id: "AppDBRepSet", version: 1, members: [ {_id: 0, host: "mongod-appdb-0.mongodb-appdb-service.default.svc.cluster.local:27017"}, {_id: 1, host: "mongod-appdb-1.mongodb-appdb-service.default.svc.cluster.local:27017"}, {_id: 2, host: "mongod-appdb-2.mongodb-appdb-service.default.svc.cluster.local:27017"} ]});'
# NOTE: for testing, the OplogDB is a 1 member replication set
echo "Configuring the OplogDB MongoDB Replica Set"
kubectl exec mongod-oplogdb-0 -c mongod-oplogdb-container -- mongo --eval 'rs.initiate({_id: "OplogDBRepSet", version: 1, members: [ {_id: 0, host: "mongod-oplogdb-0.mongodb-oplogdb-service.default.svc.cluster.local:27017"} ]});'
# NOTE: for testing, the BlockstoreDB is a 1 member replica set
echo "Configuring the BlockstoreDB MongoDB Replica Set"
kubectl exec mongod-blockstoredb-0 -c mongod-blockstoredb-container -- mongo --eval 'rs.initiate({_id: "BlockstoreDBRepSet", version: 1, members: [ {_id: 0, host: "mongod-blockstoredb-0.mongodb-blockstoredb-service.default.svc.cluster.local:27017"} ]});'
echo

# Wait for the MongoDB Replica Set to have a primary ready
echo "Waiting for the AppDB, OplogDB and BlockstoreDB MongoDB Replica Set to initialise..."
kubectl exec mongod-appdb-0 -c mongod-appdb-container -- mongo --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'
kubectl exec mongod-oplogdb-0 -c mongod-oplogdb-container -- mongo --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'
kubectl exec mongod-blockstoredb-0 -c mongod-blockstoredb-container -- mongo --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'
sleep 2 # Just a little more sleep to ensure everything is ready!
echo "...initialisation of MongoDB Replica Sets completed"
echo

# Create the Admin User on AppDB (this will automatically disable the localhost exception)
echo "Creating user: 'main_admin'"
kubectl exec mongod-appdb-0 -c mongod-appdb-container -- mongo --eval 'db.getSiblingDB("admin").createUser({user:"main_admin",pwd:"'"${NEW_PASSWORD}"'",roles:[{role:"root",db:"admin"}]});'
echo
# Create the Admin User on OplogDB (this will automatically disable the localhost exception)
echo "Creating user: 'main_admin'"
kubectl exec mongod-oplogdb-0 -c mongod-oplogdb-container -- mongo --eval 'db.getSiblingDB("admin").createUser({user:"main_admin",pwd:"'"${NEW_PASSWORD}"'",roles:[{role:"root",db:"admin"}]});'
echo
# Create the Admin User on BlockstoreDB (this will automatically disable the localhost exception)
echo "Creating user: 'main_admin'"
kubectl exec mongod-blockstoredb-0 -c mongod-blockstoredb-container -- mongo --eval 'db.getSiblingDB("admin").createUser({user:"main_admin",pwd:"'"${NEW_PASSWORD}"'",roles:[{role:"root",db:"admin"}]});'
echo

# Create the Ops Manager stateful set
echo "Deploying Ops Manager stateful set"
kubectl apply -f ../resources/mongodb-opsmgr-service.yaml
echo

# Print current deployment state
kubectl get persistentvolumes
echo
kubectl get all 
echo
