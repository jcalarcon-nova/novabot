#!/usr/bin/env python3
"""
Knowledge Base Management Tool for NovaBot

This script provides comprehensive management capabilities for the NovaBot knowledge base,
including content analysis, quality checks, duplicate detection, and batch operations.
"""

import csv
import json
import os
import sys
from pathlib import Path
from typing import List, Dict, Set, Tuple, Optional
import argparse
from collections import Counter, defaultdict
import re
from datetime import datetime


class KnowledgeBaseManager:
    """Comprehensive manager for NovaBot knowledge base operations."""
    
    def __init__(self, knowledge_base_dir: str = "data/knowledge_base"):
        self.knowledge_base_dir = Path(knowledge_base_dir)
        self.required_fields = {"question", "answer", "category", "tags", "priority"}
        self.valid_priorities = {"high", "medium", "low"}
        
    def load_csv_file(self, file_path: Path) -> List[Dict[str, str]]:
        """Load CSV file and return list of entries."""
        entries = []
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    entries.append(dict(row))
        except Exception as e:
            print(f"❌ Error loading {file_path}: {e}")
        return entries
    
    def save_csv_file(self, file_path: Path, entries: List[Dict[str, str]]) -> bool:
        """Save entries to CSV file."""
        try:
            with open(file_path, 'w', newline='', encoding='utf-8') as f:
                if entries:
                    fieldnames = ['question', 'answer', 'category', 'tags', 'priority']
                    writer = csv.DictWriter(f, fieldnames=fieldnames)
                    writer.writeheader()
                    writer.writerows(entries)
            return True
        except Exception as e:
            print(f"❌ Error saving {file_path}: {e}")
            return False
    
    def get_all_entries(self) -> Dict[str, List[Dict[str, str]]]:
        """Load all entries from all CSV files."""
        all_entries = {}
        csv_files = list(self.knowledge_base_dir.glob("*.csv"))
        
        for file_path in csv_files:
            entries = self.load_csv_file(file_path)
            if entries:
                all_entries[file_path.name] = entries
        
        return all_entries
    
    def analyze_content(self) -> Dict:
        """Perform comprehensive content analysis."""
        print("📊 Analyzing knowledge base content...")
        
        all_entries = self.get_all_entries()
        
        analysis = {
            'files': {},
            'global_stats': {
                'total_files': len(all_entries),
                'total_entries': 0,
                'categories': Counter(),
                'priorities': Counter(),
                'tags': Counter(),
                'avg_question_length': 0,
                'avg_answer_length': 0,
                'duplicate_questions': [],
                'empty_fields': defaultdict(int),
                'quality_issues': []
            }
        }
        
        seen_questions = defaultdict(list)
        total_question_length = 0
        total_answer_length = 0
        
        for filename, entries in all_entries.items():
            file_stats = {
                'entry_count': len(entries),
                'categories': Counter(),
                'priorities': Counter(),
                'tags': Counter(),
                'issues': []
            }
            
            for idx, entry in enumerate(entries, 1):
                analysis['global_stats']['total_entries'] += 1
                
                # Track question duplicates
                question = entry.get('question', '').strip().lower()
                if question:
                    seen_questions[question].append(f"{filename}:{idx}")
                    total_question_length += len(question)
                else:
                    analysis['global_stats']['empty_fields']['question'] += 1
                    file_stats['issues'].append(f"Row {idx}: Empty question")
                
                # Track answer length
                answer = entry.get('answer', '').strip()
                if answer:
                    total_answer_length += len(answer)
                else:
                    analysis['global_stats']['empty_fields']['answer'] += 1
                    file_stats['issues'].append(f"Row {idx}: Empty answer")
                
                # Category analysis
                category = entry.get('category', '').strip()
                if category:
                    analysis['global_stats']['categories'][category] += 1
                    file_stats['categories'][category] += 1
                else:
                    analysis['global_stats']['empty_fields']['category'] += 1
                
                # Priority analysis
                priority = entry.get('priority', '').strip().lower()
                if priority:
                    if priority in self.valid_priorities:
                        analysis['global_stats']['priorities'][priority] += 1
                        file_stats['priorities'][priority] += 1
                    else:
                        file_stats['issues'].append(f"Row {idx}: Invalid priority '{priority}'")
                else:
                    analysis['global_stats']['empty_fields']['priority'] += 1
                
                # Tags analysis
                tags_str = entry.get('tags', '').strip()
                if tags_str:
                    tags = [tag.strip() for tag in tags_str.split(',') if tag.strip()]
                    for tag in tags:
                        analysis['global_stats']['tags'][tag] += 1
                        file_stats['tags'][tag] += 1
                    
                    # Check for too many tags
                    if len(tags) > 10:
                        file_stats['issues'].append(f"Row {idx}: Too many tags ({len(tags)})")
                else:
                    analysis['global_stats']['empty_fields']['tags'] += 1
                
                # Quality checks
                if len(entry.get('question', '')) > 500:
                    file_stats['issues'].append(f"Row {idx}: Question too long ({len(entry.get('question', ''))} chars)")
                
                if len(entry.get('answer', '')) > 5000:
                    file_stats['issues'].append(f"Row {idx}: Answer too long ({len(entry.get('answer', ''))} chars)")
            
            analysis['files'][filename] = file_stats
        
        # Calculate averages
        if analysis['global_stats']['total_entries'] > 0:
            analysis['global_stats']['avg_question_length'] = total_question_length / analysis['global_stats']['total_entries']
            analysis['global_stats']['avg_answer_length'] = total_answer_length / analysis['global_stats']['total_entries']
        
        # Find duplicates
        duplicates = {q: locations for q, locations in seen_questions.items() if len(locations) > 1}
        analysis['global_stats']['duplicate_questions'] = duplicates
        
        return analysis
    
    def find_duplicates(self) -> Dict[str, List[str]]:
        """Find duplicate questions across all files."""
        print("🔍 Finding duplicate questions...")
        
        all_entries = self.get_all_entries()
        seen_questions = defaultdict(list)
        
        for filename, entries in all_entries.items():
            for idx, entry in enumerate(entries, 1):
                question = entry.get('question', '').strip().lower()
                if question:
                    seen_questions[question].append(f"{filename}:{idx}")
        
        duplicates = {q: locations for q, locations in seen_questions.items() if len(locations) > 1}
        
        if duplicates:
            print(f"Found {len(duplicates)} duplicate questions:")
            for question, locations in duplicates.items():
                print(f"  '{question[:80]}...' in {', '.join(locations)}")
        else:
            print("✅ No duplicate questions found")
        
        return duplicates
    
    def remove_duplicates(self, dry_run: bool = True) -> bool:
        """Remove duplicate questions, keeping the first occurrence."""
        print(f"🧹 {'[DRY RUN] ' if dry_run else ''}Removing duplicate questions...")
        
        duplicates = self.find_duplicates()
        if not duplicates:
            print("✅ No duplicates to remove")
            return True
        
        all_entries = self.get_all_entries()
        modified_files = set()
        
        for question, locations in duplicates.items():
            # Keep the first occurrence, remove the rest
            for location in locations[1:]:
                filename, row_num = location.split(':')
                row_num = int(row_num) - 1  # Convert to 0-based index
                
                if filename in all_entries and 0 <= row_num < len(all_entries[filename]):
                    if dry_run:
                        print(f"  Would remove: {location}")
                    else:
                        del all_entries[filename][row_num]
                        modified_files.add(filename)
                        print(f"  Removed: {location}")
        
        if not dry_run and modified_files:
            # Save modified files
            for filename in modified_files:
                file_path = self.knowledge_base_dir / filename
                if self.save_csv_file(file_path, all_entries[filename]):
                    print(f"✅ Updated {filename}")
                else:
                    print(f"❌ Failed to update {filename}")
                    return False
        
        return True
    
    def search_content(self, query: str, field: str = "all") -> List[Dict]:
        """Search for content in the knowledge base."""
        print(f"🔍 Searching for '{query}' in field '{field}'...")
        
        all_entries = self.get_all_entries()
        results = []
        
        query_lower = query.lower()
        
        for filename, entries in all_entries.items():
            for idx, entry in enumerate(entries, 1):
                match = False
                
                if field == "all":
                    # Search in all fields
                    for key, value in entry.items():
                        if query_lower in str(value).lower():
                            match = True
                            break
                elif field in entry:
                    # Search in specific field
                    if query_lower in str(entry[field]).lower():
                        match = True
                
                if match:
                    result = entry.copy()
                    result['_source'] = f"{filename}:{idx}"
                    results.append(result)
        
        print(f"Found {len(results)} results")
        return results
    
    def export_statistics(self, output_file: str = None) -> Dict:
        """Export comprehensive statistics to JSON."""
        print("📈 Generating comprehensive statistics...")
        
        analysis = self.analyze_content()
        
        # Create detailed report
        report = {
            'generated_at': datetime.now().isoformat(),
            'summary': {
                'total_files': analysis['global_stats']['total_files'],
                'total_entries': analysis['global_stats']['total_entries'],
                'duplicate_questions': len(analysis['global_stats']['duplicate_questions']),
                'avg_question_length': round(analysis['global_stats']['avg_question_length'], 2),
                'avg_answer_length': round(analysis['global_stats']['avg_answer_length'], 2),
            },
            'categories': dict(analysis['global_stats']['categories']),
            'priorities': dict(analysis['global_stats']['priorities']),
            'top_tags': dict(analysis['global_stats']['tags'].most_common(20)),
            'empty_fields': dict(analysis['global_stats']['empty_fields']),
            'files': {}
        }
        
        # Add file-specific details
        for filename, file_stats in analysis['files'].items():
            report['files'][filename] = {
                'entry_count': file_stats['entry_count'],
                'categories': dict(file_stats['categories']),
                'priorities': dict(file_stats['priorities']),
                'top_tags': dict(file_stats['tags'].most_common(10)),
                'issues_count': len(file_stats['issues']),
                'issues': file_stats['issues'][:10]  # Limit to first 10 issues
            }
        
        # Add duplicates
        if analysis['global_stats']['duplicate_questions']:
            report['duplicates'] = {
                'count': len(analysis['global_stats']['duplicate_questions']),
                'examples': dict(list(analysis['global_stats']['duplicate_questions'].items())[:10])
            }
        
        if output_file:
            try:
                with open(output_file, 'w', encoding='utf-8') as f:
                    json.dump(report, f, indent=2, ensure_ascii=False)
                print(f"✅ Statistics exported to {output_file}")
            except Exception as e:
                print(f"❌ Error exporting statistics: {e}")
        
        return report
    
    def validate_and_fix(self, fix: bool = False) -> bool:
        """Validate knowledge base and optionally fix issues."""
        print(f"🔧 {'Validating and fixing' if fix else 'Validating'} knowledge base...")
        
        all_entries = self.get_all_entries()
        has_issues = False
        
        for filename, entries in all_entries.items():
            print(f"\n📄 Processing {filename}...")
            file_modified = False
            
            for idx, entry in enumerate(entries):
                # Fix empty fields with defaults
                if not entry.get('category', '').strip():
                    if fix:
                        entry['category'] = 'general'
                        file_modified = True
                        print(f"  Fixed: Row {idx+1} - Added default category")
                    else:
                        print(f"  Issue: Row {idx+1} - Missing category")
                        has_issues = True
                
                if not entry.get('priority', '').strip():
                    if fix:
                        entry['priority'] = 'medium'
                        file_modified = True
                        print(f"  Fixed: Row {idx+1} - Added default priority")
                    else:
                        print(f"  Issue: Row {idx+1} - Missing priority")
                        has_issues = True
                
                # Fix invalid priorities
                priority = entry.get('priority', '').strip().lower()
                if priority and priority not in self.valid_priorities:
                    if fix:
                        entry['priority'] = 'medium'
                        file_modified = True
                        print(f"  Fixed: Row {idx+1} - Invalid priority '{priority}' -> 'medium'")
                    else:
                        print(f"  Issue: Row {idx+1} - Invalid priority '{priority}'")
                        has_issues = True
                
                # Clean up tags
                tags_str = entry.get('tags', '').strip()
                if tags_str:
                    tags = [tag.strip() for tag in tags_str.split(',') if tag.strip()]
                    cleaned_tags = ','.join(tags)
                    if cleaned_tags != tags_str:
                        if fix:
                            entry['tags'] = cleaned_tags
                            file_modified = True
                            print(f"  Fixed: Row {idx+1} - Cleaned up tags")
                        else:
                            print(f"  Issue: Row {idx+1} - Malformed tags")
                            has_issues = True
            
            # Save modified file
            if fix and file_modified:
                file_path = self.knowledge_base_dir / filename
                if self.save_csv_file(file_path, entries):
                    print(f"  ✅ Saved fixes to {filename}")
                else:
                    print(f"  ❌ Failed to save {filename}")
                    return False
        
        if not fix and has_issues:
            print(f"\n⚠️  Issues found. Use --fix to automatically resolve them.")
            return False
        elif fix:
            print(f"\n✅ Validation and fixes completed successfully!")
        else:
            print(f"\n✅ No issues found!")
        
        return True
    
    def merge_files(self, source_files: List[str], target_file: str, remove_duplicates: bool = True) -> bool:
        """Merge multiple CSV files into one."""
        print(f"🔗 Merging {len(source_files)} files into {target_file}...")
        
        all_entries = []
        seen_questions = set()
        
        for source_file in source_files:
            file_path = self.knowledge_base_dir / source_file
            if not file_path.exists():
                print(f"❌ Source file not found: {source_file}")
                return False
            
            entries = self.load_csv_file(file_path)
            print(f"  Loaded {len(entries)} entries from {source_file}")
            
            for entry in entries:
                question = entry.get('question', '').strip().lower()
                
                if remove_duplicates and question in seen_questions:
                    print(f"  Skipped duplicate: {question[:50]}...")
                    continue
                
                all_entries.append(entry)
                if question:
                    seen_questions.add(question)
        
        # Save merged file
        target_path = self.knowledge_base_dir / target_file
        if self.save_csv_file(target_path, all_entries):
            print(f"✅ Merged {len(all_entries)} entries into {target_file}")
            return True
        else:
            print(f"❌ Failed to save merged file")
            return False


