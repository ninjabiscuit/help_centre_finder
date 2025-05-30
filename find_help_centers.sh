#!/usr/bin/env bash

# Help Center Sitemap Finder & Counter
# Usage: ./find_help_centers.sh <domain.com>
# Requires: curl, jq, host, libxml2
# Optional: fzf (for interactive selection)

# --- Configuration ---
# Keywords indicating help/support content (lowercase)
HELP_KEYWORDS=("help" "support" "docs" "documentation" "faq" "knowledge" "guide" "tutorial" "assist")
# Keywords indicating content to exclude (lowercase)
EXCLUDE_KEYWORDS=("api" "shop" "store" "blog" "news" "careers" "jobs" "status" "mail" "email" "ftp" "remote" "cdn" "assets" "static" "app" "admin" "dashboard" "portal" "dev" "staging" "test" "media" "legal" "partnerships" "events" "ebooks" "customer_stories")
# Common sitemap filenames to check on subdomains/paths
COMMON_SITEMAP_FILES=("sitemap.xml" "sitemap_index.xml")

# --- Globals ---
declare -A FINAL_SITEMAPS_TO_COUNT # Associative array for unique sitemaps
declare -A URL_COUNTS_BY_SITEMAP   # Store counts per sitemap
declare -A UNIQUE_URLS_SEEN      # Store unique <loc> URLs encountered globally
TOTAL_URLS_FOUND=0                # Global counter for UNIQUE URLs

# --- Functions ---

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

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

# Check if a string contains any of the help keywords AND none of the exclude keywords
is_likely_help_candidate() {
    local input_str="${1,,}" # Convert to lowercase
    local is_help=false
    local is_excluded=false

    for keyword in "${HELP_KEYWORDS[@]}"; do
        if [[ "$input_str" == *"$keyword"* ]]; then
            is_help=true
            break
        fi
    done

    # If it doesn't contain help keywords, it's not a candidate
    [[ "$is_help" == false ]] && return 1

    for keyword in "${EXCLUDE_KEYWORDS[@]}"; do
        if [[ "$input_str" == *"$keyword"* ]]; then
            is_excluded=true
            break
        fi
    done

    # If it contains excluded keywords, it's not a candidate
    [[ "$is_excluded" == true ]] && return 1

    # Contains help keywords and no excluded keywords
    return 0
}

# Function to check if a host resolves
check_host_resolves() {
    host "$1" &> /dev/null
}

