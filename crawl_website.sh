#!/usr/bin/env bash

# Website Crawler & Page Counter
# Usage: ./crawl_website.sh <url>
# Requires: curl, xmllint, grep
# Optional: tee (for logging)

# --- Configuration ---
MAX_PAGES=1000          # Maximum number of pages to crawl to prevent infinite loops
TIMEOUT=10              # Curl timeout in seconds
USER_AGENT="WebsiteCrawlerBot/1.0"
MAX_DEPTH=5             # Maximum crawl depth
ALLOWED_EXTENSIONS=("" ".html" ".htm" ".php" ".asp" ".aspx" ".jsp" ".do")
SLEEP_BETWEEN_REQUESTS=0.5  # Sleep time between requests in seconds (be nice to servers)

# --- Globals ---
declare -A VISITED_URLS     # Associative array for tracking visited URLs
declare -A URLS_TO_VISIT    # Queue of URLs to visit
TOTAL_PAGES_FOUND=0         # Counter for pages
CURRENT_DEPTH=0             # Current crawl depth
MAIN_DOMAIN=""              # Extracted main domain to stay within

# --- Functions ---

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

# Function to get just the hostname part of a URL
get_hostname_from_url() {
    local url="$1"
    # Remove scheme
    local no_scheme="${url#*://}"
    # Remove path, query, fragment
    local hostname="${no_scheme%%/*}"
    # Remove port
    hostname="${hostname%%:*}"
    echo "$hostname"
}

