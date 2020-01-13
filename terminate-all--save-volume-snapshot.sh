#!/bin/bash

#get instanceid of machine
INSTANCEID=`aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].InstanceId' --output text`
echo "InstanceId: $INSTANCEID"

#create volume from snapshot in above zone
#first line below uses json but second line is easier and no need for json file
#VOLUMEID=`aws ec2 create-volume --availability-zone $ZONE --snapshot-id $DSSNAPSHOTID --cli-input-json file://create-volume.json --query 'VolumeId' --output text`
VOLUMEID=`aws ec2 create-volume --availability-zone $ZONE --snapshot-id $DSSNAPSHOTID --no-encrypted --query 'VolumeId' --output text`
echo "VolumeId: $VOLUMEID"

#detach datascience volume once finished
aws ec2 detach-volume --volume-id $VOLUMEID
echo "VolumeId $VOLUMEID detached"

#create new snapshot of datascience volume
DSSNAPSHOTIDNEW=`aws ec2 create-snapshot --volume-id $VOLUMEID --description "datascience-volume1" --query 'SnapshotId' --output text`
echo "New DS Volume SnapshotId: $DSSNAPSHOTIDNEW"


#delete volume once snapshot created
aws ec2 delete-volume --volume-id $VOLUMEID
echo "VolumeId $VOLUMEID deleted"

#terminate intance
aws ec2 terminate-instances --instance-ids $INSTANCEID
echo "InstanceId $INSTANCEID terminated"