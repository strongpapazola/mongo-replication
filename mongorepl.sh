#!/bin/bash
source color.sh
PROCESS=$blue"[*]"$foreground_color
SUCCESS=$green"[+]"$foreground_color
FAILED=$red"[-]"$foreground_color
IP_HOST=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
PORT1="30001"
PORT2="30002"
PORT3="30003"

#read -p "it's your ip : [$IP_HOST] (y/n)?" CONFIRM
#if [ "$CONFIRM" == "n" ];then
#	read -p "Insert IP : " IP_HOST
#fi

echo -e $SUCCESS "IP HOST : $IP_HOST"

create(){
echo -e "$PROCESS Creating Docker Instanse"
docker run -d -p $PORT1:27017 -v mongo1:/data/db --name mongo1 mongo mongod --replSet my-mongo-set
docker run -d -p $PORT2:27017 -v mongo2:/data/db --name mongo2 mongo mongod --replSet my-mongo-set
docker run -d -p $PORT3:27017 -v mongo3:/data/db --name mongo3 mongo mongod --replSet my-mongo-set
echo -e "$SUCCESS Docker Instanse Created"
echo -e "$PROCESS Creating Docker Network"
docker network create my-mongo-cluster
docker network connect my-mongo-cluster mongo1
docker network connect my-mongo-cluster mongo2
docker network connect my-mongo-cluster mongo3
echo -e "$SUCCESS Docker Network Created"

docker run --rm mongo mongo --eval "rs.initiate({ _id: 'my-mongo-set', members: [ {_id: 0, host: '$IP_HOST:$PORT1'}, {_id: 1, host: '$IP_HOST:$PORT2'}, {_id: 2, host: '$IP_HOST:$PORT3'} ]})" $IP_HOST:$PORT1
echo -e $PROCESS "Writing Node Replication On mongo1"
echo -e $PROCESS "Run : mongo --eval rs.initiate({ _id: 'my-mongo-set', members: [ {_id: 0, host: '$IP_HOST:$PORT1'}, {_id: 1, host: '$IP_HOST:$PORT2'}, {_id: 2, host: '$IP_HOST:$PORT3'} ]})" $IP_HOST:$PORT1
echo -e $SUCCESS "MongoDB Replication Was Created...!"
echo -e $SUCCESS "address : mongodb://$IP_HOST:$PORT1,$IP_HOST:$PORT2,$IP_HOST:$PORT3/admin?replicaSet=my-mongo-set"
}

delete(){
echo -e "$PROCESS Cleaning Docker MongoDB Instance"
docker container stop mongo1 mongo2 mongo3
docker container rm mongo1 mongo2 mongo3
docker network rm my-mongo-cluster
echo -e "$SUCCESS Docker MongoDB Instance Cleared"
echo -e "$PROCESS Cleaning Docker MongoDB Data Volume"
rm -rf /var/lib/docker/volumes/mongo1
rm -rf /var/lib/docker/volumes/mongo2
rm -rf /var/lib/docker/volumes/mongo3
echo -e "$SUCCESS Docker MongoDB Data Volume Cleared"
echo -e "$PROCESS Restarting Docker"
service docker restart
echo -e "$SUCCESS Docker Restarted"
echo -e $SUCCESS "MongoDB Replication Was Deleted...!"
}

auth(){
docker run --rm -it mongo mongo mongodb://$IP_HOST:$PORT1,$IP_HOST:$PORT2,$IP_HOST:$PORT3/admin?replicaSet=my-mongo-set --eval "db.createUser({user: 'admin', pwd: 'admin', roles: [{role:'userAdminAnyDatabase', db: 'admin'}, 'readWriteAnyDatabase']})"
#echo docker run --rm -it mongo mongo mongodb://$IP_HOST:$PORT1,$IP_HOST:$PORT2,$IP_HOST:$PORT3/admin?replicaSet=my-mongo-set --eval "db.createUser({user: 'admin', pwd: 'admin', roles: [{role:'userAdminAnyDatabase', db: 'admin'}, 'readWriteAnyDatabase']})"
echo -e $PROCESS "Adding User Into All Replica..."
echo -e $PROCESS "Run : mongo mongodb://$IP_HOST:$PORT1,$IP_HOST:$PORT2,$IP_HOST:$PORT3/admin?replicaSet=my-mongo-set --eval"
echo -e $PROCESS "\"db.createUser({user: 'admin', pwd: 'admin', roles: [{role:'userAdminAnyDatabase', db: 'admin'}, 'readWriteAnyDatabase']})\""


echo -e "$PROCESS Generating KeyFile to keyfile.pem"
openssl rand -base64 756 > keyfile.pem && chmod 400 keyfile.pem
echo -e "$SUCCESS KeyFile to keyfile.pem Generated"
echo -e "$PROCESS Stopping Docker MongoDB Container"
docker container stop mongo1 mongo2 mongo3
docker container rm mongo1 mongo2 mongo3
echo -e "$SUCCESS Docker MongoDB Container Stopped"
echo -e "$PROCESS Copying Keyfile MongoDB Volume"
cp keyfile.pem /var/lib/docker/volumes/mongo1/_data/
cp keyfile.pem /var/lib/docker/volumes/mongo2/_data/
cp keyfile.pem /var/lib/docker/volumes/mongo3/_data/
echo -e "$SUCCESS Docker MongoDB Keyfile Copied"
echo -e $PROCESS "Run : mongod --keyFile '/data/db/keyfile.pem' --replSet my-mongo-set --auth"
docker run -d -p $PORT1:27017 -v mongo1:/data/db --name mongo1 --restart unless-stopped mongo mongod --keyFile '/data/db/keyfile.pem' --replSet my-mongo-set --auth
docker run -d -p $PORT2:27017 -v mongo2:/data/db --name mongo2 --restart unless-stopped mongo mongod --keyFile '/data/db/keyfile.pem' --replSet my-mongo-set --auth
docker run -d -p $PORT3:27017 -v mongo3:/data/db --name mongo3 --restart unless-stopped mongo mongod --keyFile '/data/db/keyfile.pem' --replSet my-mongo-set --auth
echo -e $SUCCESS "address : mongodb://admin:admin@$IP_HOST:$PORT1,$IP_HOST:$PORT2,$IP_HOST:$PORT3/admin?replicaSet=my-mongo-set"
echo -e "$SUCCESS MongoDB Authentication With Keyfile Was Added...!"
}

if [ "$1" == "create" ];then
create
elif [ "$1" == "delete" ];then
delete
elif [ "$1" == "auth" ];then
auth
elif [ "$1" == "mongo" ];then
docker run -it --rm mongo mongo $2
else
echo -e $FAILED "Please Type Argument [create/delete/auth/mongo]"
fi

