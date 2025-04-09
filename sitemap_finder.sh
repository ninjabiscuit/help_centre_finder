#!/usr/bin/env bash

# Robust Sitemap Discovery Script
# Usage: ./robust_sitemap_finder.sh https://example.com [--all]

SITE_URL="$1"
FIND_ALL=false
[ "$2" == "--all" ] && FIND_ALL=true

if [ -z "$SITE_URL" ]; then
  echo "Usage: $0 <site_url> [--all]"
  exit 1
fi

SITE_URL=$(echo "$SITE_URL" | sed 's:/*$::') # Remove trailing slash
ROBOTS_URL="$SITE_URL/robots.txt"

declare -A FOUND_SITEMAPS

function check_url() {
  local url="$1"
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" -L "$url")
  if [[ "$status" == "200" ]]; then
    FOUND_SITEMAPS["$url"]=200
    $FIND_ALL || return 0
  elif [[ "$status" == "301" || "$status" == "302" ]]; then
    final_url=$(curl -s -I -L "$url" | grep -i '^location:' | tail -1 | awk '{print $2}' | tr -d '
')
    [[ -n "$final_url" ]] && check_url "$final_url"
  fi
  return 1
}

# 1. Check robots.txt
echo "📄 Checking $ROBOTS_URL for sitemap..."
robots_content=$(curl -s "$ROBOTS_URL")

if [[ -n "$robots_content" ]]; then
  mapfile -t robots_sitemaps < <(echo "$robots_content" | grep -i '^sitemap:' | awk '{print $2}')
  for sm_url in "${robots_sitemaps[@]}"; do
    echo "🔍 Found in robots.txt: $sm_url"
    check_url "$sm_url"
  done
fi

# 2. Try a wide range of common sitemap paths
echo "🔎 Trying common sitemap paths..."
common_paths=(
  "/sitemap.xml" "/sitemap_index.xml" "/sitemap1.xml" "/sitemap2.xml"
  "/sitemap-news.xml" "/news-sitemap.xml" "/wp-sitemap.xml"
  "/sitemap/sitemap.xml" "/sitemap.xml.gz" "/sitemap.gz"
)

for path in "${common_paths[@]}"; do
  full_url="$SITE_URL$path"
  check_url "$full_url"
done

# 3. Try parsing homepage <link rel="sitemap"> and comments
echo "🧠 Checking homepage HTML for sitemap hints..."
homepage=$(curl -s "$SITE_URL")
mapfile -t html_sitemaps < <(echo "$homepage" | grep -oE '<link[^>]*rel=["'"'"']sitemap["'"'"'][^>]*>' | grep -oE 'href=["'"'"'][^"'"'"' >]*' | cut -d'"' -f2)

for html_sm in "${html_sitemaps[@]}"; do
  [[ "$html_sm" =~ ^http ]] || html_sm="$SITE_URL/$html_sm"
  echo "🔗 Found in <head>: $html_sm"
  check_url "$html_sm"
done

# 4. Print results
if [ ${#FOUND_SITEMAPS[@]} -eq 0 ]; then
  echo "❌ No sitemaps found."
  exit 1
else
  echo
  echo "✅ Sitemaps found:"
  for sm in "${!FOUND_SITEMAPS[@]}"; do
    echo "  - $sm (HTTP ${FOUND_SITEMAPS[$sm]})"
  done
fi

exit 0
