#!/usr/bin/env python3
"""
Script to fix encoding issues in CSV files by replacing problematic Unicode characters
with their ASCII equivalents.
"""

import csv
import os
import sys
from pathlib import Path
from typing import Dict, List, Tuple


class CSVEncodingFixer:
    """Fix encoding issues in CSV files by replacing problematic characters."""
    
    def __init__(self):
        # Mapping of problematic Unicode characters to their replacements
        self.character_replacements = {
            # Trademark and copyright symbols
            '\u00ae': '(R)',    # registered trademark ® -> (R)
            '\u2122': '(TM)',   # trademark ™ -> (TM)
            '\u00a9': '(C)',    # copyright © -> (C)
            
            # Quotes and apostrophes
            '\u2018': "'",      # left single quote ' -> '
            '\u2019': "'",      # right single quote ' -> '
            '\u201c': '"',      # left double quote " -> "
            '\u201d': '"',      # right double quote " -> "
            '\u2033': '"',      # double prime ″ -> "
            '\u2032': "'",      # prime ′ -> '
            
            # Dashes
            '\u2013': '-',      # en dash – -> -
            '\u2014': '-',      # em dash — -> -
            '\u2212': '-',      # minus sign − -> -
            
            # Spaces
            '\u00a0': ' ',      # non-breaking space -> regular space
            '\u2009': ' ',      # thin space -> regular space
            '\u2003': ' ',      # em space -> regular space
            '\u2002': ' ',      # en space -> regular space
            
            # Other symbols
            '\u2022': '*',      # bullet • -> *
            '\u2026': '...',    # ellipsis … -> ...
            '\u2010': '-',      # hyphen ‐ -> -
            '\u2011': '-',      # non-breaking hyphen ‑ -> -
            
            # Currency
            '\u20ac': 'EUR',    # euro € -> EUR
            '\u00a3': 'GBP',    # pound £ -> GBP
            '\u00a5': 'JPY',    # yen ¥ -> JPY
        }
    
    def fix_text(self, text: str) -> Tuple[str, List[str]]:
        """
        Fix problematic characters in text.
        
        Returns:
            Tuple of (fixed_text, list_of_changes)
        """
        if not text:
            return text, []
        
        fixed_text = text
        changes = []
        
        for problematic_char, replacement in self.character_replacements.items():
            if problematic_char in fixed_text:
                count = fixed_text.count(problematic_char)
                fixed_text = fixed_text.replace(problematic_char, replacement)
                changes.append(f"'{problematic_char}' (U+{ord(problematic_char):04X}) -> '{replacement}' ({count} occurrences)")
        
        return fixed_text, changes
    
    def analyze_csv_file(self, file_path: Path) -> Dict:
        """Analyze a CSV file for encoding issues."""
        print(f"🔍 Analyzing {file_path.name}...")
        
        analysis = {
            'file_path': file_path,
            'total_rows': 0,
            'rows_with_issues': 0,
            'total_replacements': 0,
            'issues_by_field': {},
            'sample_issues': []
        }
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                
                for row_num, row in enumerate(reader, start=2):  # Start at 2 (after header)
                    analysis['total_rows'] += 1
                    row_has_issues = False
                    
                    for field_name, field_value in row.items():
                        if field_value:
                            _, changes = self.fix_text(field_value)
                            
                            if changes:
                                row_has_issues = True
                                
                                if field_name not in analysis['issues_by_field']:
                                    analysis['issues_by_field'][field_name] = 0
                                analysis['issues_by_field'][field_name] += 1
                                
                                # Store sample issues
                                if len(analysis['sample_issues']) < 5:
                                    analysis['sample_issues'].append({
                                        'row': row_num,
                                        'field': field_name,
                                        'changes': changes,
                                        'preview': field_value[:100] + '...' if len(field_value) > 100 else field_value
                                    })
                    
                    if row_has_issues:
                        analysis['rows_with_issues'] += 1
        
        except Exception as e:
            print(f"❌ Error analyzing {file_path}: {e}")
            return None
        
        return analysis
    
    def fix_csv_file(self, file_path: Path, backup: bool = True) -> bool:
        """Fix encoding issues in a CSV file."""
        print(f"🔧 Fixing {file_path.name}...")
        
        # Create backup if requested
        if backup:
            backup_path = file_path.with_suffix(f'{file_path.suffix}.backup')
            print(f"📦 Creating backup: {backup_path.name}")
            import shutil
            shutil.copy2(file_path, backup_path)
        
        try:
            # Read the original file
            rows = []
            fieldnames = None
            
            with open(file_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                fieldnames = reader.fieldnames
                
                for row in reader:
                    # Fix each field in the row
                    fixed_row = {}
                    for field_name, field_value in row.items():
                        if field_value:
                            fixed_text, _ = self.fix_text(field_value)
                            fixed_row[field_name] = fixed_text
                        else:
                            fixed_row[field_name] = field_value
                    
                    rows.append(fixed_row)
            
            # Write the fixed file
            with open(file_path, 'w', newline='', encoding='utf-8') as f:
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()
                writer.writerows(rows)
            
            print(f"✅ Successfully fixed {file_path.name}")
            return True
            
        except Exception as e:
            print(f"❌ Error fixing {file_path}: {e}")
            return False
    
    def process_files(self, file_paths: List[Path], dry_run: bool = True) -> Dict:
        """Process multiple CSV files for encoding fixes."""
        results = {
            'analyzed_files': 0,
            'files_with_issues': 0,
            'total_fixes_needed': 0,
            'files_processed': []
        }
        
        for file_path in file_paths:
            if not file_path.exists():
                print(f"⚠️  File not found: {file_path}")
                continue
            
            # Analyze first
            analysis = self.analyze_csv_file(file_path)
            if analysis is None:
                continue
            
            results['analyzed_files'] += 1
            
            if analysis['rows_with_issues'] > 0:
                results['files_with_issues'] += 1
                results['total_fixes_needed'] += analysis['rows_with_issues']
                
                print(f"📊 Found issues in {file_path.name}:")
                print(f"   Rows with issues: {analysis['rows_with_issues']}/{analysis['total_rows']}")
                print(f"   Fields affected: {list(analysis['issues_by_field'].keys())}")
                
                # Show sample issues
                if analysis['sample_issues']:
                    print(f"   Sample issues:")
                    for issue in analysis['sample_issues'][:3]:
                        print(f"     Row {issue['row']} ({issue['field']}): {issue['changes']}")
                
                if not dry_run:
                    # Actually fix the file
                    if self.fix_csv_file(file_path):
                        results['files_processed'].append(str(file_path))
                        
                        # Re-analyze to confirm fixes
                        post_analysis = self.analyze_csv_file(file_path)
                        if post_analysis and post_analysis['rows_with_issues'] == 0:
                            print(f"✅ Confirmed: All encoding issues fixed in {file_path.name}")
                        else:
                            print(f"⚠️  Warning: Some issues may remain in {file_path.name}")
                
            else:
                print(f"✅ No encoding issues found in {file_path.name}")
            
            print()
        
        return results


def main():
    """Main function to fix CSV encoding issues."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Fix encoding issues in CSV files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python fix_csv_encoding.py --dry-run
    python fix_csv_encoding.py --fix
    python fix_csv_encoding.py --fix --no-backup
    python fix_csv_encoding.py --files file1.csv file2.csv
        """
    )
    
    parser.add_argument(
        '--files', '-f',
        nargs='+',
        help='Specific files to process (default: datadog CSV files)'
    )
    
    parser.add_argument(
        '--fix',
        action='store_true',
        help='Actually fix the files (default: dry-run only)'
    )
    
    parser.add_argument(
        '--no-backup',
        action='store_true',
        help='Skip creating backup files'
    )
    
    args = parser.parse_args()
    
    # Determine files to process
    if args.files:
        file_paths = [Path(f) for f in args.files]
    else:
        # Default to the problematic files mentioned in the issue
        knowledge_base_dir = Path('data/knowledge_base')
        file_paths = [
            knowledge_base_dir / 'datadog_mulesoft_integration.csv',
            knowledge_base_dir / 'datadog_mulesoft_web_docs.csv'
        ]
    
    # Initialize fixer
    fixer = CSVEncodingFixer()
    
    # Process files
    dry_run = not args.fix
    mode = "DRY RUN" if dry_run else "FIX MODE"
    backup = not args.no_backup
    
    print(f"🚀 CSV Encoding Fixer - {mode}")
    print(f"📁 Processing {len(file_paths)} files")
    if not dry_run:
        print(f"📦 Backup files: {'Yes' if backup else 'No'}")
    print()
    
    results = fixer.process_files(file_paths, dry_run=dry_run)
    
    # Summary
    print("📊 SUMMARY:")
    print(f"   Files analyzed: {results['analyzed_files']}")
    print(f"   Files with issues: {results['files_with_issues']}")
    print(f"   Total fixes needed: {results['total_fixes_needed']}")
    
    if not dry_run:
        print(f"   Files processed: {len(results['files_processed'])}")
        if results['files_processed']:
            print("   Fixed files:")
            for file_path in results['files_processed']:
                print(f"     - {file_path}")
    
    if dry_run and results['files_with_issues'] > 0:
        print("\n💡 To fix the issues, run with --fix flag")


if __name__ == "__main__":
    main()