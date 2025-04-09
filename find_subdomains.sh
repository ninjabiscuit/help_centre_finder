#!/usr/bin/env bash

# Aggressive Subdomain Finder
# Usage: ./find_subdomains.sh <domain.com>
# Requires: curl, jq, host (or dig)

# --- Configuration ---
# Add more common subdomains here if needed
COMMON_SUBDOMAINS=(
    "www" "mail" "email" "remote" "blog" "shop" "store" "dev" "staging"
    "test" "api" "app" "admin" "dashboard" "portal" "ftp" "webmail" "m"
    "vpn" "support" "help" "status" "docs" "developer" "careers" "jobs"
    "news" "media" "assets" "static" "cdn" "owa" "jira" "confluence"
)

# --- Functions ---

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a subdomain resolves
check_host() {
    local subdomain="$1"
    if host "$subdomain" &> /dev/null; then
        echo "$subdomain"
    fi
}

# --- Main Script ---

# Input validation
if [ -z "$1" ]; then
    echo "Usage: $0 <domain.com>"
    echo "Example: $0 example.com"
    exit 1
fi

# Check dependencies
for cmd in curl jq host; do
    if ! command_exists "$cmd"; then
        echo "Error: Required command '$cmd' not found."
        echo "Please install it (e.g., brew install $cmd or apt install $cmd)."
        exit 1
    fi
done

# Extract base domain (remove protocol, www., paths)
DOMAIN=$(echo "$1" | sed -e 's|^[^/]*//||' -e 's/^www\.//' -e 's|/.*$||')
echo "🔍 Finding subdomains for: $DOMAIN"

# Temporary file for collecting results uniquely
FOUND_SUBDOMAINS_TMP=$(mktemp)
# Ensure temp file is removed on exit
trap 'rm -f "$FOUND_SUBDOMAINS_TMP"' EXIT

# 1. Query crt.sh (Certificate Transparency Logs)
echo "[+] Querying crt.sh..."
curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" | jq -r '.[].name_value' | \
    sed -e 's/^\*\.//' -e 's/^CN=//' | \
    grep -E "\\.$DOMAIN$" | \
    grep -vE '@' | \
    sort -u >> "$FOUND_SUBDOMAINS_TMP"

# 2. Check robots.txt (Try https and http, www and non-www)
echo "[+] Checking robots.txt..."
for proto in https http; do
    for prefix in www. ""; do
        url="${proto}://${prefix}${DOMAIN}/robots.txt"
        curl -s -L -m 5 "$url" | \
            grep -ioE 'https?://[^ ]+' | \
            awk -F/ '{print $3}' | \
            tr '[:upper:]' '[:lower:]' | \
            grep "\\.$DOMAIN$" >> "$FOUND_SUBDOMAINS_TMP"
    done
done

# 3. Scrape Homepage (Try https and http)
echo "[+] Scraping homepage..."
for proto in https http; do
    url="${proto}://${DOMAIN}"
     curl -s -L -m 10 "$url" | \
        grep -ioE '(href|src)="https?://[^"]+"' | \
        grep -ioE 'https?://[^"]+' | \
        awk -F/ '{print $3}' | \
        tr '[:upper:]' '[:lower:]' | \
        grep "\\.$DOMAIN$" >> "$FOUND_SUBDOMAINS_TMP"
done

# 4. Check Common Subdomains
echo "[+] Checking common subdomains..."
for sub in "${COMMON_SUBDOMAINS[@]}"; do
   check_host "$sub.$DOMAIN" >> "$FOUND_SUBDOMAINS_TMP"
done

# --- Output Results ---
echo
echo "✅ Found Subdomains:"
# Sort and print unique results
sort -u "$FOUND_SUBDOMAINS_TMP"

# Check if any subdomains were found
if [ ! -s "$FOUND_SUBDOMAINS_TMP" ]; then
  echo "  (None found using these methods)"
fi

exit 0
