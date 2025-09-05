#!/usr/bin/env python3
"""
Script to process web documentation CSV from scraping and convert to 
NovaBot knowledge base Q&A format.
"""

import csv
import re
from typing import Dict, List, Tuple
from pathlib import Path


class WebDocumentationProcessor:
    """Process web documentation into structured knowledge base format."""
    
    def __init__(self):
        self.category = "datadog-mulesoft-docs"
        self.base_tags = ["datadog", "mulesoft", "documentation"]
        
    def detect_content_type(self, content: str) -> str:
        """Detect the type of documentation content."""
        content_upper = content.upper()
        
        if "OVERVIEW" in content_upper:
            return "overview"
        elif "CONFIGURATION" in content_upper:
            return "configuration"
        elif "INSTALLATION" in content_upper:
            return "installation"
        elif "CONNECTOR" in content_upper:
            return "connector"
        elif "INTEGRATION" in content_upper:
            return "integration"
        elif "MONITOR" in content_upper:
            return "monitoring"
        elif "DASHBOARD" in content_upper:
            return "dashboard"
        elif "TROUBLESHOOT" in content_upper:
            return "troubleshooting"
        elif "SYSTEM ARCHITECTURE" in content_upper:
            return "architecture"
        elif "OOTB" in content_upper or "OUT OF THE BOX" in content_upper:
            return "ootb-assets"
        elif "COST OPTIMIZATION" in content_upper:
            return "cost-optimization"
        else:
            return "documentation"
    
    def extract_title_and_topic(self, content: str) -> Tuple[str, str]:
        """Extract title and main topic from content."""
        lines = [line.strip() for line in content.split('\n') if line.strip()]
        
        if not lines:
            return "Documentation", "general"
        
        # First line is usually the title
        title = lines[0]
        
        # Clean up title - remove excessive formatting
        title = re.sub(r'[®™©]', '', title)  # Remove trademark symbols
        title = re.sub(r'\s+', ' ', title).strip()  # Normalize whitespace
        
        # Extract main topic/product
        if "DATADOG" in title.upper():
            topic = "datadog"
        elif "CLOUDWATCH" in title.upper():
            topic = "cloudwatch"
        elif "APM" in title.upper():
            topic = "apm"
        elif "MULE" in title.upper():
            topic = "mulesoft"
        else:
            topic = "integration"
        
        return title, topic
    
    def generate_question_from_content(self, title: str, content: str, content_type: str) -> str:
        """Generate a natural question from the documentation content."""
        title = title.replace("®", "").replace("™", "")
        
        if content_type == "overview":
            return f"What is {title} and how does it work?"
        elif content_type == "configuration":
            if "SERVICE" in title.upper():
                return f"How do I configure the service for {title}?"
            else:
                return f"How do I configure {title}?"
        elif content_type == "installation":
            return f"How do I install {title}?"
        elif content_type == "monitoring":
            return f"How do I set up monitoring with {title}?"
        elif content_type == "dashboard":
            return f"What dashboards are available for {title}?"
        elif content_type == "troubleshooting":
            return f"How do I troubleshoot issues with {title}?"
        elif content_type == "architecture":
            return f"What is the system architecture for {title}?"
        elif content_type == "ootb-assets":
            return f"What out-of-the-box assets are available for {title}?"
        elif content_type == "cost-optimization":
            return f"How can I optimize costs for {title}?"
        else:
            return f"What do I need to know about {title}?"
    
    def clean_and_format_answer(self, content: str) -> str:
        """Clean and format the content for use as an answer."""
        # Remove trademark symbols for cleaner text
        content = re.sub(r'[®™©]', '', content)
        
        # Normalize whitespace
        content = re.sub(r'\n\s*\n', '\n\n', content)  # Remove empty lines
        content = re.sub(r'\n\s+', '\n', content)      # Remove leading spaces
        content = re.sub(r'\s+', ' ', content)         # Normalize spaces
        
        # Ensure proper paragraph breaks
        content = content.replace('\n', '\n\n').strip()
        
        # Clean up any residual formatting issues
        content = re.sub(r'\n{3,}', '\n\n', content)  # Max 2 line breaks
        
        return content
    
    def generate_tags(self, title: str, content: str, content_type: str, topic: str) -> List[str]:
        """Generate relevant tags based on content analysis."""
        tags = self.base_tags.copy()
        
        # Add content type tag
        tags.append(content_type)
        
        # Add topic tag if not already in base tags
        if topic not in tags:
            tags.append(topic)
        
        content_lower = content.lower()
        title_lower = title.lower()
        
        # Add specific technology tags
        if "cloudwatch" in content_lower or "cloudwatch" in title_lower:
            tags.append("cloudwatch")
        if "apm" in content_lower or "apm" in title_lower:
            tags.append("apm")
        if "connector" in content_lower or "connector" in title_lower:
            tags.append("connector")
        if "dashboard" in content_lower or "dashboard" in title_lower:
            tags.append("dashboard")
        if "monitor" in content_lower or "monitor" in title_lower:
            tags.append("monitoring")
        if "installation" in content_lower or "installation" in title_lower:
            tags.append("installation")
        if "configuration" in content_lower or "configuration" in title_lower:
            tags.append("configuration")
        if "troubleshoot" in content_lower or "troubleshoot" in title_lower:
            tags.append("troubleshooting")
        if "architecture" in content_lower or "architecture" in title_lower:
            tags.append("architecture")
        if "cost" in content_lower or "cost" in title_lower:
            tags.append("cost-optimization")
        if "ootb" in content_lower or "out of the box" in content_lower:
            tags.append("ootb")
            
        # Remove duplicates and limit to top 6 tags
        tags = list(dict.fromkeys(tags))  # Remove duplicates while preserving order
        return tags[:6]
    
    def determine_priority(self, content_type: str, content: str) -> str:
        """Determine priority based on content type and content."""
        content_lower = content.lower()
        
        # High priority for essential setup and configuration
        if content_type in ["overview", "installation", "configuration"]:
            return "high"
        
        # High priority for troubleshooting and errors
        if content_type == "troubleshooting" or any(word in content_lower for word in 
            ["error", "issue", "problem", "troubleshoot", "fail", "debug"]):
            return "high"
        
        # Medium priority for monitoring and operational content
        if content_type in ["monitoring", "dashboard", "architecture"]:
            return "medium"
        
        # Medium priority for connector and integration specifics
        if content_type in ["connector", "integration"]:
            return "medium"
        
        # Low priority for general documentation and optimization
        if content_type in ["ootb-assets", "cost-optimization"]:
            return "low"
        
        return "medium"  # Default
    
    def process_entry(self, entry: Dict[str, str]) -> Dict[str, str]:
        """Process a single documentation entry into Q&A format."""
        content = entry['content']
        
        # Extract basic information
        title, topic = self.extract_title_and_topic(content)
        content_type = self.detect_content_type(content)
        
        # Generate Q&A
        question = self.generate_question_from_content(title, content, content_type)
        answer = self.clean_and_format_answer(content)
        
        # Generate metadata
        tags = self.generate_tags(title, content, content_type, topic)
        priority = self.determine_priority(content_type, content)
        
        return {
            'question': question,
            'answer': answer,
            'category': self.category,
            'tags': ','.join(tags),
            'priority': priority
        }
    
    def process_documentation_csv(self, input_file: str, output_file: str):
        """Process the web documentation CSV and create enhanced knowledge base."""
        print("🔄 Processing web documentation CSV...")
        
        processed_entries = []
        
        try:
            with open(input_file, 'r', encoding='latin-1') as f:
                reader = csv.DictReader(f)
                
                for row in reader:
                    try:
                        processed_entry = self.process_entry(row)
                        processed_entries.append(processed_entry)
                    except Exception as e:
                        print(f"⚠️ Warning: Failed to process entry {row.get('id', 'unknown')}: {e}")
                        continue
            
            # Write processed entries to output file
            with open(output_file, 'w', newline='', encoding='utf-8') as f:
                fieldnames = ['question', 'answer', 'category', 'tags', 'priority']
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()
                writer.writerows(processed_entries)
            
            print(f"✅ Successfully processed {len(processed_entries)} entries")
            print(f"📁 Enhanced knowledge base saved to: {output_file}")
            
            # Generate statistics
            self.generate_statistics(processed_entries)
            
        except Exception as e:
            print(f"❌ Error processing documentation: {e}")
            raise
    
    def generate_statistics(self, entries: List[Dict[str, str]]):
        """Generate and display statistics about processed entries."""
        from collections import Counter
        
        print("\n📊 PROCESSING STATISTICS:")
        print(f"   Total entries processed: {len(entries)}")
        
        # Priority distribution
        priorities = Counter(entry['priority'] for entry in entries)
        print(f"   Priority distribution: {dict(priorities)}")
        
        # Tag analysis
        all_tags = []
        for entry in entries:
            all_tags.extend(entry['tags'].split(','))
        
        tag_counts = Counter(all_tags)
        print(f"   Top 10 tags: {dict(tag_counts.most_common(10))}")
        
        # Content length analysis
        question_lengths = [len(entry['question']) for entry in entries]
        answer_lengths = [len(entry['answer']) for entry in entries]
        
        print(f"   Avg question length: {sum(question_lengths)/len(question_lengths):.0f} chars")
        print(f"   Avg answer length: {sum(answer_lengths)/len(answer_lengths):.0f} chars")


def main():
    """Main processing function."""
    processor = WebDocumentationProcessor()
    
    input_file = "web-documentation.csv"
    output_file = "data/knowledge_base/datadog_mulesoft_web_docs.csv"
    
    # Ensure output directory exists
    Path(output_file).parent.mkdir(parents=True, exist_ok=True)
    
    print("🚀 Starting Web Documentation Processing...")
    processor.process_documentation_csv(input_file, output_file)
    print("✨ Web documentation processing complete!")


if __name__ == "__main__":
    main()