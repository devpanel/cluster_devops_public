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
ORIGIN=$1
NEW_PARAMETERS=$2
#===================

NEW_PARAMETERS=${NEW_PARAMETERS:1:${#NEW_PARAMETERS}-2}
NEW_PARAMETERS=${NEW_PARAMETERS//, /\\n}
NEW_PARAMETERS=`echo -e "$NEW_PARAMETERS" | sed "s|:|: |" | sed "s|: \([^0-9/]\+.*\)|: '\1'|" | sed "s|'true'|true|" | sed "s|'false'|false|"`
echo -e "`cat $ORIGIN`\n$NEW_PARAMETERS"

#devops/jenkins/scripts/Parameter/concatenate.sh 'devops/jenkins/jobs/pipeline/deploy/fixedParameters.yml' '[CLIENT_GIT_TOKEN:8e34938fe28a8c678bda3a5fa6a97973cb4ee3dd, SITE_CNAME:wordpress.devpanel.app, CLIENT_GIT_URL:https://github.com/ezops-br/wordpress_client.git, CLIENT_GIT_BRANCH:master, CLUSTER:us-west-1 : dev23, HAS_HTTPS:false, NO_HAS_HTTPS:true, NUMBER:1234, CLIENT_GIT_USER:jenkins-ezops]'