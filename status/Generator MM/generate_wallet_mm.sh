#!/bin/bash

set -e
mkdir -p evd_addr && cd evd_addr

apt update && apt install -y python3-venv python3-pip curl

python3 -m venv venv --without-pip

source venv/bin/activate

curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python get-pip.py --quiet
rm get-pip.py

pip install --quiet eth-account

wget https://raw.githubusercontent.com/YAbl0K0/nodes/master/status/Generator%20MM/wallets.py

python wallets.py

deactivate

cd ..
