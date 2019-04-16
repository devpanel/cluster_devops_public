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


if [ "$CLUSTER_NAME" != "" ]
then
  SECRET_PATH="/ECS-CLUSTER/${CLUSTER_NAME}"
  
  rm -rf ~/.aws
  SECRETS=`aws secretsmanager get-secret-value --region us-east-1 --secret-id $SECRET_PATH`
  if [ $? == 0 ]
  then
    ACCESS_KEY_ID=`echo "$SECRETS" | jq -r '.SecretString' | jq -r '.ACCESS_KEY_ID'`
    SECRET_ACCESS_KEY=`echo "$SECRETS" | jq -r '.SecretString' | jq -r '.SECRET_ACCESS_KEY'`
  
    if [ "$ACCESS_KEY_ID" != "null" ] && [ "$SECRET_ACCESS_KEY" != "null" ] 
    then
      mkdir -p ~/.aws/
    
      echo "[default]
aws_access_key_id=${ACCESS_KEY_ID}
aws_secret_access_key=${SECRET_ACCESS_KEY}" > ~/.aws/credentials
    else
      echo "ACCESS_KEY_ID and/or SECRET_ACCESS_KEY dont exists in secret!"
      exit 1
    fi
  fi
else
  echo "Variable 'CLUSTER_NAME' is not set previous in Jenkinsfile and dont was possible read her in SH context"
  exit 1
fi


# devops/jenkins/scripts/Aws/enableRemote.sh