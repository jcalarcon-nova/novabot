#!/usr/bin/env python3
"""
Knowledge Base Validation Script for NovaBot

This script validates CSV files in the knowledge base directory to ensure
they meet the required format and quality standards.
"""

import csv
import os
import sys
from pathlib import Path
from typing import List, Dict, Set, Tuple
import re


class KnowledgeBaseValidator:
    """Validator for NovaBot knowledge base CSV files."""
    
    def __init__(self, knowledge_base_dir: str = "data/knowledge_base"):
        self.knowledge_base_dir = Path(knowledge_base_dir)
        self.required_fields = {"question", "answer", "category", "tags", "priority"}
        self.valid_priorities = {"high", "medium", "low"}
        self.errors: List[str] = []
        self.warnings: List[str] = []
        
    def log_error(self, message: str):
        """Log an error message."""
        self.errors.append(f"❌ ERROR: {message}")
        
    def log_warning(self, message: str):
        """Log a warning message."""
        self.warnings.append(f"⚠️  WARNING: {message}")
        
    def validate_file_structure(self, file_path: Path) -> bool:
        """Validate the basic structure of a CSV file."""
        if not file_path.exists():
            self.log_error(f"File does not exist: {file_path}")
            return False
            
        if file_path.stat().st_size == 0:
            self.log_error(f"File is empty: {file_path}")
            return False
            
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                # Check if file can be read as CSV
                reader = csv.DictReader(f)
                header = reader.fieldnames
                
                if not header:
                    self.log_error(f"No header found in: {file_path}")
                    return False
                    
                # Check required fields
                header_set = set(header)
                missing_fields = self.required_fields - header_set
                if missing_fields:
                    self.log_error(f"Missing required fields in {file_path}: {missing_fields}")
                    return False
                    
                # Check for extra fields
                extra_fields = header_set - self.required_fields
                if extra_fields:
                    self.log_warning(f"Extra fields in {file_path}: {extra_fields}")
                    
        except Exception as e:
            self.log_error(f"Failed to read {file_path}: {str(e)}")
            return False
            
        return True
    
    def validate_content_quality(self, file_path: Path) -> Tuple[int, int]:
        """
        Validate the quality of content in a CSV file.
        
        Returns:
            Tuple of (total_rows, valid_rows)
        """
        total_rows = 0
        valid_rows = 0
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                
                for row_num, row in enumerate(reader, start=2):  # Start at 2 for header
                    total_rows += 1
                    is_valid_row = True
                    
                    # Check for empty required fields
                    for field in self.required_fields:
                        if not row.get(field, '').strip():
                            self.log_error(f"{file_path}:{row_num} - Empty {field}")
                            is_valid_row = False
                    
                    # Validate priority values
                    priority = row.get('priority', '').strip().lower()
                    if priority and priority not in self.valid_priorities:
                        self.log_error(f"{file_path}:{row_num} - Invalid priority: {priority}")
                        is_valid_row = False
                    
                    # Check question length
                    question = row.get('question', '').strip()
                    if len(question) > 500:
                        self.log_warning(f"{file_path}:{row_num} - Question is very long ({len(question)} chars)")
                    elif len(question) < 10:
                        self.log_warning(f"{file_path}:{row_num} - Question is very short ({len(question)} chars)")
                    
                    # Check answer length
                    answer = row.get('answer', '').strip()
                    if len(answer) > 5000:
                        self.log_warning(f"{file_path}:{row_num} - Answer is very long ({len(answer)} chars)")
                    elif len(answer) < 20:
                        self.log_warning(f"{file_path}:{row_num} - Answer is very short ({len(answer)} chars)")
                    
                    # Validate tags format
                    tags = row.get('tags', '').strip()
                    if tags:
                        tag_list = [tag.strip() for tag in tags.split(',')]
                        if len(tag_list) > 10:
                            self.log_warning(f"{file_path}:{row_num} - Too many tags ({len(tag_list)})")
                        
                        # Check for empty tags
                        if any(not tag for tag in tag_list):
                            self.log_error(f"{file_path}:{row_num} - Empty tags found")
                            is_valid_row = False
                    
                    # Validate category format
                    category = row.get('category', '').strip()
                    if category and not re.match(r'^[a-zA-Z0-9_-]+$', category):
                        self.log_warning(f"{file_path}:{row_num} - Category contains special characters: {category}")
                    
                    if is_valid_row:
                        valid_rows += 1
                        
        except Exception as e:
            self.log_error(f"Failed to validate content in {file_path}: {str(e)}")
            
        return total_rows, valid_rows
    
    def check_for_duplicates(self, files: List[Path]) -> Dict[str, List[str]]:
        """Check for duplicate questions across all files."""
        questions_to_files = {}
        duplicates = {}
        
        for file_path in files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    reader = csv.DictReader(f)
                    
                    for row_num, row in enumerate(reader, start=2):
                        question = row.get('question', '').strip().lower()
                        if not question:
                            continue
                            
                        file_location = f"{file_path.name}:{row_num}"
                        
                        if question in questions_to_files:
                            # Found duplicate
                            if question not in duplicates:
                                duplicates[question] = [questions_to_files[question]]
                            duplicates[question].append(file_location)
                        else:
                            questions_to_files[question] = file_location
                            
            except Exception as e:
                self.log_error(f"Failed to check duplicates in {file_path}: {str(e)}")
        
        return duplicates
    
    def generate_statistics(self, files: List[Path]) -> Dict:
        """Generate statistics about the knowledge base."""
        stats = {
            'total_files': len(files),
            'total_entries': 0,
            'categories': {},
            'priorities': {'high': 0, 'medium': 0, 'low': 0},
            'tags': {},
            'avg_question_length': 0,
            'avg_answer_length': 0,
        }
        
        total_question_length = 0
        total_answer_length = 0
        
        for file_path in files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    reader = csv.DictReader(f)
                    
                    for row in reader:
                        stats['total_entries'] += 1
                        
                        # Count categories
                        category = row.get('category', '').strip()
                        if category:
                            stats['categories'][category] = stats['categories'].get(category, 0) + 1
                        
                        # Count priorities
                        priority = row.get('priority', '').strip().lower()
                        if priority in stats['priorities']:
                            stats['priorities'][priority] += 1
                        
                        # Count tags
                        tags = row.get('tags', '').strip()
                        if tags:
                            tag_list = [tag.strip() for tag in tags.split(',') if tag.strip()]
                            for tag in tag_list:
                                stats['tags'][tag] = stats['tags'].get(tag, 0) + 1
                        
                        # Calculate lengths
                        question = row.get('question', '').strip()
                        answer = row.get('answer', '').strip()
                        total_question_length += len(question)
                        total_answer_length += len(answer)
                        
            except Exception as e:
                self.log_error(f"Failed to generate stats for {file_path}: {str(e)}")
        
        if stats['total_entries'] > 0:
            stats['avg_question_length'] = total_question_length / stats['total_entries']
            stats['avg_answer_length'] = total_answer_length / stats['total_entries']
        
        return stats
    
    def validate_all(self) -> bool:
        """Validate all CSV files in the knowledge base directory."""
        print("🔍 Validating NovaBot Knowledge Base...")
        print(f"📁 Directory: {self.knowledge_base_dir}")
        print()
        
        if not self.knowledge_base_dir.exists():
            self.log_error(f"Knowledge base directory does not exist: {self.knowledge_base_dir}")
            return False
        
        # Find all CSV files
        csv_files = list(self.knowledge_base_dir.glob("*.csv"))
        if not csv_files:
            self.log_error(f"No CSV files found in {self.knowledge_base_dir}")
            return False
        
        print(f"📄 Found {len(csv_files)} CSV files:")
        for file_path in csv_files:
            print(f"   - {file_path.name}")
        print()
        
        # Validate each file
        valid_files = []
        total_entries = 0
        valid_entries = 0
        
        for file_path in csv_files:
            print(f"🔍 Validating {file_path.name}...")
            
            if self.validate_file_structure(file_path):
                valid_files.append(file_path)
                file_total, file_valid = self.validate_content_quality(file_path)
                total_entries += file_total
                valid_entries += file_valid
                print(f"   ✅ Structure valid - {file_valid}/{file_total} entries valid")
            else:
                print(f"   ❌ Structure invalid")
        
        print()
        
        # Check for duplicates
        if valid_files:
            print("🔍 Checking for duplicate questions...")
            duplicates = self.check_for_duplicates(valid_files)
            
            if duplicates:
                print(f"   ⚠️  Found {len(duplicates)} duplicate questions:")
                for question, locations in duplicates.items():
                    self.log_warning(f"Duplicate question: '{question[:50]}...' in {', '.join(locations)}")
            else:
                print("   ✅ No duplicates found")
        
        print()
        
        # Generate statistics
        if valid_files:
            print("📊 Knowledge Base Statistics:")
            stats = self.generate_statistics(valid_files)
            
            print(f"   📄 Total files: {stats['total_files']}")
            print(f"   📝 Total entries: {stats['total_entries']}")
            print(f"   📊 Valid entries: {valid_entries} ({(valid_entries/total_entries*100):.1f}%)")
            print(f"   📏 Avg question length: {stats['avg_question_length']:.1f} chars")
            print(f"   📏 Avg answer length: {stats['avg_answer_length']:.1f} chars")
            
            if stats['categories']:
                print("   📂 Categories:")
                for category, count in sorted(stats['categories'].items()):
                    print(f"      - {category}: {count}")
            
            if stats['priorities']:
                print("   🔥 Priority distribution:")
                for priority, count in stats['priorities'].items():
                    if count > 0:
                        print(f"      - {priority}: {count} ({count/stats['total_entries']*100:.1f}%)")
            
            if stats['tags']:
                print("   🏷️  Top 10 tags:")
                top_tags = sorted(stats['tags'].items(), key=lambda x: x[1], reverse=True)[:10]
                for tag, count in top_tags:
                    print(f"      - {tag}: {count}")
        
        print()
        
        # Print summary
        if self.errors:
            print("❌ ERRORS FOUND:")
            for error in self.errors:
                print(f"   {error}")
            print()
        
        if self.warnings:
            print("⚠️  WARNINGS:")
            for warning in self.warnings:
                print(f"   {warning}")
            print()
        
        success = len(self.errors) == 0
        if success:
            print("✅ Knowledge base validation completed successfully!")
        else:
            print(f"❌ Knowledge base validation failed with {len(self.errors)} errors")
        
        return success


