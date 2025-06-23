# CMS Analysis Guide - Manual Instructions

This guide provides step-by-step instructions for running the enhanced CMS detection analysis on any CSV file containing URLs.

## Prerequisites

- **Bash shell** (macOS/Linux)
- **Python 3** installed
- **curl** command available
- CSV file with URLs in column D (`IMPORT_SOURCE_URL`)

## Scripts Overview

The analysis consists of these key scripts:

1. **`hybrid_cms_analyzer.sh`** - Main analysis script (enhanced with 1000-char headers)
2. **`fix_csv_format.py`** - Fixes CSV formatting issues
3. **`manual_cms_corrections.py`** - Manual review and corrections (optional)
4. **`fix_wordpress_detection.py`** - Additional WordPress detection fixes (optional)

## Step-by-Step Instructions

### Step 1: Prepare Your CSV File

Ensure your CSV file has:
- Header row with column names
- URLs in column D named `IMPORT_SOURCE_URL`
- Proper CSV formatting (quoted fields with commas)

**Example CSV structure:**
```csv
APP_ID,CUSTOMER_NAME,SUPPORT_SEGMENT,IMPORT_SOURCE_URL,CREATED_AT,UPDATED_AT,IMPORT_SOURCE_ID,SAMPLE_APP_ID
1234,"Company Name",High Volume,https://example.com/help,2025-01-01,2025-01-01,5678,1234
```

### Step 2: Run the Main CMS Analysis

```bash
# Make the script executable
chmod +x hybrid_cms_analyzer.sh

# Run the analysis (replace INPUT.csv with your filename)
./hybrid_cms_analyzer.sh "INPUT.csv" "results_enhanced.csv"
```

**What this does:**
- Analyzes each URL in column D
- Fetches headers (up to 1000 characters)
- Detects CMS platforms (WordPress, Salesforce, Shopify, etc.)
- Identifies bot protection mechanisms
- Creates two output files:
  - `results_enhanced.csv` - All results
  - `results_enhanced_review.csv` - Low-confidence cases for manual review

**Expected runtime:** ~2-3 hours for 1,300 URLs

### Step 3: Fix CSV Formatting (If Needed)

If the output CSV has formatting issues (data spanning multiple rows):

```bash
# Fix CSV formatting
python3 fix_csv_format.py

# This reads: processed_urls_enhanced_1000chars.csv
# And creates: processed_urls_enhanced_1000chars_fixed.csv
```

**Note:** You may need to edit the script to change input/output filenames.

### Step 4: Manual Review (Optional)

For low-confidence detections flagged for review:

```bash
# Review and improve uncertain CMS detections
python3 manual_cms_corrections.py

# This reads: processed_urls_final_review.csv  
# And creates: processed_urls_final_corrected.csv
```

### Step 5: WordPress-Specific Fixes (Optional)

To catch additional WordPress sites missed by the main analysis:

```bash
# Enhanced WordPress detection
python3 fix_wordpress_detection.py

# This reads: processed_urls_final.csv
# And creates: processed_urls_final_wordpress_fixed.csv
```

## Configuration Options

### Adjusting Header Capture Limit

To change the header capture limit, edit `hybrid_cms_analyzer.sh` line ~376:

```bash
# Current setting (1000 characters)
clean_headers=$(echo "$headers" | tr '\n\r' ' ' | cut -c1-1000)

# To increase to 1500 characters:
clean_headers=$(echo "$headers" | tr '\n\r' ' ' | cut -c1-1500)

# To capture unlimited headers (remove truncation):
clean_headers=$(echo "$headers" | tr '\n\r' ' ')
```

### Adding New CMS Detection Patterns

To detect additional CMS platforms, edit the `detect_cms_with_confidence()` function in `hybrid_cms_analyzer.sh`:

```bash
# Example: Adding Joomla detection
if echo "$headers" | grep -qi "x-joomla\|joomla"; then
    cms="Joomla"
    confidence=90
    evidence="Joomla headers"
fi
```

## File Structure After Analysis

```
your-directory/
├── INPUT.csv                              # Your original CSV
├── results_enhanced.csv                   # Main results (may need fixing)
├── results_enhanced_review.csv            # Low-confidence cases
├── results_enhanced_fixed.csv             # Clean, properly formatted results
├── enhanced_analysis.log                  # Detailed processing log
├── hybrid_cms_analyzer.sh                 # Main analysis script
├── fix_csv_format.py                      # CSV formatting fixer
├── manual_cms_corrections.py              # Manual review tool
└── fix_wordpress_detection.py             # WordPress enhancement tool
```

## Expected Results

### CMS Detection Capabilities

The enhanced system can detect:

- **WordPress** (wp-json, api.w.org, wp-content, etc.)
- **Salesforce** (.my.site.com domains, salesforce headers)
- **Shopify** (shopify headers, myshopify.com)
- **Zendesk** (zendesk headers, zendesk.com)
- **Intercom** (intercom headers, widget indicators)
- **Drupal** (x-drupal headers, drupal paths)
- **Notion** (.notion.site domains)
- **ReadMe.io** (readme-deploy, cdn.readme.io)
- **Webflow** (webflow indicators)
- **Squarespace** (squarespace headers)
- **Wix** (x-wix headers, wixstatic)
- **Ghost** (x-ghost headers)
- **Gatsby** (gatsby framework indicators)
- **Next.js** (__NEXT_DATA__ indicators)
- **React/Angular/Vue** apps
- **Custom frameworks** (Express, PHP, ASP.NET, Django, Laravel)

### Performance Expectations

- **Processing speed:** ~2-3 seconds per URL
- **Success rate:** 55-60% CMS identification
- **WordPress detection:** ~7-8% of URLs (if WordPress sites present)
- **Confidence scoring:** 0-100% with evidence

## Troubleshooting

### Common Issues

1. **Script hangs or times out**
   - Reduce batch size by splitting large CSV files
   - Increase timeout values in script

2. **CSV formatting broken**
   - Always run `fix_csv_format.py` after main analysis
   - Check for embedded newlines in headers

3. **Low detection rates**
   - Increase header capture limit
   - Check bot protection blocking requests
   - Review user-agent rotation

4. **Permission errors**
   - Ensure scripts are executable: `chmod +x *.sh`
   - Check file permissions on output directory

### Performance Optimization

For large datasets (>2000 URLs):

1. **Split the CSV** into smaller chunks
2. **Run analysis in parallel** on different chunks
3. **Increase timeout values** for slow sites
4. **Filter out invalid URLs** beforehand

## Security Considerations

- Script respects robots.txt and rate limiting
- Uses multiple user agents to avoid blocking
- Implements timeouts to prevent hanging
- Does not store or transmit sensitive data

## Support Files

All scripts include:
- Error handling and logging
- Progress indicators
- Configurable timeouts
- Multiple user-agent rotation
- Bot protection detection
- Confidence scoring with evidence

For questions or issues, refer to the generated log files for detailed processing information.