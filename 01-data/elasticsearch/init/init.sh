#!/bin/bash
set -e

TOKEN_DIR=/usr/share/elasticsearch/kibana-token
TOKEN_FILE="$TOKEN_DIR/kibana.token"

# Ensure token directory exists
mkdir -p "$TOKEN_DIR"

# Function to check if token is valid
check_token() {
  local token=$1
  # Test the token against Elasticsearch
  # Replace <ELASTICSEARCH_URL> with your ES endpoint, e.g., http://localhost:9200
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" http://localhost:9200)
  if [ "$HTTP_STATUS" = "200" ]; then
    return 0   # valid
  else
    return 1   # invalid
  fi
}

if [ -f "$TOKEN_FILE" ]; then
  EXISTING_TOKEN=$(cat "$TOKEN_FILE")
  if check_token "$EXISTING_TOKEN"; then
    echo "Token already exists and is valid."
    exit 0
  else
    echo "Existing token is invalid, generating a new one..."
  fi
else
  echo "No token found, generating a new one..."
fi

# Generate new Kibana service token
SERVICE_TOKEN=$(elasticsearch-service-tokens create elastic/kibana kibana)
TOKEN_ONLY=$(echo "$SERVICE_TOKEN" | awk -F'= ' '{print $2}')

# Save token
echo "$TOKEN_ONLY" > "$TOKEN_FILE"
echo "Token saved to $TOKEN_FILE"
