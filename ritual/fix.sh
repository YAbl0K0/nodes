#!/bin/bash

cd foundry
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
echo 'export PATH="$PATH:/root/.foundry/bin"' >> .profile
source .profile

foundryup

# Установка зависимостей для контрактов
cd $HOME/infernet-container-starter/projects/hello-world/contracts/lib/
rm -r forge-std
rm -r infernet-sdk
forge install --no-commit foundry-rs/forge-std
forge install --no-commit ritual-net/infernet-sdk

# Deploy Consumer Contract
cd $HOME/infernet-container-starter
project=hello-world make deploy-contracts >> logs.txt
CONTRACT_ADDRESS=$(grep "Deployed SaysHello" logs.txt | awk '{print $NF}')
rm -rf logs.txt

if [ -z "$CONTRACT_ADDRESS" ]; then
  echo -e "${err}Произошла ошибка: не удалось прочитать contractAddress из $CONTRACT_DATA_FILE${end}"
  exit 1
fi

echo -e "${fmt}Адрес вашего контракта: $CONTRACT_ADDRESS${end}"
sed -i 's|0x13D69Cf7d6CE4218F646B759Dcf334D82c023d8e|'$CONTRACT_ADDRESS'|' "$HOME/infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol"

# Call Consumer Contract
cd $HOME/infernet-container-starter
project=hello-world make call-contract

cd $HOME/infernet-container-starter/deploy

docker compose down
sleep 3
sudo rm -rf docker-compose.yaml
wget https://raw.githubusercontent.com/DOUBLE-TOP/guides/main/ritual/docker-compose.yaml
docker compose up -d

docker rm -fv infernet-anvil  &>/dev/null
