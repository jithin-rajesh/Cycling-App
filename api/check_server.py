
import urllib.request
import json
import logging

url = "http://localhost:8000/api/plan"
data = json.dumps({"query": "I want to ride 20 miles"}).encode("utf-8")
req = urllib.request.Request(url, data=data, method="POST")
req.add_header("Content-Type", "application/json")

print(f"Checking {url}...")
try:
    with urllib.request.urlopen(req) as resp:
        print(f"Status: {resp.status}")
        for line in resp:
            print(line.decode("utf-8").strip())
except Exception as e:
    print(f"Error: {e}")
