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
CLUSTER=$2
COMMAND=`echo "${@:3}" | base64 -w 0`
#=================

INSTANCE_ARN=`aws ecs list-container-instances --region $REGION --cluster $CLUSTER --status "ACTIVE" | jq -r '.containerInstanceArns | .[-1]'`

INSTANCE_ID=`aws ecs describe-container-instances --region $REGION --cluster $CLUSTER --container-instances ${INSTANCE_ARN: -36} | jq -r ' .containerInstances | .[] | .ec2InstanceId'`

COMMAND_ID=`aws ssm send-command --region $REGION --instance-ids $INSTANCE_ID --document-name "AWS-RunShellScript" --parameters commands='eval $(echo '$COMMAND' | base64 -d -w 0)' --output text --query "Command.CommandId"`

while true
do
  COMMAND_RESULT=`aws ssm get-command-invocation --region $REGION --instance-id $INSTANCE_ID --command-id $COMMAND_ID`

  if [ "`echo "$COMMAND_RESULT" | jq -r '.Status'`" != "InProgress" ] 
  then
    echo "`echo "$COMMAND_RESULT" | jq -r '(.StandardErrorContent, .StandardOutputContent)'`"
    exit "`echo "$COMMAND_RESULT" | jq -r '.ResponseCode'`"
  fi
  
  sleep 0.5
done