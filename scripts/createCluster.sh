#!/bin/bash

# createCluster.sh
# Spin up Docker containers running both CB Server and Sync Gateway
# configure server with bucket, indexes, and data plus sync gateway user
# Configure sync gateway
#
# Effectively, this script will provide everything required to run the
# simple mobile demo in this project

# wait_for_container seconds ip_address port
# Check for a response from http://ip_address:port and return error code
# if a response is not received in seconds
wait_for_container() {
	local SECONDS=${1}
	local IP=${2}
	local PORT=${3}
	local success=1 # has not (yet) succeeded
	while [ ${SECONDS} -gt 0 ]; do
		SECONDS=$((SECONDS-1))
		curl -sf ${IP}:${PORT} -o /dev/null
		if [ $? -eq 0 ]; then
			success=0 # connection succeeded
			break;
		fi
		sleep 1
		echo -n "."
	done
	echo " " # add carriage return
	return $success
}

if [ -z ${LOCPATH} ]; then # get the script directory and hop up one level
	export LOCPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
fi
if [ ! -d ${LOCPATH} ]; then # this shouldn't happen unless, of course, the above is overridden
	echo "${0}: LOCPATH does not exist (${LOCPATH})" >&2
	exit 99
fi

# Stop and remove existing containers, if they're running
( docker stop cb_sg ; docker stop sync-gateway ; docker rm cb_sg ; docker rm sync-gateway ) 2>/dev/null

################################################################################
# Create Cluster Container
echo "**** Creating Cluster Container ****"
echo "**************************************************"
echo " "
docker run -d -v "$LOCPATH/data":/cb_share \
	-p 8091-8096:8091-8096 \
	-p 11210-11211:11210-11211 --network sync_gateway --name cb_sg couchbase:enterprise-6.6.3

wait=60
echo -n "Waiting up to ${wait} seconds for cluster to start "
wait_for_container ${wait} localhost 8091
success=$?
if [ $success -ne 0 ]; then
	echo "Server container failed to start!" >&2
	exit 99
fi

################################################################################
# Initialize CB Server Node
echo " " ; echo " "
echo "**** Initialize CB Server Node  ****"
echo "**************************************************"
echo " "
curl -sS  --output dev/null -u Administrator:password -v -X POST http://127.0.0.1:8091/nodes/self/controller/settings \
	-d path=/opt/couchbase/var/lib/couchbase/data \
	-d index_path=/opt/couchbase/var/lib/couchbase/indexes \
	-d cbas_path=/opt/couchbase/var/lib/couchbase/eventing \
	-d eventing_path=/opt/couchbase/var/lib/couchbase/analytics

# Rename Node
echo " " ; echo " "
echo "**** Renaming Cluster ****"
echo "**************************************************"
echo " "
curl -sS  --output dev/null -u Administrator:password -v -X POST http://127.0.0.1:8091/node/controller/rename \
	-d hostname=127.0.0.1

# Set up services (Data [kv], Index, Query [n1ql], FTS)
echo " " ; echo " "
echo "**** Set up Cluster Services (Data, Index, Query, FTS) ****"
echo "**************************************************"
echo " "
curl -sS  --output dev/null -u Administrator:password -v -X POST http://127.0.0.1:8091/node/controller/setupServices \
	-d services=kv%2Cindex%2Cn1ql%2Cfts
echo " " ; echo " "
echo "**** Setting Cluster Storage Mode ****"
echo "**************************************************"
echo " "
curl -sS  --output dev/null -u Administrator:password -v -X POST http://127.0.0.1:8091/settings/indexes -d storageMode=plasma

# Set Memory Quotas
echo " " ; echo " "
echo "**** Set Service Memory Quotas  ****"
echo "**************************************************"
echo " "
curl -sS  --output dev/null -u Administrator:password -v -X POST http://127.0.0.1:8091/pools/default \
	-d memoryQuota=1024 \
	-d indexMemoryQuota=512 \
	-d ftsMemoryQuota=512

# Use Administrator/password for console login
echo " " ; echo " "
echo "**** Set console login credentials ****"
echo "**************************************************"
echo " "
curl -sS  --output dev/null -u Administrator:password -v -X POST http://127.0.0.1:8091/settings/web \
	-d password=password \
	-d username=Administrator \
	-d port=8091

# Create bucket: demobucket - 512mb memory quota, no replicas, enable flush (optional)
echo " " ; echo " "
echo "**** Creating Demo Bucket       ****"
echo "**************************************************"
echo " "
curl -sS  -X POST --output dev/null -u Administrator:password http://127.0.0.1:8091/pools/default/buckets \
	-d name=demobucket -d ramQuotaMB=256 -d authType=sasl -d saslPassword=9832cae99c0972343d54760f124d1f59 \
	-d replicaNumber=0 \
	-d replicaIndex=0 \
	-d bucketType=couchbase \
	-d flushEnabled=1
sleep 5

# Set up Indexes
# Primary Index
echo " " ; echo " "
echo "**** Create Index: Primary Index ****"
echo "**************************************************"
echo " "
curl -sS  --output dev/null -u Administrator:password http://127.0.0.1:8093/query/service -d 'statement=CREATE PRIMARY INDEX demo_pidx ON demobucket'
# GSI: type
echo " " ; echo " "
echo "**** Create Index: GSI Index     ****"
echo "**************************************************"
echo " "
curl -sS  --output dev/null -u Administrator:password http://127.0.0.1:8093/query/service -d 'statement=CREATE INDEX demo_typeIDX ON demobucket(type)'

# Create user: sync_gateway
echo " " ; echo " "
echo "**** Creating Sync Gateway User ****"
echo "**************************************************"
echo " "
curl --output /dev/null -sS  -X PUT --data "name=Sync Gateway&roles=ro_admin,bucket_full_access[demobucket]&password=password" \
	-H "Content-Type: application/x-www-form-urlencoded" \
	http://Administrator:password@127.0.0.1:8091/settings/rbac/users/local/sync_gateway

################################################################################
# Create Sync Gateway container
echo " " ; echo " "
echo "**** Creating Sync Gateway Container ****"
echo "**************************************************"
echo " "
docker run -p 4984-4985:4984-4985 \
	--network sync_gateway \
	--name sync-gateway \
	-d \
	-v "$LOCPATH/data/":/etc/sync_gateway/ \
	couchbase/sync-gateway:2.8.0-enterprise -adminInterface :4985 /etc/sync_gateway/sync-gateway-config.json

# Setup Sync Gateway
wait=20
echo -n "Waiting up to ${wait} seconds for sync gateway to start "
wait_for_container ${wait} localhost 4985
success=$?
if [ $success -ne 0 ]; then
	echo "Sync Gateway container failed to start!" >&2
	exit 99
fi

echo " " ; echo " "
echo "**** Creating Sync Gateway User ****"
echo "**************************************************"
echo " "
curl --output /dev/null -sS  --request POST -H 'Content-Type: application/json' \
	--data '{ "name": "sync_gateway", "password": "password", "admin_channels": [ "*" ], "admin_roles": null,"email": "daniel.james@couchbase.com", "disabled": false }'  \
	http://localhost:4985/demobucket/_user/

echo " " ; echo " "
echo "**** Loading sample users into CB ****"
echo "**************************************************"
echo " "
docker exec -it cb_sg cbimport json -c couchbase://127.0.0.1 -u Administrator -p password -b demobucket -f list -d file://cb_share/names.json -t 1 -g contact::%email%::01
