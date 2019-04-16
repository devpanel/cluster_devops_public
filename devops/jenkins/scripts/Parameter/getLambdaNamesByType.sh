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
TYPE=$1
#================= 

for REGION in `aws ec2 describe-regions --region=us-east-1 --output text --query 'Regions[*].RegionName'`
do
  RESULT=$RESULT`aws cloudformation describe-stacks --region $REGION | jq -r '[.[] | .[] | [select (.Description == "Sets up ecs cluster" and .RootId == null) | .Parameters[] | select(.ParameterKey == "ClusterName") | "'$REGION' : '$TYPE'-" + .ParameterValue] + [select (.Description == "Sets up '$TYPE' lambda") | "'$REGION' : " + (.Parameters[] | select(.ParameterKey == "Name") | .ParameterValue)] | .[]] | group_by(.) | .[] | select(length == 1) | .[]'`"\n"
done

echo -e "CREATE_NEW\n$RESULT" | grep .


# devops/jenkins/scripts/Parameter/getLambdaNamesByType.sh AlarmToSlack