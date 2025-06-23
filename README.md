# Help Centre Finder

A collection of Bash scripts for discovering, analyzing, and counting help centres, sitemaps, and webpages across domains.

## Overview

This repository contains several specialized scripts for web discovery tasks:

- **find_help_centers.sh**: Discover help centres for a domain using multiple detection methods
- **count_sitemap_urls.sh**: Count URLs in XML sitemaps including recursive processing of sitemap indexes
- **crawl_website.sh**: Crawl a website and count the number of pages within a domain
- **sitemap_finder.sh**: Find sitemaps for a website through various discovery methods
- **find_subdomains.sh**: Discover subdomains using multiple techniques
- **hybrid_cms_analyzer.sh**: Analyze CSV files to detect CMS platforms and bot protection across URLs

## Requirements

- Bash environment (Linux, macOS, WSL)
- Core utilities: `curl`, `grep`, `awk`, `sed`
- Additional tools:
  - `jq`: For JSON processing
  - `xmllint`: For parsing XML (part of libxml2)
  - `python3`: For CSV processing and formatting (CMS analysis)
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

Analyze CMS platforms in a CSV file:
```bash
./hybrid_cms_analyzer.sh "input.csv" "output.csv"
```

## CMS Analysis

The `hybrid_cms_analyzer.sh` script provides comprehensive CMS detection and analysis for CSV files containing URLs.

**CSV Format Requirements:**
- Must have a header row
- URLs must be in column D (4th column) with header name `IMPORT_SOURCE_URL`
- Other columns can be anything - only column D is used for analysis
- CSV should be properly formatted (quoted fields containing commas)

**Example CSV structure:**
```csv
APP_ID,CUSTOMER_NAME,SUPPORT_SEGMENT,IMPORT_SOURCE_URL,CREATED_AT
1234,"Company Name",High Volume,https://example.com/help,2025-01-01
5678,"Another Co",Medium,https://support.test.com,2025-01-02
```

**Features:**
- Detects 20+ CMS platforms (WordPress, Salesforce, Shopify, Zendesk, etc.)
- Captures complete HTTP headers (1000 characters) 
- Identifies bot protection mechanisms
- Provides confidence scoring with evidence
- Adds new columns: CMS_HEADERS, BOT_PROTECTION, CMS, CMS_CONFIDENCE, CMS_EVIDENCE

**Supported CMS Platforms:**
- WordPress, Drupal, Joomla
- Salesforce, Zendesk, Intercom 
- Shopify, Magento
- Notion, ReadMe.io, Ghost
- React, Angular, Vue.js apps
- Express, Django, Laravel frameworks
- And many more...

**Usage:**
```bash
# Basic analysis (requires URLs in column D)
./hybrid_cms_analyzer.sh "urls.csv" "results.csv"

# Fix CSV formatting if output has issues
python3 fix_csv_format.py
```

**Output:**
- Main results file with original data + 5 new CMS columns
- Review file for low-confidence detections  
- Detailed processing logs

For complete instructions, see [CMS_ANALYSIS_GUIDE.md](CMS_ANALYSIS_GUIDE.md).

## Domain Processing

All scripts include robust domain processing to:
- Handle multi-part TLDs correctly (.co.uk, .com.au, etc.)
- Strip protocols, paths, and ports
- Extract main domains from subdomains

## License

[MIT License](LICENSE) 