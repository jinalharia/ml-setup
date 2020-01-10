#!/bin/bash

PRIVATE_KEY="datasciencetutorial.pem"
DSSNAPSHOTID="snap-02056915e488e2a8e" #this is the snapshotid of the datascience volume to create
IMAGEID="ami-0122108aad5144107" #this is the ami imageid to create instance from

#update json file with ImageId from above (incase we need to update image to be used
jq --arg v "$IMAGEID" '.ImageId = $v' create-spot-instance.json > tmp.json
mv tmp.json create-spot-instance.json

#create the spot instance at price with imageid in the json file and save output to spot-instance-info.json
aws ec2 request-spot-instances --spot-price 0.0288 --instance-count 1 --type one-time --launch-specification file://create-spot-instance.json > spot-instance-info.json

#parse spot instance json file to get availability zone and instance id
cat spot-instance-info.json | jq '.SpotInstanceRequests[0].LaunchSpecification.Placement.AvailibilityZone'
cat spot-instance-info.json | jq '.SpotInstanceRequests[0].LaunchedAvailabilityZone'
cat spot-instance-info.json | jq '.SpotInstanceRequests[0].InstanceId'

#get instanceid of machine
INSTANCEID=`aws ec2 describe-instances --query 'Reservations[*].Instances[*].InstanceId' --output text`
#get public dns of instance for ssh later
#AWS=`aws ec2 describe-instances --query 'Reservations[*].Instances[*].PublicDnsName' --output text`
AWS=`aws ec2 describe-instances --instance-id $INSTANCEID --query 'Reservations[*].Instances[*].PublicDnsName' --output text`
#get availability zone of instance to know where to create volume later
#ZONE=`aws ec2 describe-instances --query 'Reservations[*].Instances[*].Placement.AvailabilityZone' --output text`
ZONE=`aws ec2 describe-instances --instance-id $INSTANCEID --query 'Reservations[*].Instances[*].Placement.AvailabilityZone' --output text`

echo "AvailabilityZone: $ZONE"
echo "InstanceId: $INSTANCEID"
echo "MachineIP: $AWS"

#create volume from snapshot in above zone
#first line below uses json but second line is easier and no need for json file
#VOLUMEID=`aws ec2 create-volume --availability-zone $ZONE --snapshot-id $DSSNAPSHOTID --cli-input-json file://create-volume.json --query 'VolumeId' --output text`
VOLUMEID=`aws ec2 create-volume --availability-zone $ZONE --snapshot-id $DSSNAPSHOTID --no-encrypted --query 'VolumeId' --output text`
echo "VolumeId: $VOLUMEID"
#attach volume to instance
aws ec2 attach-volume --volume-id $VOLUMEID --instance-id $INSTANCEID --device /dev/sdf

echo "ssh-ing into $AWS"
ssh -i $PRIVATE_KEY -L 8888:127.0.0.1:8888 -L 6006:localhost:6006 ubuntu@$AWS

#detach datascience volume once finished
aws ec2 detach-volume --volume-id $VOLUMEID
#create new snapshot of datascience volume
DSSNAPSHOTIDNEW=`aws ec2 create-snapshot --volume-id $VOLUMEID --description "datascience-volume1" --query 'SnapshotId' --output text`
echo "New DS Volume SnapshotId: $DSSNAPSHOTIDNEW"
#delete volume once snapshot created
aws ec2 delete-volume --volume-id $VOLUMEID

#create ami image for instance
AMIIMAGEID=`aws ec2 create-image --instance-id $INSTANCEID --name "datascience-gpu-clean" --description "AMI for datascience machine" --query 'ImageId' --output text`
echo "New AMI ImageId: $AMIIMAGEID"
#deregister ami image
aws ec2 deregister-image --image-id $IMAGEID
#delete old volume snapshotid
aws ec2 delete-snapshot --snapshot-id $DSSNAPSHOTID
