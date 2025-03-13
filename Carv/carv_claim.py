from web3 import Web3
import json
import requests
import time
# import ast
import requests



w3 = Web3(Web3.HTTPProvider("https://arbitrum-mainnet.infura.io/v3/93ff81a0346847809ac76f699b69098c"))
ABI = "0x1fab4B4B691a86bb16c296cC06E8cf0c12695B8E"
CONTRACT = "0xa91fF8b606BA57D8c6638Dd8CF3FC7eB15a9c634"

def get_ABI(contract):
    request = "https://api.arbiscan.io/api?module=contract&action=getabi&address="+contract+"&apikey=RVVY832DVQGA39F4IVC82615YYYIGUB1S2"
    
    # print(requests.get(request).json())
    data = str(requests.get(request).json())
    time.sleep(0.3)
    contract_abi = json.loads(data[data.index('['):len(data)-2])
    time.sleep(0.3)
    return contract_abi

def access_Contract(contract, abi):
    aContract = w3.eth.contract(address=contract, abi=get_ABI(abi))
    return aContract

def multicall():
    contract = access_Contract(CONTRACT, ABI)
    time.sleep(0.3)
    string = methodID+wallet
    contract.functions.multicall("0xf39a19bf0000000000000000000000005990c2a11af316987d2d99fe8b813d7c1f0ba0d0").call()
    time.sleep(0.3)
    
mulitcall();
