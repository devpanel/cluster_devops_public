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
BRANCH=$1
#================= 

if [ -d "devops/config" ]
then
  for file in `find devops/config -maxdepth 1 -type f -iname "*-$BRANCH.yml"`
  do
    while IFS='' read -r line || [[ -n "$line" ]]
    do
      IFS=': ' read -r -a array <<< "$line"
      if [ "${array[0]}" == "CONTINUOUS_DELIVERY" ]
      then
        if [ "${array[1]}" == "true" ]
        then
          cat "$file"
        fi
      fi
    done < "$file"
  done
fi