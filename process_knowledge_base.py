#!/usr/bin/env python3
"""
Script to process and enhance the Datadog Mule Integration knowledge base
from the raw CSV format to a structured format matching the existing knowledge base.
"""

import csv
import re
import json
from typing import Dict, List, Tuple

def extract_structured_content(content: str) -> Dict[str, str]:
    """
    Extract structured information from the content field.
    
    Args:
        content: Raw content string with Title, Description, Problem, Resolution
        
    Returns:
        Dictionary with extracted structured information
    """
    result = {
        'title': '',
        'description': '',
        'problem': '',
        'resolution': '',
        'category': 'datadog-mulesoft',
        'tags': [],
        'priority': 'medium'
    }
    
    # Extract title
    title_match = re.search(r'Title:\s*([^\n\r]+)', content, re.IGNORECASE)
    if title_match:
        result['title'] = title_match.group(1).strip()
    
    # Extract description
    desc_match = re.search(r'Description:\s*([^\n\r]*?)(?=Problem:|$)', content, re.IGNORECASE | re.DOTALL)
    if desc_match:
        result['description'] = desc_match.group(1).strip()
    
    # Extract problem
    problem_match = re.search(r'Problem:\s*(.*?)(?=Resolution:|$)', content, re.IGNORECASE | re.DOTALL)
    if problem_match:
        result['problem'] = problem_match.group(1).strip()
    
    # Extract resolution
    resolution_match = re.search(r'Resolution:\s*(.*?)$', content, re.IGNORECASE | re.DOTALL)
    if resolution_match:
        result['resolution'] = resolution_match.group(1).strip()
    
    return result

def generate_tags(title: str, description: str, problem: str, resolution: str) -> List[str]:
    """
    Generate relevant tags based on the content.
    
    Args:
        title, description, problem, resolution: Content fields
        
    Returns:
        List of relevant tags
    """
    content_text = f"{title} {description} {problem} {resolution}".lower()
    
    # Define tag keywords
    tag_mapping = {
        'activation': ['activation', 'activate', 'enable', 'setup', 'configure'],
        'configuration': ['config', 'configure', 'setup', 'settings', 'parameter'],
        'integration': ['integration', 'integrate', 'connect', 'connection'],
        'mulesoft': ['mulesoft', 'mule', 'anypoint', 'rtf', 'cloudhub'],
        'datadog': ['datadog', 'dd', 'monitoring', 'metrics', 'traces'],
        'troubleshooting': ['error', 'issue', 'problem', 'troubleshoot', 'debug'],
        'authentication': ['auth', 'login', 'credential', 'token', 'api key'],
        'deployment': ['deploy', 'deployment', 'runtime', 'environment'],
        'performance': ['performance', 'memory', 'cpu', 'optimization', 'jvm'],
        'network': ['network', 'connectivity', 'port', 'firewall', 'proxy'],
        'version': ['version', 'update', 'upgrade', 'compatibility'],
        'logs': ['log', 'logging', 'trace', 'debug', 'monitor']
    }
    
    tags = []
    for tag, keywords in tag_mapping.items():
        if any(keyword in content_text for keyword in keywords):
            tags.append(tag)
    
    # Always include base tags
    if 'datadog' not in tags:
        tags.append('datadog')
    if 'mulesoft' not in tags:
        tags.append('mulesoft')
    
    return tags[:5]  # Limit to 5 most relevant tags

def determine_priority(title: str, problem: str, resolution: str) -> str:
    """
    Determine priority based on content analysis.
    
    Returns:
        Priority level: high, medium, or low
    """
    content_text = f"{title} {problem} {resolution}".lower()
    
    high_priority_keywords = [
        'error', 'fail', 'crash', 'critical', 'urgent', 'down', 'outage',
        'security', 'authentication', 'authorization', 'data loss'
    ]
    
    low_priority_keywords = [
        'documentation', 'reference', 'example', 'guide', 'tutorial',
        'feature request', 'enhancement', 'nice to have'
    ]
    
    if any(keyword in content_text for keyword in high_priority_keywords):
        return 'high'
    elif any(keyword in content_text for keyword in low_priority_keywords):
        return 'low'
    else:
        return 'medium'

def create_qa_format(structured_data: Dict[str, str]) -> Tuple[str, str]:
    """
    Create question and answer format from structured data.
    
    Returns:
        Tuple of (question, answer)
    """
    # Create question from title and problem
    question_parts = []
    if structured_data['title']:
        question_parts.append(structured_data['title'])
    if structured_data['problem'] and structured_data['problem'] != structured_data['title']:
        question_parts.append(structured_data['problem'])
    
    question = ' - '.join(question_parts) if question_parts else "Datadog MuleSoft Integration Question"
    
    # Create comprehensive answer
    answer_parts = []
    if structured_data['description']:
        answer_parts.append(f"Overview: {structured_data['description']}")
    if structured_data['problem']:
        answer_parts.append(f"Problem: {structured_data['problem']}")
    if structured_data['resolution']:
        answer_parts.append(f"Resolution: {structured_data['resolution']}")
    
    answer = '\n\n'.join(answer_parts) if answer_parts else "Please refer to the documentation for more information."
    
    return question, answer

def process_knowledge_base(input_file: str, output_file: str):
    """
    Process the raw knowledge base CSV and create enhanced version.
    
    Args:
        input_file: Path to input CSV file
        output_file: Path to output enhanced CSV file
    """
    processed_entries = []
    
    with open(input_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        for row in reader:
            # Extract structured content
            structured = extract_structured_content(row['content'])
            
            # Generate tags and priority
            tags = generate_tags(
                structured['title'],
                structured['description'], 
                structured['problem'],
                structured['resolution']
            )
            priority = determine_priority(
                structured['title'],
                structured['problem'],
                structured['resolution']
            )
            
            # Create Q&A format
            question, answer = create_qa_format(structured)
            
            # Create processed entry
            processed_entry = {
                'question': question,
                'answer': answer,
                'category': 'datadog-mulesoft',
                'tags': ','.join(tags),
                'priority': priority
            }
            
            processed_entries.append(processed_entry)
    
    # Write enhanced CSV
    with open(output_file, 'w', newline='', encoding='utf-8') as f:
        fieldnames = ['question', 'answer', 'category', 'tags', 'priority']
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(processed_entries)
    
    print(f"Processed {len(processed_entries)} entries")
    print(f"Enhanced knowledge base saved to: {output_file}")
    
    # Generate statistics
    categories = {}
    priorities = {'high': 0, 'medium': 0, 'low': 0}
    all_tags = []
    
    for entry in processed_entries:
        cat = entry['category']
        categories[cat] = categories.get(cat, 0) + 1
        priorities[entry['priority']] += 1
        all_tags.extend(entry['tags'].split(','))
    
    from collections import Counter
    tag_counts = Counter(all_tags)
    
    print(f"\nStatistics:")
    print(f"Categories: {categories}")
    print(f"Priorities: {priorities}")
    print(f"Top 10 tags: {dict(tag_counts.most_common(10))}")

if __name__ == "__main__":
    input_file = "knowledge-base.csv"
    output_file = "data/knowledge_base/datadog_mulesoft_integration.csv"
    
    print("Processing Datadog MuleSoft Integration Knowledge Base...")
    process_knowledge_base(input_file, output_file)
    print("Knowledge base processing complete!")