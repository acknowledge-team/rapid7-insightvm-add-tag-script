import requests, json, sys, base64, urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

########################
# Edit these variables #
########################
username = "admin" # ID of an IVM administrator
password = "" # Password of the IVM administrator
BASE_DOMAIN = "https://10.1.1.1:3780" # Access domain/IP to IVM in format https://<domain>:<port>
TAG_NAME = "EXPOSED" # Name of the tag to add to assets. Case sensitive
########################

BASE_URL = f"{BASE_DOMAIN}/api/3"
credentials = base64.b64encode(f"{username}:{password}".encode()).decode("utf-8")
TAG_ID = -1

headers = {
    "Content-Type": "application/json",
    "Authorization": f"Basic {credentials}"
}

def search_assets(ip):
    print(f"========== SEARCHING ASSETS IN IVM WITH IP \"{ip}\" ==========")
    url = BASE_URL + "/assets/search"
    data = {
        "filters": [
            {
                "field": "ip-address",
                "operator": "is",
                "value": ip
            }
        ],
        'match': "any"
    }
    resp = requests.post(url, headers=headers, data=json.dumps(data), verify=False).json()
    asset_ids = []
    for asset in resp["resources"]:
        print(f"Asset ID : {asset['id']} ; {BASE_DOMAIN}/asset.jsp?devid={asset['id']}")
        asset_ids.append(asset["id"])
    
    return asset_ids

def asset_tags(method, asset_id, tag_id : int = None):
    if method == "GET":
        print("======= PRINTING ASSET TAGS =======")
        url = BASE_URL + f"/assets/{asset_id}/tags"
        resp = requests.request(method, url, headers=headers, verify=False).json()
        
        for tag in resp["resources"]:
            print(f'{tag["name"]} ; {tag["source"]} ; {tag["type"]}')
        
        return resp["resources"]
    
    elif method == "PUT":
        print(f"===== ADDING TAG \"{TAG_NAME}\" TO ASSET =====")
        url = BASE_URL + f"/assets/{asset_id}/tags/{tag_id}"
        resp = requests.request(method, url, headers=headers, verify=False)
        

def search_tags():
    print("========== PRINTING TAGS IN IVM ==========")
    print(f"{BASE_DOMAIN}/tag/listing.jsp")
    url = BASE_URL + "/tags"
    resp = requests.get(url, headers=headers, verify=False).json()
    tags = []

    for tag in resp["resources"]:
        tags.append(tag)

    for x in range(1, resp["page"]["totalPages"]+1):
        url = BASE_URL + "/tags?page=" + str(x)
        resp = requests.get(url, headers=headers, verify=False).json()
        for tag in resp["resources"]:
            tags.append(tag)
    
    tags = sorted(tags, key=lambda x: x["id"])

    for tag in tags:
        print(f'{tag["id"]} ; {tag["name"]} ; {tag["source"]} ; {tag["type"]}')
    
    return tags

def create_tag():
    print(f"===== CREATING TAG \"{TAG_NAME}\" IN IVM =====")
    url = BASE_URL + "/tags"
    data = {
        'name': TAG_NAME,
        'type': 'custom'
    }
    resp = requests.post(url, headers=headers, data=json.dumps(data), verify=False).json()
    
    return resp["id"]

def main():
    if len(sys.argv) != 2:
        print("Usage:\nLinux : python3 main.py <text file with all IPs>\nWindows : py -3 main.py <text file with all IPs>")
        return
    else :
        try :
            ip_list = []
            with open(sys.argv[1], "r") as file:
                for ip in file:
                    ip_list.append(ip.strip())
        except :
            print(f"Unable to open {sys.argv[1]}")
            return

    global TAG_ID
    asset_number = 0
    for ip in ip_list:
        asset_ids = search_assets(ip)

        for asset_id in asset_ids:

            tags = asset_tags("GET", asset_id)
            found = 0
            for tag in tags:
                if tag["name"] == TAG_NAME :
                    print(f"===== TAG \"{TAG_NAME}\" ALREADY GIVEN TO ASSET \"{ip}\" / \"{asset_id}\"=====\n")
                    TAG_ID = tag["id"]
                    found = 1
                    break

            if found == 0 :
                if TAG_ID == -1:
                    global_tags = search_tags()
                    for tag in global_tags:
                        if tag["name"] == TAG_NAME :
                            TAG_ID = tag["id"]
                            print(f"===== FOUND TAG \"{TAG_NAME}\" IN IVM WITH ID {TAG_ID} =====")
                            print(f"{BASE_DOMAIN}/tag/detail.jsp?tagID={TAG_ID}")
                            break
                
                if TAG_ID == -1:
                    TAG_ID = create_tag()
                    print(f"{TAG_NAME} ; {TAG_ID} ; {BASE_DOMAIN}/tag/detail.jsp?tagID={TAG_ID}")
                
                asset_tags("PUT", asset_id, TAG_ID)
                
                print(f"======= TAG \"{TAG_NAME}\" ADDED TO ASSET \"{ip}\" / \"{asset_id}\" =======\n")
                asset_number += 1

    if asset_number > 0 :
        print(f"Successfully tagged {asset_number} assets")
    else :
        print("All assets were already tagged")

        
if __name__ == "__main__":
    main()
