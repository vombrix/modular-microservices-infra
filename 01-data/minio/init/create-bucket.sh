#!/bin/bash

# MinIO Bucket Creation Script
# Path: 01-data/minio/init/create-bucket.sh
#
# This script creates default buckets in MinIO on startup
# Uses the MinIO Client (mc) to create and configure buckets

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "============================================"
echo "MinIO Bucket Initialization"
echo "============================================"
echo ""

# Wait for MinIO to be ready
echo -e "${YELLOW}Waiting for MinIO to be ready...${NC}"
until mc alias set myaistor http://minio:9000 "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}" > /dev/null 2>&1; do
    echo -e "${YELLOW}MinIO is unavailable - sleeping${NC}"
    sleep 2
done

echo -e "${GREEN}✓ MinIO is ready${NC}"
echo ""

# Configure MinIO alias
echo -e "${YELLOW}Configuring MinIO client...${NC}"
mc alias set myaistor http://minio:9000 "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}"
echo -e "${GREEN}✓ MinIO client configured${NC}"
echo ""

# =============================================================================
# Create Buckets
# =============================================================================

echo -e "${YELLOW}Creating buckets...${NC}"

# Bucket list with descriptions
declare -A buckets=(
    ["uploads"]="User uploaded files"
    ["backups"]="System backups"
    ["assets"]="Static assets (public)"
    ["documents"]="Document storage"
    ["images"]="Image storage"
    ["videos"]="Video storage"
    ["logs"]="Log archives"
    ["temp"]="Temporary files"
    ["loki"]="Loki chunks"
    ["pyroscope"]="Pyroscope metrics"
    ["mimir"]="Mimir data"
    ["mimir-ruler"]="Mimir ruler data"
    ["mimir-alertmanager"]="Mimir alertmanager data"
    ["tempo"]="Tempo traces"
)

for bucket in "${!buckets[@]}"; do
    if mc mb --ignore-existing myaistor/${bucket}; then
        echo -e "${GREEN}✓ Created bucket: ${bucket} - ${buckets[$bucket]}${NC}"
    else
        echo -e "${YELLOW}⚠ Bucket ${bucket} already exists${NC}"
    fi
done

echo ""

# =============================================================================
# Set Bucket Policies
# =============================================================================

echo -e "${YELLOW}Configuring bucket policies...${NC}"

# Make 'assets' bucket public for read access
echo -e "Setting public read policy on 'assets' bucket..."
mc anonymous set download myaistor/assets
echo -e "${GREEN}✓ Assets bucket is now publicly readable${NC}"

# Make 'images' bucket public for read access
echo -e "Setting public read policy on 'images' bucket..."
mc anonymous set download myaistor/images
echo -e "${GREEN}✓ Images bucket is now publicly readable${NC}"

echo ""

# =============================================================================
# Enable Versioning
# =============================================================================

echo -e "${YELLOW}Enabling versioning on critical buckets...${NC}"

for bucket in backups documents; do
    if mc version enable myaistor/${bucket}; then
        echo -e "${GREEN}✓ Versioning enabled on ${bucket}${NC}"
    else
        echo -e "${RED}✗ Failed to enable versioning on ${bucket}${NC}"
    fi
done

echo ""

# =============================================================================
# Set Lifecycle Policies
# =============================================================================

echo -e "${YELLOW}Setting lifecycle policies...${NC}"

# Create lifecycle policy for temp bucket (delete after 7 days)
cat > /tmp/temp-lifecycle.json << EOF
{
    "Rules": [
        {
            "ID": "DeleteTempFilesAfter7Days",
            "Status": "Enabled",
            "Expiration": {
                "Days": 7
            }
        }
    ]
}
EOF

mc ilm import myaistor/temp < /tmp/temp-lifecycle.json
echo -e "${GREEN}✓ Lifecycle policy set on 'temp' bucket (7 days retention)${NC}"

# Create lifecycle policy for logs bucket (delete after 30 days)
cat > /tmp/logs-lifecycle.json << EOF
{
    "Rules": [
        {
            "ID": "DeleteLogsAfter30Days",
            "Status": "Enabled",
            "Expiration": {
                "Days": 30
            }
        }
    ]
}
EOF

