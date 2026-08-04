#!/bin/bash
set -e

mkdir -p /token
chmod 777 /token

echo "Creating Kibana service account token..."

# Delete existing token if any to avoid duplicate name conflict
curl -s -u elastic:${ELASTIC_PASSWORD} -X DELETE http://elasticsearch:9200/_security/service/elastic/kibana/credential/token/kibana > /dev/null 2>&1 || true

RESPONSE=$(curl -s -u elastic:${ELASTIC_PASSWORD} -X POST http://elasticsearch:9200/_security/service/elastic/kibana/credential/token/kibana)

echo "$RESPONSE"

TOKEN=$(echo "$RESPONSE" | sed -n 's/.*"value":"\([^"]*\)".*/\1/p')

if [ -z "$TOKEN" ]; then
    echo "Failed to create token"
    exit 1
fi

echo "$TOKEN" > /token/kibana.token
chmod 644 /token/kibana.token
echo "Done"