# Adapted from count_sitemap_urls.sh: Fetches and counts URLs recursively
fetch_and_count_urls() {
    local sitemap_url="$1"
    local indent="$2"
    local current_total=0

    # Prevent processing the same sitemap multiple times within a run
    if [[ -v URL_COUNTS_BY_SITEMAP["$sitemap_url"] ]]; then
       echo "${indent}Skipping already processed: $sitemap_url"
       return 0
    fi

    echo "${indent}Fetching: $sitemap_url"
    local content
    content=$(curl -s -L --compressed -A "HelpCenterFinderBot/1.0" "$sitemap_url")
    local curl_status=$?

    if [[ $curl_status -ne 0 ]] || [[ -z "$content" ]]; then
        echo "${indent}Error: Failed to fetch $sitemap_url (curl status: $curl_status) or content empty."
        URL_COUNTS_BY_SITEMAP["$sitemap_url"]=-1 # Mark as failed
        return 1
    fi

    # Check if it's a sitemapindex (case-insensitive)
    if echo "$content" | grep -iq "<sitemapindex"; then
        echo "${indent}Detected sitemap index."
        local xmllint_output
        xmllint_output=$(echo "$content" | xmllint --xpath "//*[local-name()='sitemapindex']/*[local-name()='sitemap']/*[local-name()='loc']/text()" - 2>/dev/null)
        local xmllint_status=$?

        if [[ $xmllint_status -eq 0 ]] && [[ -n "$xmllint_output" ]]; then
            local subsitemaps=()
            mapfile -t subsitemaps < <(echo "$xmllint_output")
            echo "${indent}Found ${#subsitemaps[@]} sub-sitemaps."
            local success=0
            local processed_count=0
            for sub in "${subsitemaps[@]}"; do
                # Ensure sub-sitemap URL is absolute
                 if [[ ! "$sub" =~ ^https?:// ]]; then
                    local base_url=$(dirname "$sitemap_url")
                    sub="${base_url}/${sub}" # Basic relative path handling
                 fi

                 # --- DOMAIN CHECK ADDED ---
                 local sub_hostname=$(get_hostname_from_url "$sub")
                 local sub_domain=$(extract_main_domain "$sub_hostname") # Extract base domain for comparison
                 if [[ "$sub_domain" != "$main_domain" ]]; then
                      echo "${indent}  Skipping sub-sitemap from different domain: $sub (domain: $sub_domain != main: $main_domain)"
                      continue # Skip to the next sub-sitemap
                 fi
                 # --- END DOMAIN CHECK ---

                 echo "${indent}  DEBUG: Recursively calling fetch_and_count_urls with [$sub]"
                 fetch_and_count_urls "$sub" "  $indent" || success=1 # Recurse
                 processed_count=$((processed_count + 1))
            done
            echo "${indent}Processed $processed_count sub-sitemaps belonging to $main_domain."
            URL_COUNTS_BY_SITEMAP["$sitemap_url"]=0 # Index itself has 0 direct URLs
            return $success
        else
            echo "${indent}Warning: Failed to extract sub-sitemaps from index $sitemap_url (xmllint status: $xmllint_status)."
            URL_COUNTS_BY_SITEMAP["$sitemap_url"]=-1 # Mark as failed
            return 1
        fi
    # Check if it's a urlset (case-insensitive)
    elif echo "$content" | grep -iq "<urlset"; then
        echo "${indent}Detected urlset."
        local loc_urls_output
        local xmllint_loc_status

        # Extract the <loc> content using xmllint
        loc_urls_output=$(echo "$content" | xmllint --xpath "//*[local-name()='urlset']/*[local-name()='url']/*[local-name()='loc']/text()" - 2>/dev/null)
        xmllint_loc_status=$?

        local count_in_this_sitemap=0
        if [[ $xmllint_loc_status -eq 0 ]] && [[ -n "$loc_urls_output" ]]; then
            local loc_urls=()
            mapfile -t loc_urls < <(echo "$loc_urls_output")
            local url_count_in_file=${#loc_urls[@]} # Total <loc> tags in this file
            echo "${indent}Found $url_count_in_file <loc> tags in file."

            # Iterate and count only unique URLs globally
            for loc_url in "${loc_urls[@]}"; do
                # Basic validation/cleanup (optional, can be enhanced)
                loc_url=$(echo "$loc_url" | tr -d '[:space:]') # Remove whitespace
                if [[ -z "$loc_url" ]]; then continue; fi

                if [[ ! -v UNIQUE_URLS_SEEN["$loc_url"] ]]; then
                    UNIQUE_URLS_SEEN["$loc_url"]=1
                    TOTAL_URLS_FOUND=$((TOTAL_URLS_FOUND + 1))
                    count_in_this_sitemap=$((count_in_this_sitemap + 1))
                fi
            done
             echo "${indent}Added $count_in_this_sitemap new unique URLs to global count."
        else
            echo "${indent}Warning: Failed to extract <loc> URLs from $sitemap_url (xmllint status: $xmllint_loc_status) or no <loc> tags found."
            count_in_this_sitemap=0 # No URLs counted for this file
        fi

        # Store the count of *new* unique URLs contributed by *this* sitemap
        URL_COUNTS_BY_SITEMAP["$sitemap_url"]=$count_in_this_sitemap
        return 0
    else
        echo "${indent}Error: Unknown sitemap format at $sitemap_url"
        echo "${indent}Content start: $(echo "$content" | head -n 3 | tr -d '\\n')"
        URL_COUNTS_BY_SITEMAP["$sitemap_url"]=-1 # Mark as failed
        return 1
    fi
}

# Try finding a sitemap at common locations for a base URL (e.g., https://help.example.com)
# This function now handles cases where the base URL redirects to a path.
find_sitemap_at_base() {
    local original_base_url="$1"
    echo "  -> Searching for sitemap based on $original_base_url ..."

    # 1. Determine the final landing URL of the base URL itself
    local base_curl_output
    base_curl_output=$(curl -s -L --compressed -A "HelpCenterFinderBot/1.0" -w "%{http_code} %{url_effective}" -o /dev/null -m 10 "$original_base_url")
    local base_curl_exit_code=$?
    local base_http_status=$(echo "$base_curl_output" | awk '{print $1}')
    local base_effective_url=$(echo "$base_curl_output" | awk '{print $2}')

    if [[ $base_curl_exit_code -ne 0 ]]; then
         echo "     Curl command failed trying to resolve base $original_base_url (Exit code: $base_curl_exit_code)"
         return 1
    fi
    # Basic check if the base URL resolved to something usable
    if ! [[ "$base_http_status" =~ ^[23] ]]; then # 2xx (OK) or 3xx (Redirection)
        echo "     Base URL $original_base_url did not resolve successfully (Final Status: $base_http_status). Skipping sitemap search."
        return 1
    fi
     echo "     Base URL $original_base_url resolved to $base_effective_url (Status: $base_http_status)"

    # 2. Define potential search locations (base URL and effective URL's directory if different)
    declare -A search_locations_map # Use map to avoid duplicates
    search_locations_map["$original_base_url"]=1

    # Check if effective URL has a path and is different from original base
    # Regex checks for http(s)://domain/path structure
    if [[ "$base_effective_url" != "$original_base_url" ]] && [[ "$base_effective_url" =~ ^https?://[^/]+/.+ ]]; then
        # Extract directory path using dirname
        local effective_dir=$(dirname "$base_effective_url")
        # Ensure dirname didn't just return scheme or .
        if [[ "$effective_dir" != "http:" ]] && [[ "$effective_dir" != "https:" ]] && [[ "$effective_dir" != "." ]]; then
            search_locations_map["$effective_dir"]=1
            echo "     Adding effective URL directory to search locations: $effective_dir"
        fi
    fi

    # 3. Iterate through search locations and common sitemap files
    for search_base in "${!search_locations_map[@]}"; do
        echo "     Searching relative to: ${search_base%/}"
        for sitemap_file in "${COMMON_SITEMAP_FILES[@]}"; do
            # Ensure no double slashes if search_base already ends with /
            local potential_sitemap_url="${search_base%/}/$sitemap_file"
            echo "       Checking: $potential_sitemap_url"

            local sitemap_curl_output
            # Still use -L to follow redirects, but check the final URL
            sitemap_curl_output=$(curl -s -L --compressed -A "HelpCenterFinderBot/1.0" -w "%{http_code} %{url_effective}" -o /dev/null -m 10 "$potential_sitemap_url")
            local sitemap_curl_exit_code=$?
            local sitemap_http_status=$(echo "$sitemap_curl_output" | awk '{print $1}')
            local sitemap_effective_url=$(echo "$sitemap_curl_output" | awk '{print $2}')

            if [[ $sitemap_curl_exit_code -ne 0 ]]; then
                 echo "       Curl command failed for $potential_sitemap_url (Exit code: $sitemap_curl_exit_code)"
                 continue # Try next common file
            fi

            # Check if final status code is 200
            if [[ "$sitemap_http_status" == "200" ]]; then
                 # --- DOMAIN CHECK ADDED ---
                 local effective_hostname=$(get_hostname_from_url "$sitemap_effective_url")
                 local effective_domain=$(extract_main_domain "$effective_hostname")
                 if [[ "$effective_domain" == "$main_domain" ]]; then
                    echo "       Found valid sitemap on correct domain: $sitemap_effective_url (Status: $sitemap_http_status)"
                    FINAL_SITEMAPS_TO_COUNT["$sitemap_effective_url"]=1
                    return 0 # Successfully found one matching domain, exit function
                 else
                    echo "       Found sitemap $sitemap_effective_url, but it's on a different domain ($effective_domain != $main_domain). Skipping."
                    # Continue searching other sitemap_files for this search_base
                 fi
                 # --- END DOMAIN CHECK ---
            else
                 echo "       Failed check for $potential_sitemap_url (Final Status: $sitemap_http_status, Effective URL: $sitemap_effective_url)"
            fi
        done
    done

    echo "     No valid sitemap found *on domain $main_domain* for base URL $original_base_url or its effective directory."
    return 1 # Failed to find any sitemap matching the domain
}

# --- Main Script ---

# Input validation
if [ -z "$1" ]; then
    echo "Usage: $0 <domain.com | url>"
    echo "Example: $0 example.com"
    echo "Example: $0 https://help.example.com/some/path"
    exit 1
fi

original_input="$1"
main_domain=$(extract_main_domain "$original_input")

if [[ -z "$main_domain" ]]; then
    echo "Error: Could not extract a valid domain/hostname from input: $original_input"
    exit 1
fi

echo "Original Input: $original_input"
echo "Using Main Domain: $main_domain"

# Check dependencies
for cmd in curl jq host xmllint; do
    if ! command_exists "$cmd"; then
        echo "Error: Required command '$cmd' not found."
        echo "Please install it (e.g., brew install $cmd or apt install $cmd)."
        exit 1
    fi
done

# Use associative array for unique candidates
declare -A CANDIDATES

# --- Domain Analysis ---
echo -e "\\n--- Analyzing Domain: $main_domain ---"

# 1. Check DNS TXT Record for _help_center_sitemap
echo "[1/4] Checking DNS TXT record for _help_center_sitemap.$main_domain..."
sitemap_from_txt=$(host -t TXT "_help_center_sitemap.$main_domain" | grep -o '".*"' | tr -d '"')

if [ -n "$sitemap_from_txt" ]; then
    echo "  Found sitemap via TXT record: $sitemap_from_txt"
    FINAL_SITEMAPS_TO_COUNT["$sitemap_from_txt"]=1
else
    echo "  No TXT record found for _help_center_sitemap.$main_domain."
fi

# 2. Generate and Check Potential Help Center Subdomains/Paths
echo -e "\\n[2/4] Checking common help subdomains and paths based on $main_domain..."
declare -A potential_urls_map # Use map to avoid duplicates

# Add the original input if it looks like a different, valid hostname/URL
# (Simple check: contains a dot or is not the same as main_domain)
if [[ "$original_input" != "$main_domain" ]] && [[ "$original_input" == *"."* ]]; then
     # Attempt to normalize the original input to a base URL (e.g. https://sub.domain.com)
     original_base_url=$(echo "$original_input" | sed -E 's#^([^/]*://)?([^/?#]+).*#https://\2#')
     if [[ "$original_base_url" =~ ^https:// ]]; then
         echo "  Adding original input base URL to checks: $original_base_url"
         potential_urls_map["$original_base_url"]=1
     fi
fi


# Generate URLs based on keywords and the main domain
for keyword in "${HELP_KEYWORDS[@]}"; do
    potential_urls_map["https://$keyword.$main_domain"]=1
    potential_urls_map["https://$main_domain/$keyword"]=1
done

# Add www subdomain as a common case
potential_urls_map["https://www.$main_domain"]=1

# Check if potential URLs resolve and look for sitemaps
checked_hosts_count=0
found_via_common=false
for url_base in "${!potential_urls_map[@]}"; do
    # Extract hostname for DNS check
    host_to_check=$(echo "$url_base" | sed -E 's#^https?://([^/]+).*#\1#')

    echo "  Checking potential base: $url_base (Host: $host_to_check)"

    # Check if hostname resolves before trying to find sitemap
    if check_host_resolves "$host_to_check"; then
        echo "    Host $host_to_check resolves."
        checked_hosts_count=$((checked_hosts_count + 1))
        # Now try finding a common sitemap file there
        if find_sitemap_at_base "$url_base"; then
             echo "    Found sitemap for $url_base"
             found_via_common=true
             # find_sitemap_at_base already adds to FINAL_SITEMAPS_TO_COUNT
        else
             echo "    No common sitemap found directly for $url_base"
        fi
    else
        echo "    Host $host_to_check does not resolve. Skipping."
    fi
done

if [[ "$checked_hosts_count" -eq 0 ]]; then
     echo "  Warning: None of the generated potential hostnames resolved."
elif [[ "$found_via_common" = false ]]; then
     echo "  Checked $checked_hosts_count resolving hosts, but found no sitemaps via common file names (sitemap.xml, sitemap_index.xml)."
fi


# 3. Search robots.txt for Sitemap Directives
echo -e "\\n[3/4] Searching robots.txt on https://$main_domain/robots.txt..."
robots_url="https://$main_domain/robots.txt"
robots_sitemaps=$(curl -s -L -m 5 -A "HelpCenterFinderBot/1.0" "$robots_url" | grep -i '^Sitemap:' | awk '{print $2}')
for sm_url in $robots_sitemaps; do
     # Clean potential carriage returns
     sm_url=$(echo "$sm_url" | tr -d '\\r')
     hostname=$(echo "$sm_url" | awk -F/ '{print $3}')
     path=$(echo "$sm_url" | awk -F/ '{ $1=$2=$3=""; print $0 }' | sed 's/^ *//') # Get path part
    if is_likely_help_candidate "$hostname" || is_likely_help_candidate "$path"; then
         echo "  [Robots] Found likely help sitemap: $sm_url"
        CANDIDATES["sitemap:$sm_url"]=1
    fi
done

# 4. Check Common Subdomains (resolution + keywords)
# (Limited list for performance, add more if needed)
COMMON_HELP_SUBDOMAINS=("help" "support" "docs" "guide" "guides" "knowledge" "faq" "knowledgebase")
echo "[+] Checking common help subdomains..."
for sub_prefix in "${COMMON_HELP_SUBDOMAINS[@]}"; do
    subdomain="$sub_prefix.$main_domain"
    if check_host_resolves "$subdomain"; then
        if is_likely_help_candidate "$subdomain"; then
             echo "  [Common Subdomain] Found likely help subdomain: $subdomain"
            CANDIDATES["subdomain:$subdomain"]=1
        fi
    fi
done


# --- User Selection ---
if [ ${#CANDIDATES[@]} -eq 0 ]; then
    echo -e "\n❌ No likely help center candidates found using these methods."
    exit 1
fi

echo -e "\n📊 Potential Help Center Candidates Found:"
candidate_list=()
for key in "${!CANDIDATES[@]}"; do
    candidate_list+=("$key")
done
# Sort the list robustly using mapfile/readarray
mapfile -t sorted_candidates < <(printf "%s\\n" "${candidate_list[@]}" | sort)


SELECTED_CANDIDATES=()
if command_exists fzf; then
    echo "ℹ️ Use TAB to select multiple candidates, Enter to confirm."
    echo "DEBUG (fzf input - showing elements before piping):"
    printf "DEBUG: [%s]\\n" "${sorted_candidates[@]}" # Print each element clearly

    # Pipe directly to fzf (reverted)
    mapfile -t SELECTED_CANDIDATES < <(printf "%s\\n" "${sorted_candidates[@]}" | \
        fzf --multi --prompt="Select candidates > ")

else
    echo "ℹ️ fzf not found. Using manual selection."
    echo "   Enter the numbers of the candidates you want to check (e.g., 1 3 4), then press Enter:"
    for i in "${!sorted_candidates[@]}"; do
        local current_candidate="${sorted_candidates[i]}"
        echo "DEBUG (manual loop): Index $i, Candidate: [$current_candidate]" # Add this
        printf "  %d) %s\\n" $((i+1)) "$current_candidate"
    done
    read -p "> " -a choices
    for choice in "${choices[@]}"; do
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#sorted_candidates[@]}" ]; then
            SELECTED_CANDIDATES+=("${sorted_candidates[choice-1]}")
        else
            echo "Warning: Invalid choice '$choice' ignored."
        fi
    done
fi


if [ ${#SELECTED_CANDIDATES[@]} -eq 0 ]; then
    echo "No candidates selected. Exiting."
    exit 0
fi

echo -e "\n🚀 Processing selected candidates:"

# --- Resolve Sitemaps for Selected Candidates ---
for selected in "${SELECTED_CANDIDATES[@]}"; do
    # Trim leading/trailing whitespace just in case
    selected=$(echo "$selected" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    echo "DEBUG: Processing selected item: [$selected]"

    # Robust parsing: Check if colon exists and split
    type=""
    value=""
    if [[ "$selected" == *:* ]]; then
         type="${selected%%:*}"  # Get part before the first colon
         value="${selected#*:}" # Get part after the first colon
    else
         echo "Warning: Selected item '$selected' is missing the expected 'type:value' format. Skipping."
         continue
    fi

    echo "DEBUG: Parsed type=[$type], value=[$value]"

    # Validate the extracted type
    if [[ "$type" != "sitemap" && "$type" != "subdomain" ]]; then
        echo "Warning: Extracted type '$type' is invalid for item '$selected'. Skipping."
        continue
    fi

    # Proceed with validated type and value
    if [[ "$type" == "sitemap" ]]; then
        echo "[Selected] Adding direct sitemap: $value"
        FINAL_SITEMAPS_TO_COUNT["$value"]=1
    elif [[ "$type" == "subdomain" ]]; then
        echo "[Selected] Checking subdomain: $value"
        # Try finding sitemap for this subdomain (https first)
        find_sitemap_at_base "https://$value" || find_sitemap_at_base "http://$value"
    fi
done


# --- Count URLs in Final Sitemaps ---
if [ ${#FINAL_SITEMAPS_TO_COUNT[@]} -eq 0 ]; then
    echo -e "\n❌ No specific sitemaps could be resolved from the selected candidates."
    exit 1
fi

echo -e "\n🔢 Counting URLs in resolved sitemaps..."
overall_status=0
for sitemap in "${!FINAL_SITEMAPS_TO_COUNT[@]}"; do
    fetch_and_count_urls "$sitemap" "" || overall_status=1 # Track if any fetch fails
done

# --- Final Output ---
echo -e "\\n--- Summary for $main_domain ---"
echo "📦 URLs Counted per Sitemap:"
processed_count=0
failed_count=0
if [ ${#URL_COUNTS_BY_SITEMAP[@]} -eq 0 ]; then
     echo "  (No sitemaps were processed)"
else
    for sitemap in "${!URL_COUNTS_BY_SITEMAP[@]}"; do
        count=${URL_COUNTS_BY_SITEMAP[$sitemap]}
        if [[ "$count" -eq -1 ]]; then
            echo "  - $sitemap: FAILED"
            failed_count=$((failed_count + 1))
        else
            echo "  - $sitemap: $count URLs"
             processed_count=$((processed_count + 1))
        fi
    done
fi

echo "-----------------------------------------"
echo "✅ Successfully processed sitemaps: $processed_count"
echo "❌ Failed/Unreachable sitemaps:    $failed_count"
echo "🔢 Total *unique* URLs found in successful sitemaps: $TOTAL_URLS_FOUND"
echo "-----------------------------------------"

exit $overall_status
