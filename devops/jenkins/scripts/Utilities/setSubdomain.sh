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



SUBDOMAIN=$1
ADDRESS=$2
TTL=${3-60}

function valid_ip()
{
  local  ip=$1
  local  stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      OIFS=$IFS
      IFS='.'
      ip=($ip)
      IFS=$OIFS
      [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
          && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
      stat=$?
  fi
  return $stat
}

if [ "${SUBDOMAIN:${#SUBDOMAIN}-1}" != "." ]
then
  SUBDOMAIN=$SUBDOMAIN'.'
fi

REQUEST=`aws route53 list-hosted-zones-by-name`

for HostedZoneName in `echo "$REQUEST" | jq -r '.HostedZones | .[] | .Name'`
do
  if [[ $SUBDOMAIN =~ .*${HostedZoneName} ]]
  then
    HOSTED_ZONE_NAME=$HostedZoneName
    break
  fi
done

HOSTED_ZONE_ID=`echo "$REQUEST" | jq -r '[.HostedZones | .[] | select (.Name == "'$HOSTED_ZONE_NAME'") | .Id] | .[0]'`

if valid_ip $ADDRESS
then 
  RECORD_TYPE='A'
else 
  RECORD_TYPE='CNAME'
fi

aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{
  "Changes": 
  [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": 
      {
        "Name": "'$SUBDOMAIN'",
        "Type": "'$RECORD_TYPE'",
        "TTL": '$TTL',
        "ResourceRecords": 
        [
          {
            "Value": "'$ADDRESS'"
          }
        ]
      }
    }
  ]
}'
 
#devops/jenkins/scripts/Utilities/setSubdomain.sh "jenkins-client-dev.ezopssoftware.com.br" "google.com"