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



#===== Script Inputs
REGION=$1
SECRET_PATH=$2
PARAMETERS=$3
OVERWRITE=${4-false}
#===================

if [ "`aws secretsmanager list-secrets --region $REGION | jq -r '[.SecretList | .[] | select(.Name == "'$SECRET_PATH'")] | length'`" == "0" ]
then
  aws secretsmanager create-secret --region $REGION --name $SECRET_PATH --secret-string "$PARAMETERS" 2> /dev/null
  
  if [ $? != 0 ]
  then
    aws secretsmanager restore-secret --region $REGION --secret-id $SECRET_PATH 

    aws secretsmanager put-secret-value --region $REGION --secret-id $SECRET_PATH --secret-string "$PARAMETERS"
  fi
else
  if [ "$OVERWRITE" == "false" ]
  then
    CURRENT_PARAMETERS=`aws secretsmanager get-secret-value --region $REGION --secret-id $SECRET_PATH | jq -r '.SecretString'`
    CONCATED_PARAMETERS=`jq --argjson arr1 "$PARAMETERS" --argjson arr2 "$CURRENT_PARAMETERS" -n '$arr2 + $arr1'`
      
    aws secretsmanager put-secret-value --region $REGION --secret-id $SECRET_PATH --secret-string "$CONCATED_PARAMETERS"
  else
    aws secretsmanager put-secret-value --region $REGION --secret-id $SECRET_PATH --secret-string "$PARAMETERS"
  fi
fi


#devops/jenkins/scripts/SecretManager/set.sh us-east-1 /ECS-CLUSTER/weslei12 '{"param1":"value1 sdf","param2":"value2"}'