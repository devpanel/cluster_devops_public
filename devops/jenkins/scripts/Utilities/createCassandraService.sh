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



#=================== Script Inputs
REGION=${1}
CLUSTER_NAME=${2}
IMAGE_VERSION=${3}
CASSANDRA_SNAPSHOT=${4}
CASSANDRA_TASKS=${5}
CASSANDRA_CONTAINER_EBS_SIZE=${6}
CASSANDRA_CONTAINER_CPU_UNIT=${7}
CASSANDRA_CONTAINER_MEMORY=${8}
LAMBDA_ALARM_TO_SLACK_NAME=${9}
#==================================

cd `dirname "$0"`

ACCOUNT_ID=`aws sts get-caller-identity --output text --query 'Account'`
SECURITY_GROUP=`./getCloudFormationVariable.sh $REGION "${CLUSTER_NAME}InternalAccessSecurityGroup"`
PRIVATE_SUBNET1=`./getCloudFormationVariable.sh $REGION "${CLUSTER_NAME}PrivateSubnet1"`
PRIVATE_SUBNET2=`./getCloudFormationVariable.sh $REGION "${CLUSTER_NAME}PrivateSubnet2"`
CASSANDRA_SERVICE_DISCOVERY_ARN=`./getCloudFormationVariable.sh $REGION "${CLUSTER_NAME}CassandraServiceDiscoveryArn"`
LAMBDA_ALARM_TO_SLACK_ARN="arn:aws:sns:${REGION}:${ACCOUNT_ID}:${LAMBDA_ALARM_TO_SLACK_NAME}"

CURRENT_TASKS_NUMBER=`aws ecs list-services --region $REGION --cluster $CLUSTER_NAME | jq -r '[.serviceArns | .[] | select(startswith("arn:aws:ecs:'$REGION':'$ACCOUNT_ID':service/cassandra"))] | length'`

#== Removes services, ebs and alarms that are not being used
for i in `seq $(( $CASSANDRA_TASKS+1 )) $CURRENT_TASKS_NUMBER`
do
  TASK_DEFINITION_NAME="${CLUSTER_NAME}__cassandra${i}"
  SERVICE_NAME="cassandra${i}"
  
  #== Delete services
  aws ecs update-service --region $REGION --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --desired-count 0
  TASKS=(`aws ecs list-tasks --region $REGION --cluster "$CLUSTER_NAME" --service-name "$SERVICE_NAME" | jq -r '.taskArns | .[]'`)
  for j in ${!TASKS[@]}
  do
    aws ecs stop-task --region $REGION --cluster "$CLUSTER_NAME" --task "${TASKS[$j]}"
  done
  aws ecs delete-service --region $REGION --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME"
  
  #== Delete tasks definitions
  TASKS_DEFINITIONS=(`aws ecs list-task-definitions --region $REGION --family-prefix "$TASK_DEFINITION_NAME" | jq -r '.taskDefinitionArns | .[]'`)
  for j in ${!TASKS_DEFINITIONS[@]}
  do
    aws ecs deregister-task-definition --region $REGION --task-definition "${TASKS_DEFINITIONS[$j]}"
  done
  
  #== Delete alarmes
  aws cloudwatch delete-alarms --region $REGION --alarm-names "${CLUSTER_NAME}_${SERVICE_NAME}__ecs_alarm_yellow_cpuutilization"
  aws cloudwatch delete-alarms --region $REGION --alarm-names "${CLUSTER_NAME}_${SERVICE_NAME}__ecs_alarm_yellow_memoryutilization"
  aws cloudwatch delete-alarms --region $REGION --alarm-names "${CLUSTER_NAME}_${SERVICE_NAME}__ecs_alarm_yellow_ebsutilization"
  aws cloudwatch delete-alarms --region $REGION --alarm-names "${CLUSTER_NAME}_${SERVICE_NAME}__ecs_alarm_red_cpuutilization"
  aws cloudwatch delete-alarms --region $REGION --alarm-names "${CLUSTER_NAME}_${SERVICE_NAME}__ecs_alarm_red_memoryutilization"
  aws cloudwatch delete-alarms --region $REGION --alarm-names "${CLUSTER_NAME}_${SERVICE_NAME}__ecs_alarm_red_ebsutilization"
  
  #== Delete Volumes
  VOLUMES_IDS=(`aws ec2 describe-volumes --region $REGION --filters Name=tag:Name,Values=$TASK_DEFINITION_NAME | jq -r '.[] | .[] | .VolumeId'`)
  for j in ${!VOLUMES_IDS[@]}
  do
    aws ec2 detach-volume --region $REGION --volume-id "${VOLUMES_IDS[$j]}" --force
    aws ec2 wait volume-available --region $REGION --volume-ids "${VOLUMES_IDS[$j]}"
    aws ec2 delete-volume --region $REGION --volume-id "${VOLUMES_IDS[$j]}"
  done
