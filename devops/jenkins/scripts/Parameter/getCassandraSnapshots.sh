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



for REGION in `aws ec2 describe-regions --region=us-east-1 --output text --query 'Regions[*].RegionName'`
do
  BUCKET_PREFIX=`aws ssm get-parameter --region $REGION --name /GENERAL/BUCKET_PREFIX --output text --query Parameter.Value 2> /dev/null`
  
  if [ "$BUCKET_PREFIX" != "" ]
  then
    BUCKET_NAME="${BUCKET_PREFIX}-${REGION}"
    
    RESULT=$RESULT`aws s3api list-objects --bucket "$BUCKET_NAME" --prefix "backups/cassandra" | jq -r '.Contents | .[] | "{\"LastModified\": " + (.LastModified[:-5] + "Z" | fromdateiso8601 | tostring) + ", \"S3\": \"s3://'$BUCKET_NAME'/" + .Key + "\"},"'`
  fi
done

echo "[${RESULT::-1}]" | jq -r 'unique_by(.S3) | sort_by(-.LastModified) | .[] | .S3'

# devops/jenkins/scripts/Parameter/getCassandraSnapshots.sh