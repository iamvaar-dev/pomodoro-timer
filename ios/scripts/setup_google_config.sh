#!/bin/bash

# Script to setup Google configuration for iOS build
# This script reads the .env file and sets up the Google iOS Client ID

set -e

# Get the project root directory (3 levels up from this script)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"
CONFIG_FILE="$PROJECT_ROOT/ios/Runner/GoogleService-Info.xcconfig"

echo "Setting up Google configuration for iOS..."
echo "Project root: $PROJECT_ROOT"
echo "Env file: $ENV_FILE"
echo "Config file: $CONFIG_FILE"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Warning: .env file not found at $ENV_FILE"
    echo "Creating default configuration..."
    echo "GOOGLE_IOS_CLIENT_ID = your_ios_client_id_here" > "$CONFIG_FILE"
    exit 0
fi

# Read the Google iOS Client ID from .env file
GOOGLE_IOS_CLIENT_ID=$(grep "^GOOGLE_IOS_CLIENT_ID" "$ENV_FILE" | cut -d '=' -f2 | tr -d ' "'"'"'')

if [ -z "$GOOGLE_IOS_CLIENT_ID" ] || [ "$GOOGLE_IOS_CLIENT_ID" = "your_ios_client_id_here" ]; then
    echo "Warning: GOOGLE_IOS_CLIENT_ID not configured in .env file"
    echo "Using placeholder value..."
    GOOGLE_IOS_CLIENT_ID="your_ios_client_id_here"
fi

# Create the reversed client ID for URL scheme (required for iOS Google Sign-In)
REVERSED_CLIENT_ID=$(echo "$GOOGLE_IOS_CLIENT_ID" | awk -F. '{for(i=NF;i>0;i--) printf "%s%s", $i, (i>1 ? "." : "")}')

# Create the configuration file
cat > "$CONFIG_FILE" << EOF
// Google Service Configuration
// This file is generated automatically - do not edit manually
// Generated from .env file on $(date)

GOOGLE_IOS_CLIENT_ID = $GOOGLE_IOS_CLIENT_ID
GOOGLE_IOS_REVERSED_CLIENT_ID = $REVERSED_CLIENT_ID
EOF

echo "Google iOS configuration updated successfully!"
echo "GOOGLE_IOS_CLIENT_ID = $GOOGLE_IOS_CLIENT_ID"
echo "GOOGLE_IOS_REVERSED_CLIENT_ID = $REVERSED_CLIENT_ID"