done

for i in `seq 1 $CASSANDRA_TASKS`
do
  TASK_DEFINITION_NAME="${CLUSTER_NAME}__cassandra${i}"
  SERVICE_NAME="cassandra${i}"

  #== Create Yellow Alarms
  #CPU
  aws cloudwatch put-metric-alarm --region $REGION --alarm-name "${CLUSTER_NAME}_${SERVICE_NAME}__ecs_alarm_yellow_cpuutilization" --metric-name CPUUtilization --namespace AWS/ECS --statistic Average --period 60 --threshold  70 --comparison-operator GreaterThanThreshold --dimensions Name=ClusterName,Value=$CLUSTER_NAME Name=ServiceName,Value=$SERVICE_NAME --evaluation-periods 2 --alarm-actions "$LAMBDA_ALARM_TO_SLACK_ARN" --ok-actions "$LAMBDA_ALARM_TO_SLACK_ARN" --unit Percent
  #EBS
  aws cloudwatch put-metric-alarm --region $REGION --alarm-name "${CLUSTER_NAME}_${SERVICE_NAME}__ecs_alarm_yellow_ebsutilization" --metric-name EBSUtilization --namespace AWS/ECS --statistic Average --period 60 --threshold 70 --comparison-operator GreaterThanThreshold --dimensions Name=ClusterName,Value=$CLUSTER_NAME Name=ServiceName,Value=$SERVICE_NAME --evaluation-periods 2 --alarm-actions "$LAMBDA_ALARM_TO_SLACK_ARN" --ok-actions "$LAMBDA_ALARM_TO_SLACK_ARN" --unit Percent
  
  #== Create Red Alarms
  #CPU 
  aws cloudwatch put-metric-alarm --region $REGION --alarm-name "${CLUSTER_NAME}_${SERVICE_NAME}__ecs_alarm_red_cpuutilization" --metric-name CPUUtilization --namespace AWS/ECS --statistic Average --period 60 --threshold 90 --comparison-operator GreaterThanThreshold --dimensions Name=ClusterName,Value=$CLUSTER_NAME Name=ServiceName,Value=$SERVICE_NAME --evaluation-periods 2 --alarm-actions "$LAMBDA_ALARM_TO_SLACK_ARN" --ok-actions "$LAMBDA_ALARM_TO_SLACK_ARN" --unit Percent
  #EBS
  aws cloudwatch put-metric-alarm --region $REGION --alarm-name "${CLUSTER_NAME}_${SERVICE_NAME}__ecs_alarm_red_ebsutilization" --metric-name EBSUtilization --namespace AWS/ECS --statistic Average --period 60 --threshold 90 --comparison-operator GreaterThanThreshold --dimensions Name=ClusterName,Value=$CLUSTER_NAME Name=ServiceName,Value=$SERVICE_NAME --evaluation-periods 2 --alarm-actions "$LAMBDA_ALARM_TO_SLACK_ARN" --ok-actions "$LAMBDA_ALARM_TO_SLACK_ARN" --unit Percent


  TASK_VOLUME='[
    {
      "name": "'$TASK_DEFINITION_NAME'",
      "dockerVolumeConfiguration": 
      {
        "autoprovision": true,
        "scope": "shared",
        "driver": "rexray/ebs",
        "driverOpts": 
        {
          "size": "'$CASSANDRA_CONTAINER_EBS_SIZE'"
        } 
      }
    }
  ]'

  TASK_CONTAINER_DEFINITONS='[
    {
      "name": "'$TASK_DEFINITION_NAME'",
      "image": "'$ACCOUNT_ID'.dkr.ecr.'$REGION'.amazonaws.com/cassandra:'$IMAGE_VERSION'",
      "memoryReservation": '$CASSANDRA_CONTAINER_MEMORY',
      "cpu": '$CASSANDRA_CONTAINER_CPU_UNIT',
      "portMappings": 
      [
        {
          "containerPort": 7000,
          "hostPort": 7000
        },
        {
          "containerPort": 7001,
          "hostPort": 7001
        },
        {
          "containerPort": 7199,
          "hostPort": 7199
        },
        {
          "containerPort": 9042,
          "hostPort": 9042
        },
        {
          "containerPort": 9160,
          "hostPort": 9160
        },
        {
          "containerPort": 9142,
          "hostPort": 9142
        }
      ],
      "logConfiguration": 
      {
        "logDriver": "awslogs",
        "options": 
        {
          "awslogs-group": "/ecs-cluster/'$CLUSTER_NAME'",
          "awslogs-stream-prefix": "/ecs-task-output",
          "awslogs-region": "'$REGION'"
        }
      },
      "environment": 
      [
        { 
          "name": "MAX_HEAP_SIZE",
          "value": "'$CASSANDRA_CONTAINER_MEMORY'M"
        },
        {
          "name": "HEAP_NEWSIZE",
          "value": "'$(( $CASSANDRA_CONTAINER_MEMORY / 4 ))'M"
        },
        { 
          "name": "IS_BACKUP",
          "value": "no"
        },
        { 
          "name": "CLUSTER_NAME",
          "value": "'$CLUSTER_NAME'"
        },
        { 
          "name": "SERVICE_NAME",
          "value": "'$SERVICE_NAME'"
        },
        { 
          "name": "TASKS",
          "value": "'$CASSANDRA_TASKS'"
        },
        { 
          "name": "SNAPSHOT",
          "value": "'$CASSANDRA_SNAPSHOT'"
        },
        { 
          "name": "CASSANDRA_ENDPOINT_SNITCH",
          "value": "GossipingPropertyFileSnitch"
        },
        { 
          "name": "CASSANDRA_DC",
          "value": "DC1"
        },
        { 
          "name": "CASSANDRA_RACK",
          "value": "RAC1"
        }
      ],
      "mountPoints": 
      [
        {
          "sourceVolume": "'$TASK_DEFINITION_NAME'",
          "containerPath": "/var/lib/cassandra",
          "readOnly": false
        }
      ],
      "healthCheck": 
      {
        "command": ["CMD-SHELL", "/healthcheck.sh"],
        "interval": 60,
        "timeout": 30,
        "retries": 2,
        "startPeriod": 300
      }
    }
  ]'
  
  CASSANDRA_TASK_DEFINITION_ID=`aws ecs register-task-definition --region $REGION --family "$TASK_DEFINITION_NAME" --network-mode "awsvpc" --volumes "$TASK_VOLUME" --container-definitions "$TASK_CONTAINER_DEFINITONS" | jq -r '.taskDefinition | .taskDefinitionArn'`

  if [ "`aws ecs list-services --region $REGION --cluster "$CLUSTER_NAME" | jq -r '[.[] | .[] | select(endswith("'$SERVICE_NAME'"))] | length'`" == "0" ]
  then
    aws ecs create-service --region $REGION --service-name "$SERVICE_NAME" --cluster "$CLUSTER_NAME" --task-definition "$CASSANDRA_TASK_DEFINITION_ID" --desired-count 1 --deployment-configuration "minimumHealthyPercent=0,maximumPercent=100" --network-configuration "awsvpcConfiguration={securityGroups=[$SECURITY_GROUP],subnets=[$PRIVATE_SUBNET1,$PRIVATE_SUBNET2]}" --service-registries "registryArn=$CASSANDRA_SERVICE_DISCOVERY_ARN"
  else
    aws ecs update-service --region $REGION --service "$SERVICE_NAME" --cluster "$CLUSTER_NAME" --task-definition "$CASSANDRA_TASK_DEFINITION_ID" --desired-count 1 --deployment-configuration "minimumHealthyPercent=0,maximumPercent=100" --network-configuration "awsvpcConfiguration={securityGroups=[$SECURITY_GROUP],subnets=[$PRIVATE_SUBNET1,$PRIVATE_SUBNET2]}"
  fi
done

#sudo docker build -f devops/docker/cassandra/Dockerfile -t cassandra:test devops/docker/cassandra && ecs-cli push -r us-east-1 cassandra:test && devops/jenkins/scripts/Utilities/createCassandraService.sh us-east-1 dev6007 test WITHOUT 0 10 512 256 AlarmToSlack-dev6007
#sudo docker build -f devops/docker/cassandra/Dockerfile -t cassandra:test devops/docker/cassandra && ecs-cli push -r us-east-1 cassandra:test && devops/jenkins/scripts/Utilities/createCassandraService.sh us-east-1 dev6007 test WITHOUT 3 10 512 256 AlarmToSlack-dev6007