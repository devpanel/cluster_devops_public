#!/bin/bash


docker build -t mysql-client .
ecs-cli push -r ap-northeast-2 mysql-client