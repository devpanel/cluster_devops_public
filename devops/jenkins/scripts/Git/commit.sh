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



function urlencode() 
{
  local LANG=C i c e=''
  for ((i=0;i<${#1};i++))
  do
    c=${1:$i:1}
    [[ "$c" =~ [a-zA-Z0-9\.\~\_\-] ]] || printf -v c '%%%02X' "'$c"
    e+="$c"
  done
  echo "$e"
}

#=== Script Inputs
GIT_URL=$1
GIT_BRANCH=$2
#================= 

REQUEST=`aws secretsmanager get-secret-value --region us-east-1 --secret-id /GENERAL | jq -r '.SecretString'`
GIT_EMAIL=`echo "$REQUEST" | jq -r '.GIT_EMAIL'`
GIT_NAME=`echo "$REQUEST" | jq -r '.GIT_NAME'`
GIT_USERNAME=`echo "$REQUEST" | jq -r '.GIT_USER'`
GIT_PASSWORD=`echo "$REQUEST" | jq -r '.GIT_PASSWORD'`

echo $GIT_USERNAME
echo $GIT_PASSWORD

git add -A
git -c "user.name=$GIT_NAME" -c "user.email=$GIT_EMAIL" commit -m 'Save Configuration [ci skip]'
git push "${GIT_URL//https\:\/\//https\:\/\/`urlencode $GIT_USERNAME`\:`urlencode $GIT_PASSWORD`\@}" HEAD:$GIT_BRANCH