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
STACK_NAME=$2
#================= 

aws cloudformation describe-stacks --region $REGION | jq -r '[.[] | .[] | select (.StackName == "'$STACK_NAME'" and .StackStatus != "DELETE_COMPLETE") ] | if length > 0 then "no" else "yes" end'

# devops/jenkins/scripts/Utilities/isFirstExecution.sh us-east-1 "weslei26-cluster"