def main():
    """Main function to run the validation."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Validate NovaBot Knowledge Base CSV files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python validate_knowledge_base.py
    python validate_knowledge_base.py --dir custom/path
    python validate_knowledge_base.py --quiet
        """
    )
    
    parser.add_argument(
        '--dir', '-d',
        default='data/knowledge_base',
        help='Knowledge base directory path (default: data/knowledge_base)'
    )
    
    parser.add_argument(
        '--quiet', '-q',
        action='store_true',
        help='Only show errors and warnings, suppress other output'
    )
    
    args = parser.parse_args()
    
    # Redirect stdout if quiet mode
    if args.quiet:
        import io
        original_stdout = sys.stdout
        sys.stdout = io.StringIO()
    
    try:
        validator = KnowledgeBaseValidator(args.dir)
        success = validator.validate_all()
        
        # Restore stdout and print errors/warnings
        if args.quiet:
            sys.stdout = original_stdout
            if validator.errors or validator.warnings:
                for error in validator.errors:
                    print(error)
                for warning in validator.warnings:
                    print(warning)
        
        sys.exit(0 if success else 1)
        
    except KeyboardInterrupt:
        if args.quiet:
            sys.stdout = original_stdout
        print("\n⏹️  Validation interrupted by user")
        sys.exit(1)
    except Exception as e:
        if args.quiet:
            sys.stdout = original_stdout
        print(f"❌ Unexpected error: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()