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
#=================

ACCOUNT_ID=`aws sts get-caller-identity --output text --query 'Account'`
BUCKET_NAME="devops-bucket-${ACCOUNT_ID}-${REGION}"
S3_CHECK=`aws s3 ls "s3://${BUCKET_NAME}" 2>&1`

if [ $? != 0 ]
then
  NO_BUCKET_CHECK=$(echo $S3_CHECK | grep -c 'NoSuchBucket')

  if [ $NO_BUCKET_CHECK = 1 ]
  then
    COMMAND="aws s3api create-bucket --region ${REGION} --acl private --bucket ${BUCKET_NAME}"

    if [ $REGION != "us-east-1" ]
    then
    	COMMAND="$COMMAND --create-bucket-configuration LocationConstraint=${REGION}"
  	fi

  	RESULT=`eval "$COMMAND"`
  	echo -e $BUCKET_NAME
  else
    echo "Error checking S3 Bucket"
    echo "$S3_CHECK"
    exit 1
  fi
else
  echo -e $BUCKET_NAME
fi