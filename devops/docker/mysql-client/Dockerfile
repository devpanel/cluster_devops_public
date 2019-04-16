FROM ubuntu:16.04

#== install pre-requisites
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    apt-get install -y wget && apt-get install zip unzip jq -y

#== install "mysqldump" and "mysql"
RUN apt-get install -y mysql-client

#== install aws-cli
RUN apt-get install -y unzip && \
    apt-get --reinstall install -y python-minimal && \
    wget https://s3.amazonaws.com/aws-cli/awscli-bundle.zip && \
    unzip awscli-bundle.zip && \
    ./awscli-bundle/install -i /usr/local/aws -b /usr/bin/aws && \
    rm -rf awscli-bundle*

#== add permissions for scripts
COPY root/ /
RUN chmod +x /*.sh
