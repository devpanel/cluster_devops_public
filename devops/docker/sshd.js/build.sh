#!/bin/bash

sudo docker build -t sshd .
sudo docker run -p 23:23 -e CLUSTER_NAME=dev5001 -e REGION=eu-central-1 sshd