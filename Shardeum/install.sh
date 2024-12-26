#!/bin/bash

cd $HOME
docker exec -i shardeum-dashboard operator-cli stop

docker image prune -a -f
docker volume prune -f
docker rm -f shardeum-dashboard

apt install expect -y
bash <(curl -s https://raw.githubusercontent.com/DOUBLE-TOP/tools/main/main.sh)
bash <(curl -s https://raw.githubusercontent.com/DOUBLE-TOP/tools/main/docker.sh)
curl -O https://raw.githubusercontent.com/shardeum/shardeum-validator/refs/heads/itn4/install.sh && chmod +x install.sh

expect -c '
set timeout 5

spawn ./install.sh
while 1 {

    expect {
        "By running this installer, you agree to allow the Shardeum team to collect this data. (Y/n)?:" {send "y\r"; exp_continue}
        "What base directory should the node use (default ~/shardeum):" {send "\r"; exp_continue}
        "Do you want to run the web based Dashboard? (Y/n):" {send "\r"; exp_continue}
        "Enter the port (1025-65536) to access the web based Dashboard (default 8080):" {send "8180\r"; exp_continue}
        "If you wish to set an explicit external IP, enter an IPv4 address (default=auto):" {send "\r"; exp_continue}
        "If you wish to set an explicit internal IP, enter an IPv4 address (default=auto):" {send "\r"; exp_continue}
        "This allows p2p communication between nodes. Enter the first port (1025-65536) for p2p communication (default 9001):" {send "\r"; exp_continue}
        "Enter the second port (1025-65536) for p2p communication (default 10001):" {send "\r"; exp_continue}
        -re ".*password.*:" {sleep 1; send "111QwErTy*\r"; exp_continue}
        eof {break}
    }
}
'

rm ./install.sh
source $HOME/.shardeum/.env
cd $HOME
docker exec -i shardeum-validator operator-cli start

echo -e "\033[1;31;40mShardeum установлен. Проверь количество токенов в explorer-sphinx.shardeum.org и делай стейк!\033[m"
