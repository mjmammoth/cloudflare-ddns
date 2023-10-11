#!/bin/bash

HEADERS=(-H "X-Auth-Email: $EMAIL" -H "X-Auth-Key: $API_KEY" -H "Content-Type: application/json")

# Load cache if exists
if [[ -f $CACHE_FILE ]]; then
    source $CACHE_FILE
fi

# Get the Zone ID
if [[ -z $ZONE_ID ]]; then
    echo "Fetching Zone ID"
    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" \
    "${HEADERS[@]}" | jq -r '.result[0].id')
    echo "Fetched Zone ID: $ZONE_ID"
    echo "ZONE_ID=$ZONE_ID" >> $CACHE_FILE
else
    echo "Using cached Zone ID: $ZONE_ID"
fi

# Check for a valid Zone ID
if [ -z "$ZONE_ID" ]; then
    echo "Failed to retrieve Zone ID"
    exit 1
fi


# Get the Record ID
if [[ -z $RECORD_ID ]]; then
    echo "Fetching Record ID"
    RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$RECORD_NAME.$ZONE_NAME" \
    "${HEADERS[@]}" \
    | jq -r '.result[0].id')
    echo "Fetched Record ID: $RECORD_ID"
    echo "RECORD_ID=$RECORD_ID" >> $CACHE_FILE
else
    echo "Using cached Record ID: $RECORD_ID"
fi

# Check for a valid Record ID
if [ -z "$RECORD_ID" ]; then
    echo "Failed to retrieve Record ID"
    exit 1
fi

# Get Your IP Address
CURRENT_IP_ADDRESS=$(curl -s ifconfig.me)

if [[ $CURRENT_IP_ADDRESS == $CACHED_IP_ADDRESS ]]; then
    echo "IP Address has not changed"
    exit 0
fi

# If there is no cached IP, dig the IP and exit out if it is still the same
if [[ -z $CACHED_IP_ADDRESS ]]; then
    echo "Fetching DNS Record"
    CACHED_IP_ADDRESS=$(dig +short $RECORD_NAME.$ZONE_NAME | tail -n1)
    echo "Fetched DNS Record: $CACHED_IP_ADDRESS"
    echo "CACHED_IP_ADDRESS=$CACHED_IP_ADDRESS" >> $CACHE_FILE
    if [[ $CURRENT_IP_ADDRESS == $CACHED_IP_ADDRESS ]]; then
        echo "IP Address has not changed"
        exit 0
    fi
fi

echo "IP Address has changed to $IP_ADDRESS"
echo "CACHED_IP_ADDRESS=$IP_ADDRESS" >> $CACHE_FILE
# Update the DNS record
UPDATE_RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
"${HEADERS[@]}" \
--data '{"type":"A","name":"'"$RECORD_NAME"'","content":"'"$IP_ADDRESS"'","ttl":120,"proxied":false}' | jq -r '.success')

# Check for a successful update
if [ "$UPDATE_RESULT" != "true" ]; then
    echo "Failed to update DNS record"
    exit 1
fi

echo "DNS record updated successfully"


