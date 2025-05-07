#!/usr/bin/env bash

# Function to extract the main domain (e.g., example.com) from a URL or hostname
# Handles schemes, paths, ports, and basic subdomains
extract_main_domain() {
    local input="$1"
    local hostname_part
    # Remove scheme (http://, https://, etc.)
    hostname_part=$(echo "$input" | sed -E 's#^[^/]*://##')
    # Remove path and query string (/path, ?query)
    hostname_part=$(echo "$hostname_part" | sed -E 's#[/?].*##')
    # Remove port (:8080)
    hostname_part=$(echo "$hostname_part" | sed -E 's#:.*##')

    # List of known multi-part TLDs (extend as needed)
    local multi_part_tlds=("co.uk" "com.au" "co.nz" "co.jp" "org.uk" "me.uk" "net.uk" "ac.uk" "gov.uk" "org.au" "net.au" "id.au" "com.sg" "edu.sg" "gov.sg" "net.sg" "org.sg")
    
    # Try to match against known multi-part TLDs first
    for tld in "${multi_part_tlds[@]}"; do
        if [[ "$hostname_part" == *".$tld" ]]; then
            # Extract part before the TLD using pattern matching
            local domain_part="${hostname_part%.$tld}"
            # If there are subdomains, get the last part before the TLD
            if [[ "$domain_part" == *"."* ]]; then
                domain_part="${domain_part##*.}"
            fi
            echo "$domain_part.$tld"
            return
        fi
    done
    
    # Fall back to the original implementation for standard TLDs
    # Extract main domain using awk (gets last two .-separated parts)
    echo "$hostname_part" | awk -F. '{ if (NF >= 2) { print $(NF-1)"."$NF } else { print $0 } }'
}

# Test domains
test_domains=(
    "example.com"
    "www.example.com"
    "sub.example.com"
    "example.co.uk"
    "www.example.co.uk"
    "sub.example.co.uk"
    "deep.sub.example.co.uk"
    "example.com.au"
    "sub.example.com.au"
    "https://example.com/path"
    "https://sub.example.co.uk/path?query=1"
    "example.com:8080"
    "sub.example.gov.uk"
)

# Test the function with each domain
for domain in "${test_domains[@]}"; do
    main_domain=$(extract_main_domain "$domain")
    echo "Input: $domain → Main Domain: $main_domain"
done 