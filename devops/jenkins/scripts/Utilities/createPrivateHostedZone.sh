#!/bin/bash

#devpanel
#Copyright (C) 2018 devpanel

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.



#=== Script Inputs
REGION=$1
CLUSTER_NAME=$2
HOSTED_ZONE_NAME=$3
#=================

if [ "${HOSTED_ZONE_NAME:${#HOSTED_ZONE_NAME}-1}" != "." ]
then
  HOSTED_ZONE_NAME=$HOSTED_ZONE_NAME'.'
fi

cd `dirname "$0"`

VPC_ID=`./getCloudFormationVariable.sh $REGION "${CLUSTER_NAME}VPC"`
HOSTED_ZONE_ID=`aws route53 list-hosted-zones | jq -r '[.HostedZones | .[] | select(.Name == "'$HOSTED_ZONE_NAME'" and .Config.PrivateZone == true) | .Id] | .[0]'`

if [ "$HOSTED_ZONE_ID" != "null" ]
then
  if [ "`aws route53 get-hosted-zone --id $HOSTED_ZONE_ID | jq -r '.VPCs | .[] | select(.VPCId == "'$VPC_ID'" and .VPCRegion == "'$REGION'")'`" != "" ]
  then
    echo $HOSTED_ZONE_ID
  else
    aws route53 associate-vpc-with-hosted-zone --hosted-zone-id $HOSTED_ZONE_ID --vpc "VPCRegion=${REGION},VPCId=${VPC_ID}" > /dev/null
    echo $HOSTED_ZONE_ID
  fi
else
  aws route53 create-hosted-zone --region $REGION --name $HOSTED_ZONE_NAME --vpc "VPCRegion=${REGION},VPCId=${VPC_ID}" --hosted-zone-config "PrivateZone=true" --caller-reference `date +%s` | jq -r '.HostedZone | .Id'
fi

# devops/jenkins/scripts/Utilities/createPrivateHostedZone.sh us-east-1 dev9002 devpanel.me