mc ilm import myaistor/logs < /tmp/logs-lifecycle.json
echo -e "${GREEN}✓ Lifecycle policy set on 'logs' bucket (30 days retention)${NC}"

echo ""

# =============================================================================
# Create Service Accounts
# =============================================================================

echo -e "${YELLOW}Creating service accounts...${NC}"

# Application service account (read/write access to uploads, documents, images)
if mc admin user add myaistor app-service "${APP_SERVICE_PASSWORD:-change_me}"; then
    echo -e "${GREEN}✓ Created service account: app-service${NC}"
    
    # Create policy for app-service
    cat > /tmp/app-service-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::uploads/*",
                "arn:aws:s3:::uploads",
                "arn:aws:s3:::documents/*",
                "arn:aws:s3:::documents",
                "arn:aws:s3:::images/*",
                "arn:aws:s3:::images"
            ]
        }
    ]
}
EOF
    
    mc admin policy create myaistor app-service-policy /tmp/app-service-policy.json
    mc admin policy attach myaistor app-service-policy --user app-service
    echo -e "${GREEN}✓ Policy attached to app-service${NC}"
fi

# Backup service account (read/write access to backups)
if mc admin user add myaistor backup-service "${BACKUP_SERVICE_PASSWORD:-change_me}"; then
    echo -e "${GREEN}✓ Created service account: backup-service${NC}"
    
    # Attach built-in readwrite policy to backup bucket
    mc admin policy attach myaistor readwrite --user backup-service
    echo -e "${GREEN}✓ Policy attached to backup-service${NC}"
fi

# Observability service account (read/write access to loki, tempo, mimir, pyroscope)
if mc admin user add myaistor observability-service "${OBSERVABILITY_SERVICE_PASSWORD:-change_me_observability}"; then
    echo -e "${GREEN}✓ Created service account: observability-service${NC}"
    
    # Create policy for observability-service
    cat > /tmp/observability-service-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "s3:AbortMultipartUpload",
                "s3:GetObjectTagging",
                "s3:PutObjectTagging"
            ],
            "Resource": [
                "arn:aws:s3:::loki/*",
                "arn:aws:s3:::loki",
                "arn:aws:s3:::tempo/*",
                "arn:aws:s3:::tempo",
                "arn:aws:s3:::mimir/*",
                "arn:aws:s3:::mimir",
                "arn:aws:s3:::mimir-ruler/*",
                "arn:aws:s3:::mimir-ruler",
                "arn:aws:s3:::mimir-alertmanager/*",
                "arn:aws:s3:::mimir-alertmanager",
                "arn:aws:s3:::pyroscope/*",
                "arn:aws:s3:::pyroscope"
            ]
        }
    ]
}
EOF
    
    mc admin policy create myaistor observability-service-policy /tmp/observability-service-policy.json
    mc admin policy attach myaistor observability-service-policy --user observability-service
    echo -e "${GREEN}✓ Policy attached to observability-service${NC}"
fi

echo ""

# =============================================================================
# Summary
# =============================================================================

echo "============================================"
echo "MinIO Initialization Complete"
echo "============================================"
echo ""
echo -e "${GREEN}Buckets Created:${NC}"
mc ls myaistor | while read -r _ _ _ name; do
    echo "  • ${name}"
done
echo ""
echo -e "${GREEN}Public Buckets:${NC}"
echo "  • assets (read-only)"
echo "  • images (read-only)"
echo ""
echo -e "${GREEN}Buckets with Versioning:${NC}"
echo "  • backups"
echo "  • documents"
echo ""
echo -e "${GREEN}Buckets with Lifecycle Policies:${NC}"
echo "  • temp (7 days retention)"
echo "  • logs (30 days retention)"
echo ""
echo -e "${GREEN}Service Accounts Created:${NC}"
echo "  • app-service (access to uploads, documents, images)"
echo "  • backup-service (access to backups)"
echo ""
echo -e "${YELLOW}Access MinIO Console:${NC}"
echo "  URL: http://localhost:9001"
echo "  User: ${MINIO_ROOT_USER}"
echo "  Password: [configured in .env]"
echo ""
echo -e "${GREEN}✓ MinIO is ready for use${NC}"