# Function to normalize a URL
normalize_url() {
    local url="$1"
    local base_url="$2"
    
    # If URL is empty, return base URL
    if [[ -z "$url" ]]; then
        echo "$base_url"
        return
    fi
    
    # Handle relative URLs
    if [[ "$url" == /* ]]; then
        # URL starts with "/", so it's relative to the domain root
        local domain_root
        if [[ "$base_url" =~ ^(https?://[^/]+) ]]; then
            domain_root="${BASH_REMATCH[1]}"
            echo "${domain_root}${url}"
        else
            # Fallback: just prepend the base URL
            echo "${base_url%/}${url}"
        fi
    elif [[ ! "$url" =~ ^https?: ]]; then
        # URL doesn't start with http(s):, so it's relative to the current page
        local dir_path
        dir_path=$(dirname "$base_url")
        echo "${dir_path%/}/${url}"
    else
        # URL is already absolute
        echo "$url"
    fi
}

# Function to check if a URL's domain matches our main domain
is_same_domain() {
    local url="$1"
    local url_hostname
    
    # Extract hostname
    if [[ "$url" =~ ^https?:// ]]; then
        url_hostname=$(get_hostname_from_url "$url")
    else
        # Not an absolute URL, assume it's on the same domain
        return 0
    fi
    
    # Get domain from hostname
    local url_domain
    url_domain=$(extract_main_domain "$url_hostname")
    
    # Compare with main domain
    if [[ "$url_domain" == "$MAIN_DOMAIN" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a URL has an allowed extension
has_allowed_extension() {
    local url="$1"
    local path="${url#*://*/}"  # Remove protocol and domain
    
    # If path is empty or just a slash, it's the root page
    if [[ -z "$path" || "$path" == "/" ]]; then
        return 0
    fi
    
    # Strip query string and hash
    path=$(echo "$path" | sed -E 's/[?#].*$//')
    
    # Check for known file extensions
    for ext in "${ALLOWED_EXTENSIONS[@]}"; do
        if [[ "$path" == *"$ext" ]]; then
            return 0
        fi
    done
    
    # Check if path has no extension (likely a directory)
    if [[ ! "$path" =~ \.[a-zA-Z0-9]+$ ]]; then
        return 0
    fi
    
    return 1
}

# Function to crawl a page and extract links
crawl_page() {
    local url="$1"
    local depth="$2"
    
    # Check if we've already visited this URL
    if [[ -v VISITED_URLS["$url"] ]]; then
        return 0
    fi
    
    # Mark as visited
    VISITED_URLS["$url"]=1
    TOTAL_PAGES_FOUND=$((TOTAL_PAGES_FOUND + 1))
    
    # Debug output
    printf "[%4d] Depth %d: %s\n" "$TOTAL_PAGES_FOUND" "$depth" "$url"
    
    # Check if we've hit the maximum number of pages
    if [[ $TOTAL_PAGES_FOUND -ge $MAX_PAGES ]]; then
        echo "Reached maximum number of pages ($MAX_PAGES). Stopping crawl."
        return 1
    fi
    
    # Check if we've hit the maximum depth
    if [[ $depth -ge $MAX_DEPTH ]]; then
        return 0
    fi
    
    # Fetch the page
    local content
    content=$(curl -s -L --compressed -A "$USER_AGENT" -m "$TIMEOUT" "$url")
    local curl_status=$?
    
    # Sleep to be nice to the server
    sleep "$SLEEP_BETWEEN_REQUESTS"
    
    # Check if curl succeeded
    if [[ $curl_status -ne 0 ]] || [[ -z "$content" ]]; then
        echo "  Error: Failed to fetch $url (curl status: $curl_status) or content empty."
        return 0
    fi
    
    # Extract links using grep for href attributes
    local links
    links=$(echo "$content" | grep -o 'href="[^"]*"' | sed 's/href="//;s/"$//')
    
    # Process each link
    local normalized_url
    for link in $links; do
        # Normalize the URL
        normalized_url=$(normalize_url "$link" "$url")
        
        # Skip if empty
        if [[ -z "$normalized_url" ]]; then
            continue
        fi
        
        # Check if URL is on the same domain
        if is_same_domain "$normalized_url"; then
            # Check if URL has an allowed extension
            if has_allowed_extension "$normalized_url"; then
                # Add to queue if not already visited
                if [[ ! -v VISITED_URLS["$normalized_url"] ]] && [[ ! -v URLS_TO_VISIT["$normalized_url"] ]]; then
                    URLS_TO_VISIT["$normalized_url"]=$((depth + 1))
                fi
            fi
        fi
    done
    
    return 0
}

# Main function to start crawling
start_crawl() {
    local start_url="$1"
    
    # Normalize the starting URL
    if [[ ! "$start_url" =~ ^https?:// ]]; then
        start_url="https://$start_url"
    fi
    
    # Extract the main domain
    local hostname
    hostname=$(get_hostname_from_url "$start_url")
    MAIN_DOMAIN=$(extract_main_domain "$hostname")
    
    echo "Starting crawl at: $start_url"
    echo "Using main domain: $MAIN_DOMAIN"
    echo "Maximum pages: $MAX_PAGES"
    echo "Maximum depth: $MAX_DEPTH"
    echo "----------------------------------"
    
    # Add the start URL to the queue
    URLS_TO_VISIT["$start_url"]=0
    
    # Process URLs until the queue is empty
    while [[ ${#URLS_TO_VISIT[@]} -gt 0 ]]; do
        # Get the next URL from the queue
        local next_url=""
        local next_depth=0
        
        # Find first URL (this is a bit awkward in bash)
        for url in "${!URLS_TO_VISIT[@]}"; do
            next_url="$url"
            next_depth="${URLS_TO_VISIT[$url]}"
            unset URLS_TO_VISIT["$url"]
            break
        done
        
        # Crawl the page
        crawl_page "$next_url" "$next_depth" || break
    done
    
    # Print summary
    echo "----------------------------------"
    echo "Crawl completed."
    echo "Total pages found: $TOTAL_PAGES_FOUND"
    echo "Total unique URLs: ${#VISITED_URLS[@]}"
}

# --- Main Script ---

# Check dependencies
for cmd in curl grep; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: Required command '$cmd' not found."
        echo "Please install it before running this script."
        exit 1
    fi
done

# Input validation
if [ -z "$1" ]; then
    echo "Usage: $0 <url>"
    echo "Example: $0 example.com"
    echo "Example: $0 https://example.com/start/path"
    exit 1
fi

# Start the crawl
start_crawl "$1"

exit 0 