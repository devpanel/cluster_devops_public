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



#=== Change in here!!!
GIT_URL=https://git-codecommit.us-west-1.amazonaws.com/v1/repos/cluster
GIT_CURRENT_BRANCH=develop
#=====================

#=== Script Inputs
OPTION=$1
PARAMETER1=$2
PARAMETER2=$3
#=================


function fixProblems
{
  cd `dirname "$0"` # Prevent directory error if this script was called by another

  exec 200>"locker" && flock -n 200 || exit 1   # Prevent multipe executions
}

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

function isRunningInRemoteMachine
{
  if [[ `uname -r` =~ Microsoft$ ]]
  then
    return 1
  else
    return 0
  fi
}

function isFirstRun
{
  if [[ ! -d ".git" ]] || [[ -n "$isFirstTime" ]]
  then
    isFirstTime="yes"
    return 0
  else
    return 1
  fi
}

function installNecessaryPackages
{
  sudo apt-get update
  sudo apt-get -y install software-properties-common
  sudo add-apt-repository -y ppa:git-core/ppa
  sudo apt-get update
  sudo apt-get -y install git
  sudo apt-get -y install sed
}

function readUsernameAndPassword
{
  read -p "Type your git username: " USERNAME
  read -p "Type your git password: " PASSWORD

  REMOTE=${GIT_URL//https\:\/\//https\:\/\/`urlencode $USERNAME`\:`urlencode $PASSWORD`\@}
}

function readEmailAndName
{
  read -p "Type your git email: " EMAIL
  read -p "Type your git name: " NAME
}

function readBranch
{
  #=== Local Variables
  local MESSAGE=$1
  local REMOTE=$2
  #===================
  
  while true
  do 
    read -p "$MESSAGE" BRANCH

    if [[ -n `git ls-remote --heads $REMOTE $BRANCH` ]]
    then
      break
    else
      echo -e "Branch not exists!!!\n"
    fi
  done
}

function choiceBranch
{
  echo "Wait!"
  git fetch --all >&- 2>&-
  readBranch "Type your branch: " "origin"
  local NEWFILE=`sed "0,/GIT_CURRENT_BRANCH=.*/s/GIT_CURRENT_BRANCH=.*/GIT_CURRENT_BRANCH=$BRANCH/" $0`
  git checkout -f $BRANCH
  git merge
  echo "$NEWFILE" > $0
}

function pullAndCommit 
{
  #=== Local Variables
  local BACKUP_BRANCH=backup_`date +%s`
  local MESSAGE=$PARAMETER1
  #===================

  if [[ -z "$MESSAGE" ]]
  then
    MESSAGE="scripts updated"
  fi 

  if isFirstRun
  then
    git checkout -b $BACKUP_BRANCH
    git add -A
    git commit -m "$MESSAGE"
    git fetch --all
    git checkout -f $GIT_CURRENT_BRANCH
    git merge
    git checkout $BACKUP_BRANCH -- .
    git branch -D $BACKUP_BRANCH
  else
    git fetch --all
    git merge
  fi

  git rm . -r --cached # To the file .gitignore works
  git add -A
  git commit -m "$MESSAGE"
  git push
}  

function merge 
{
  #==================== Inputs
  readBranch "Type your SOURCE branch: " "origin"
  local SOURCE=$BRANCH
  readBranch "Type your DESTINATION branch: " "origin"
  local DESTINATION=$BRANCH
  #===================================================

  local BACKUP_BRANCH=backup_`date +%s`
  git checkout -b $BACKUP_BRANCH
  git add -A
  git commit -m "backup"

  git fetch --all
  git checkout -f $DESTINATION
  git merge
  git merge $SOURCE
  git checkout $SOURCE -- .
  git add -A
  git commit -m "resolves conflicts between $SOURCE and $DESTINATION"
  git push

  git checkout -f $GIT_CURRENT_BRANCH
  git merge
  git rm -rf "*"
  git checkout $BACKUP_BRANCH -- .
  git branch -D $BACKUP_BRANCH
}

 
function showOptions
{
  if [[ -z "$OPTION" ]]
  then
    echo "1) Pull/Commit"
    echo "2) Choice Branch"
    echo "3) Merge"

    while true
    do
      printf "\nChoice the number of yours operation: "
      read OPTION

      if [[ "$OPTION" =~ ^[0-9]+$ ]] && (( "$OPTION" >= 1 && "$OPTION" <= 3 ))
      then
        break
      else
        echo "Invalid number!"
      fi
    done 
  fi
  
  if [[ "$OPTION" == "1" ]]
  then
    pullAndCommit
  elif [[ "$OPTION" == "2" ]]
  then
    choiceBranch
  elif [[ "$OPTION" == "3" ]]
  then
    merge
  fi
}  
  

#============= Main Line
fixProblems  
  
if isFirstRun
then  
  echo -e "Is the first time that you runs this script.\n"
  echo -e "Now, we are go install all necessary packages to perfectly run it...\n"
  installNecessaryPackages
  clear
  
  echo -e "Now, we need that you type the username and password of remote git account with you will to make writes.\n"
  readUsernameAndPassword
  clear

  echo -e "Now we configure your email and name for identify your commits.\n"
  readEmailAndName
  clear

  git init
  git config --global core.editor "vim"
  git remote add origin $REMOTE
  git config user.email "$EMAIL"
  git config user.name "$NAME"
  clear
fi

showOptions

if ! isRunningInRemoteMachine
then
  clear
  echo "Press ENTER to exit!"
  read
fi