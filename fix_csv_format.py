#!/usr/bin/env python3

import csv
import re

def clean_csv_data():
    """Fix the malformed CSV by properly handling embedded newlines and quotes"""
    
    input_file = 'processed_urls_enhanced_1000chars.csv'
    output_file = 'processed_urls_enhanced_1000chars_fixed.csv'
    
    print("Fixing CSV formatting issues...")
    
    # Read the raw file and fix line breaks within quoted fields
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Split into lines and reconstruct proper CSV rows
    lines = content.split('\n')
    fixed_rows = []
    current_row = ""
    in_quotes = False
    quote_count = 0
    
    for line_num, line in enumerate(lines):
        if not line.strip():
            continue
            
        # Count quotes to determine if we're inside a quoted field
        quote_count_in_line = line.count('"')
        
        # If this looks like a new row (starts with a number and we're not in quotes)
        if (line and line.split(',')[0].isdigit() and not in_quotes) or line.startswith('APP_ID,'):
            if current_row:
                fixed_rows.append(current_row)
            current_row = line
            # Update quote state
            if quote_count_in_line % 2 == 1:
                in_quotes = not in_quotes
        else:
            # This is a continuation of the previous row
            current_row += " " + line.strip()
            if quote_count_in_line % 2 == 1:
                in_quotes = not in_quotes
    
    # Add the last row
    if current_row:
        fixed_rows.append(current_row)
    
    print(f"Reconstructed {len(fixed_rows)} rows from {len(lines)} original lines")
    
    # Now parse and clean the data properly
    cleaned_data = []
    
    for i, row_str in enumerate(fixed_rows):
        try:
            # Parse the CSV row
            row = list(csv.reader([row_str]))[0]
            
            if len(row) >= 13:
                # Clean the headers field (remove embedded newlines, clean up formatting)
                if len(row) > 8:
                    headers = row[8]
                    # Remove excessive whitespace and normalize
                    headers = re.sub(r'\s+', ' ', headers)
                    # Remove any remaining line breaks
                    headers = headers.replace('\n', ' ').replace('\r', ' ')
                    row[8] = headers
                
                cleaned_data.append(row)
            elif i == 0:  # Header row
                cleaned_data.append(row)
            else:
                print(f"Skipping malformed row {i}: {len(row)} columns")
                
        except Exception as e:
            print(f"Error processing row {i}: {e}")
            continue
    
    # Write the cleaned data
    with open(output_file, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        for row in cleaned_data:
            writer.writerow(row)
    
    print(f"Fixed CSV saved as: {output_file}")
    print(f"Total clean rows: {len(cleaned_data)}")
    
    # Quick analysis of the results
    cms_counts = {}
    for row in cleaned_data[1:]:  # Skip header
        if len(row) >= 11:
            cms = row[10]
            cms_counts[cms] = cms_counts.get(cms, 0) + 1
    
    print("\nCMS Detection Summary:")
    for cms, count in sorted(cms_counts.items(), key=lambda x: x[1], reverse=True):
        percentage = (count / (len(cleaned_data) - 1)) * 100
        print(f"  {cms}: {count} sites ({percentage:.1f}%)")

if __name__ == "__main__":
    clean_csv_data()