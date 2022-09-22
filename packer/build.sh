#!/bin/bash -e

export PACKER_TEMPLATE="aws-rhel8-quay.json"

export PULL_SECRET="/home/danclark/pull-secret.txt"

if [ -z $AWS_ACCESS_KEY_ID ];
then
  echo "AWS_ACCESS_KEY_ID Required"
  exit 1
fi
if [ -z $AWS_SECRET_ACCESS_KEY ];
then
  echo "AWS_SECRET_ACCESS_KEY Required"
  exit 1
fi

export DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
  --query 'Vpcs[?IsDefault == `true`].VpcId' \
  --output text) 

export SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${DEFAULT_VPC_ID}" \
  --query 'Subnets[?AvailabilityZone == `us-east-1c`].SubnetId' \
  --output text)

export SOURCE_AMI=$(aws ec2 describe-images --owners 309956199498 --region us-east-1 \
  --output text --query 'Images[*].[ImageId]' \
  --filters "Name=name,Values=RHEL-8.6?*HVM-*Hourly*" Name=architecture,Values=x86_64 | sort -r)

ansible-galaxy role install redhatofficial.rhel8_stig

packer build ${PACKER_TEMPLATE}

exit 0

# Below code does not work correctly

echo "Waiting 1 minute before cleaning up extra resources..."
sleep 60
VOL_ID=`aws --region ${AWS_DEFAULT_REGION} ec2 describe-volumes --filters='Name=status,Values=available Name=tag-key,Values="Builder" Name=tag-value,Values="Packer*"' --query 'Volumes[*].{VolumeId:VolumeId}' --output text`
echo "Deleting unattached volume id ${VOL_ID}..."
for V_ID in $VOL_ID
do
  aws --region ${AWS_DEFAULT_REGION} ec2 delete-volume --volume-id ${V_ID}
done