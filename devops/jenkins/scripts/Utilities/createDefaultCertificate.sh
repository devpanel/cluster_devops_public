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
REGION=${1}
CLUSTER_NAME=${2}
#=================

CERTIFCATE_ARN=`aws acm --region $REGION list-certificates | jq -r '[.CertificateSummaryList | .[] | select(.DomainName == "'*.${CLUSTER_NAME}.internal'") | .CertificateArn] | first'`

if [ "$CERTIFCATE_ARN" == "null" ]
then
  #== Create certificate
  openssl genrsa 2048 &> ${CLUSTER_NAME}-privatekey.pem
  openssl req -new -key ${CLUSTER_NAME}-privatekey.pem -out ${CLUSTER_NAME}-csr.pem -subj "/C=/ST=/L=/O=/OU=/CN=*.${CLUSTER_NAME}.internal" &> /dev/null
  openssl x509 -req -days 13210 -in ${CLUSTER_NAME}-csr.pem -signkey ${CLUSTER_NAME}-privatekey.pem -out ${CLUSTER_NAME}-server.crt &> /dev/null
  
  #== Upload certificate
  CERTIFCATE_ARN=`aws acm import-certificate --region $REGION --certificate "file://${CLUSTER_NAME}-server.crt" --private-key "file://${CLUSTER_NAME}-privatekey.pem" | jq -r '.CertificateArn'`
  
  #== Remove temp files
  rm -f ${CLUSTER_NAME}-*
  
  echo "$CERTIFCATE_ARN"
else
  echo "$CERTIFCATE_ARN"
fi

# devops/jenkins/scripts/Utilities/createDefaultCertificate.sh eu-west-3 dev1000