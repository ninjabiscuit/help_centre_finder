#!/usr/bin/env bash

# Usage: ./count_urls_from_sitemap.sh https://example.com/sitemap.xml

# Requires: curl, xmllint
# Installs xmllint with: brew install libxml2

declare -A sitemap_counts
total_urls=0

# Define a browser-like user agent
BROWSER_USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"

function fetch_and_count() {
    local sitemap_url="$1"
    local indent="$2"

    echo "${indent}Fetching: $sitemap_url"

    # Fetch content with L flag to follow redirects and use browser-like user agent
    content=$(curl -s -L -A "$BROWSER_USER_AGENT" "$sitemap_url")
    if [[ -z "$content" ]]; then
        echo "${indent}Error: Failed to fetch $sitemap_url or content is empty."
        return 1 # Indicate failure
    fi

    # Save the first 20 lines for debugging
    echo "${indent}First 20 lines of content:"
    echo "$content" | head -n 20 | sed "s/^/${indent}  /"

    # Check if it's a sitemapindex (case-insensitive)
    if echo "$content" | grep -iq "<sitemapindex"; then
        echo "${indent}Detected sitemap index."
        # Use local-name() to handle potential default namespace
        # Capture xmllint output/errors
        xmllint_output=$(echo "$content" | xmllint --xpath "//*[local-name()='sitemapindex']/*[local-name()='sitemap']/*[local-name()='loc']/text()" - 2>/dev/null)
        xmllint_status=$?

        if [[ $xmllint_status -eq 0 ]] && [[ -n "$xmllint_output" ]]; then
            mapfile -t subsitemaps < <(echo "$xmllint_output")
            echo "${indent}Found ${#subsitemaps[@]} sub-sitemaps."
            local success=0 # Track if all sub-fetches succeed
            for sub in "${subsitemaps[@]}"; do
                fetch_and_count "$sub" "  $indent" || success=1 # Propagate failure up
            done
            return $success
        else
            echo "${indent}Warning: Failed to extract sub-sitemaps from index $sitemap_url (xmllint status: $xmllint_status)."
             # Optional: Show first few lines of content for debugging
            echo "${indent}Content start: $(echo "$content" | head -n 5)"
            return 1 # Indicate failure
        fi
    # Check if it's a urlset (case-insensitive)
    elif echo "$content" | grep -iq "<urlset"; then
        echo "${indent}Detected urlset."
        # Count urls (case-insensitive tag)
        count=$(echo "$content" | grep -ic "<url>")
        if [[ $? -ne 0 ]]; then
             # Handle cases where grep finds no matches (exit code 1) but it's not an error
             count=0
        fi
        sitemap_counts["$sitemap_url"]=$count
        total_urls=$((total_urls + count))
        echo "${indent}Counted $count URLs."
        return 0 # Indicate success
    else
        echo "${indent}Error: Unknown sitemap format at $sitemap_url"
        # Optional: Show first few lines of content for debugging
        echo "${indent}Content start: $(echo "$content" | head -n 5)"
        return 1 # Indicate failure
    fi
}

if [ -z "$1" ]; then
    echo "Usage: $0 <sitemap_url>"
    exit 1
fi

# Clear previous results
sitemap_counts=()
total_urls=0

# Start fetching and handle potential errors
fetch_and_count "$1" ""
fetch_status=$?

echo
if [[ $fetch_status -ne 0 ]]; then
     echo "⚠️ Processing finished with errors."
fi

echo "📦 URL Counts by Sitemap:"
if [ ${#sitemap_counts[@]} -eq 0 ]; then
    echo "  (No URL sets found or processed successfully)"
else
    for sitemap in "${!sitemap_counts[@]}"; do
        echo "  $sitemap: ${sitemap_counts[$sitemap]}"
    done
fi

echo "🔢 Total URLs found in successfully processed sitemaps: $total_urls"

# Exit with the status of the fetch operation
exit $fetch_status