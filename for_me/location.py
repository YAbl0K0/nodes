import requests

ip = "8.8.8.8"  # замените на нужный IP
response = requests.get(f"http://ip-api.com/json/{ip}")
data = response.json()

print(f"IP: {data['query']}")
print(f"Country: {data['country']}")
print(f"Region: {data['regionName']}")
print(f"City: {data['city']}")
print(f"ISP: {data['isp']}")