def main():
    """Main function with command-line interface."""
    parser = argparse.ArgumentParser(
        description="NovaBot Knowledge Base Management Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Analyze content
    python manage_knowledge_base.py analyze
    
    # Find duplicates
    python manage_knowledge_base.py duplicates
    
    # Remove duplicates (dry run first)
    python manage_knowledge_base.py remove-duplicates --dry-run
    python manage_knowledge_base.py remove-duplicates
    
    # Search content
    python manage_knowledge_base.py search "datadog integration"
    
    # Export statistics
    python manage_knowledge_base.py stats --output report.json
    
    # Validate and fix issues
    python manage_knowledge_base.py validate --fix
    
    # Merge files
    python manage_knowledge_base.py merge file1.csv file2.csv --output merged.csv
        """
    )
    
    parser.add_argument(
        '--dir', '-d',
        default='data/knowledge_base',
        help='Knowledge base directory (default: data/knowledge_base)'
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Analyze command
    subparsers.add_parser('analyze', help='Analyze knowledge base content')
    
    # Duplicates command
    subparsers.add_parser('duplicates', help='Find duplicate questions')
    
    # Remove duplicates command
    remove_parser = subparsers.add_parser('remove-duplicates', help='Remove duplicate questions')
    remove_parser.add_argument('--dry-run', action='store_true', help='Show what would be removed without doing it')
    
    # Search command
    search_parser = subparsers.add_parser('search', help='Search knowledge base content')
    search_parser.add_argument('query', help='Search query')
    search_parser.add_argument('--field', choices=['question', 'answer', 'category', 'tags', 'all'], default='all', help='Field to search in')
    search_parser.add_argument('--limit', type=int, default=10, help='Maximum results to show')
    
    # Statistics command
    stats_parser = subparsers.add_parser('stats', help='Export comprehensive statistics')
    stats_parser.add_argument('--output', '-o', help='Output JSON file (default: print to console)')
    
    # Validate command
    validate_parser = subparsers.add_parser('validate', help='Validate and optionally fix issues')
    validate_parser.add_argument('--fix', action='store_true', help='Automatically fix issues')
    
    # Merge command
    merge_parser = subparsers.add_parser('merge', help='Merge multiple CSV files')
    merge_parser.add_argument('files', nargs='+', help='Source files to merge')
    merge_parser.add_argument('--output', '-o', required=True, help='Output file name')
    merge_parser.add_argument('--keep-duplicates', action='store_true', help='Keep duplicate questions')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    # Initialize manager
    manager = KnowledgeBaseManager(args.dir)
    
    try:
        if args.command == 'analyze':
            analysis = manager.analyze_content()
            
            print("\n📊 Knowledge Base Analysis Summary:")
            print(f"  Total files: {analysis['global_stats']['total_files']}")
            print(f"  Total entries: {analysis['global_stats']['total_entries']}")
            print(f"  Duplicate questions: {len(analysis['global_stats']['duplicate_questions'])}")
            print(f"  Avg question length: {analysis['global_stats']['avg_question_length']:.1f} chars")
            print(f"  Avg answer length: {analysis['global_stats']['avg_answer_length']:.1f} chars")
            
            if analysis['global_stats']['categories']:
                print("\n  Top categories:")
                for cat, count in analysis['global_stats']['categories'].most_common(5):
                    print(f"    {cat}: {count}")
            
            if analysis['global_stats']['tags']:
                print("\n  Top tags:")
                for tag, count in analysis['global_stats']['tags'].most_common(10):
                    print(f"    {tag}: {count}")
        
        elif args.command == 'duplicates':
            manager.find_duplicates()
        
        elif args.command == 'remove-duplicates':
            success = manager.remove_duplicates(dry_run=args.dry_run)
            return 0 if success else 1
        
        elif args.command == 'search':
            results = manager.search_content(args.query, args.field)
            
            print(f"\n🔍 Search Results (showing up to {args.limit}):")
            for i, result in enumerate(results[:args.limit], 1):
                print(f"\n{i}. [{result['_source']}]")
                print(f"   Question: {result.get('question', '')[:100]}...")
                print(f"   Answer: {result.get('answer', '')[:150]}...")
                print(f"   Category: {result.get('category', '')}")
                print(f"   Tags: {result.get('tags', '')}")
        
        elif args.command == 'stats':
            report = manager.export_statistics(args.output)
            
            if not args.output:
                print(json.dumps(report, indent=2, ensure_ascii=False))
        
        elif args.command == 'validate':
            success = manager.validate_and_fix(fix=args.fix)
            return 0 if success else 1
        
        elif args.command == 'merge':
            success = manager.merge_files(
                args.files, 
                args.output, 
                remove_duplicates=not args.keep_duplicates
            )
            return 0 if success else 1
        
        return 0
    
    except KeyboardInterrupt:
        print("\n⏹️  Operation interrupted by user")
        return 1
    except Exception as e:
        print(f"❌ Unexpected error: {str(e)}")
        return 1


if __name__ == "__main__":
    sys.exit(main())