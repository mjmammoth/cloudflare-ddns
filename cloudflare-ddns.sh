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
    if [[ $CURRENT_IP_ADDRESS == $CACHED_IP_ADDRESS ]]; then
        echo "IP Address has not changed"
        exit 0
    fi
fi

echo "IP Address has changed to $CURRENT_IP_ADDRESS"

# Use grep to check if the CACHED_IP_ADDRESS line exists in the cache file
grep -q "CACHED_IP_ADDRESS=" $CACHE_FILE

# $? is a special variable that holds the exit status of the last command executed
if [[ $? -eq 0 ]]; then
    # If the line exists, use sed to replace it
    TEMP_FILE=$(mktemp)
    sed "s/CACHED_IP_ADDRESS=.*/CACHED_IP_ADDRESS=$CURRENT_IP_ADDRESS/" $CACHE_FILE > $TEMP_FILE
    mv $TEMP_FILE $CACHE_FILE
else
    # If the line does not exist, append it to the file
    echo "CACHED_IP_ADDRESS=$CURRENT_IP_ADDRESS" >> $CACHE_FILE
fi

# Update the DNS record
UPDATE_RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
"${HEADERS[@]}" \
--data '{"type":"A","name":"'"$RECORD_NAME"'","content":"'"$CURRENT_IP_ADDRESS"'","ttl":120,"proxied":false}' | jq -r '.success')

# Check for a successful update
if [ "$UPDATE_RESULT" != "true" ]; then
    echo "Failed to update DNS record"
    exit 1
fi

echo "DNS record updated successfully"


