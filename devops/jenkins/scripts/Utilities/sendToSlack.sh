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
MESSAGE=$1
#=================

REGION=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region'`
SECRETS=`aws secretsmanager get-secret-value --region $REGION --secret-id /GENERAL | jq -r '.SecretString' | jq -r 'to_entries | .[]'`

ORGANIZATIONS=(`echo $SECRETS | jq -r 'select(.key | endswith("SLACK_TOKEN")) | .key | rtrimstr("_SLACK_TOKEN")'`)
for ORGANIZATION in "${ORGANIZATIONS[@]}"
do
  TOKEN=`echo $SECRETS | jq -r 'select(.key == "'$ORGANIZATION'_SLACK_TOKEN") | .value'`
  CHANNEL=`aws ssm get-parameter --region $REGION --name '/GENERAL/'$ORGANIZATION'_SLACK_CHANNEL_JENKINS' --output text --query Parameter.Value`

  curl -X POST https://slack.com/api/chat.postMessage \
    -d "token=$TOKEN" \
    -d "channel=$CHANNEL" \
    -d "text=$MESSAGE" \
    -d "username=Jenkins" \
    -d "icon_url=https://a.slack-edge.com/205a/img/services/jenkins-ci_72.png"
done 

#devops/jenkins/scripts/Utilities/sendToSlack.sh "test"