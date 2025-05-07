# Help Centre Finder

A collection of Bash scripts for discovering, analyzing, and counting help centres, sitemaps, and webpages across domains.

## Overview

This repository contains several specialized scripts for web discovery tasks:

- **find_help_centers.sh**: Discover help centres for a domain using multiple detection methods
- **count_sitemap_urls.sh**: Count URLs in XML sitemaps including recursive processing of sitemap indexes
- **crawl_website.sh**: Crawl a website and count the number of pages within a domain
- **sitemap_finder.sh**: Find sitemaps for a website through various discovery methods
- **find_subdomains.sh**: Discover subdomains using multiple techniques

## Requirements

- Bash environment (Linux, macOS, WSL)
- Core utilities: `curl`, `grep`, `awk`, `sed`
- Additional tools:
  - `jq`: For JSON processing
  - `xmllint`: For parsing XML (part of libxml2)
  - `host`: For DNS lookups
  - `fzf` (optional): For interactive selection

### Installation

```bash
# macOS
brew install curl jq bind libxml2 fzf

# Ubuntu/Debian
sudo apt install curl jq dnsutils libxml2-utils fzf
```

### Making Scripts Executable

After downloading, make all scripts executable:

```bash
# Make a single script executable
chmod +x find_help_centers.sh

# Make all scripts executable at once
chmod +x *.sh
```

**Important**: All scripts must be made executable before use, otherwise you'll get "permission denied" errors.

## Usage

### Find Help Centers

Discovers and analyzes help centres for a domain using multiple methods.

```bash
./find_help_centers.sh example.com
./find_help_centers.sh https://help.example.com/some/path
```

Features:
- Handles subdomain or URL with subfolder by extracting the main domain
- Checks DNS TXT records for `_help_center_sitemap` entries
- Searches common help subdomains (help, support, docs, etc.)
- Analyzes robots.txt for sitemap entries
- Interactive selection of candidate help centres (with fzf if available)
- Counts unique URLs across all found sitemaps

### Count URLs in Sitemaps

Counts all URLs found in a sitemap, including recursive processing of sitemap indexes.

```bash
./count_sitemap_urls.sh https://example.com/sitemap.xml
```

Features:
- Handles both sitemap index files and URL sets
- Follows redirects
- Uses browser-like user agent to bypass some protection systems
- Provides detailed output with debugging information

### Crawl Website

Crawls a website and counts all pages within a domain.

```bash
./crawl_website.sh example.com
./crawl_website.sh https://example.com/starting-path
```

Features:
- Stays within the provided domain (doesn't follow external links)
- Handles relative and absolute URLs
- Respects maximum page count and depth limits
- Normalizes URLs to avoid duplicates
- Filters by common webpage extensions

### Find Sitemaps

Discovers sitemaps for a website using various methods.

```bash
./sitemap_finder.sh https://example.com
./sitemap_finder.sh https://example.com --all  # Find all sitemaps instead of stopping at first
```

Features:
- Checks robots.txt files
- Tries common sitemap paths
- Examines homepage HTML for sitemap links

### Find Subdomains

Discovers subdomains for a domain using multiple techniques.

```bash
./find_subdomains.sh example.com
```

Features:
- Queries certificate transparency logs (crt.sh)
- Checks robots.txt files
- Scrapes homepage for subdomain references
- Tests common subdomain patterns

## Examples

Find help centres for a company:
```bash
./find_help_centers.sh shopify.com
```

Count URLs in a sitemap:
```bash
./count_sitemap_urls.sh https://help.netflix.com/sitemap.xml
```

Crawl a website:
```bash
./crawl_website.sh https://support.google.com/mail
```

## Domain Processing

All scripts include robust domain processing to:
- Handle multi-part TLDs correctly (.co.uk, .com.au, etc.)
- Strip protocols, paths, and ports
- Extract main domains from subdomains

## License

[MIT License](LICENSE) 