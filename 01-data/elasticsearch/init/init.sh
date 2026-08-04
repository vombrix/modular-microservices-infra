#!/bin/bash
# ==============================================================================
# Elasticsearch Init Script — Kibana Service Account Token
# ==============================================================================
# Path: 01-data/elasticsearch/init/init.sh
#
# This script generates a Kibana service account token and writes it to a
# shared volume so the Kibana container can authenticate with Elasticsearch.
# ==============================================================================

set -e

TOKEN_DIR="/token"
TOKEN_FILE="${TOKEN_DIR}/kibana.token"

# Ensure token directory exists and is writable
mkdir -p "${TOKEN_DIR}"
chmod 755 "${TOKEN_DIR}"

echo "Creating Kibana service account token..."

# Delete existing token if any to avoid duplicate name conflict
curl -s -u "elastic:${ELASTIC_PASSWORD}" \
  -X DELETE "http://elasticsearch:9200/_security/service/elastic/kibana/credential/token/kibana" \
  > /dev/null 2>&1 || true

# Create a new service account token
RESPONSE=$(curl -s -u "elastic:${ELASTIC_PASSWORD}" \
  -X POST "http://elasticsearch:9200/_security/service/elastic/kibana/credential/token/kibana")

echo "${RESPONSE}"

# Extract the token value from the JSON response
TOKEN=$(echo "${RESPONSE}" | sed -n 's/.*"value":"\([^"]*\)".*/\1/p')

if [ -z "${TOKEN}" ]; then
    echo "ERROR: Failed to create Kibana service account token"
    exit 1
fi

# Save token to shared volume
echo "${TOKEN}" > "${TOKEN_FILE}"
chmod 644 "${TOKEN_FILE}"
echo "✓ Kibana service account token saved to ${TOKEN_FILE}"