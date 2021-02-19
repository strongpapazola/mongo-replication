#!/bin/bash
source color.sh
IP_HOST=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
echo -e $PROCESS IP HOST : $IP_HOST
docker run -d -p 27017:27017 -v data:/data/db/ --name mongodocker mongo
docker run --rm -it mongo mongo mongodb://$IP_HOST:27017/admin --eval "db.createUser({user: 'admin', pwd: 'admin', roles: [{role:'userAdminAnyDatabase', db: 'admin'}, 'readWriteAnyDatabase']})"
docker container stop mongodocker
docker container rm mongodocker
docker run -d -p 27017:27017 -v data:/data/db/ --restart unless-stopped --name mongodocker mongo mongod --auth
docker run -it --rm mongo mongo mongodb://admin:admin@$IP_HOST:27017/admin
