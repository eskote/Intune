#! /bin/bash

server_IP="10.19.88.250"
ssh_user="user"

ssh $ssh_user@$server_IP "uptime"

