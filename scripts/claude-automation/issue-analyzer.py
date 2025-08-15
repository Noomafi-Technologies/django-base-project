#!/usr/bin/env python3
"""
Claude Issue Analyzer
Analyzes GitHub issues and extracts requirements for automated solving.
"""

import re
import json
import subprocess
import sys
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass


@dataclass
class IssueInfo:
    """Container for GitHub issue information"""
    number: int
    title: str
    body: str
    labels: List[str]
    assignees: List[str]
    state: str
    url: str
    
    @property
    def issue_type(self) -> str:
        """Determine issue type from labels or title"""
        if any(label in ['bug', 'fix'] for label in self.labels):
            return 'fix'
        elif any(label in ['enhancement', 'improvement'] for label in self.labels):
            return 'enhancement'
        elif any(label in ['feature', 'new'] for label in self.labels):
            return 'feature'
        elif any(label in ['docs', 'documentation'] for label in self.labels):
            return 'docs'
        elif 'test' in self.labels:
            return 'test'
        else:
            # Analyze title for keywords
            title_lower = self.title.lower()
            if any(word in title_lower for word in ['fix', 'bug', 'error', 'issue']):
                return 'fix'
            elif any(word in title_lower for word in ['add', 'new', 'create', 'implement']):
                return 'feature'
            elif any(word in title_lower for word in ['improve', 'enhance', 'update']):
                return 'enhancement'
            else:
                return 'feature'  # Default to feature
    
    @property
    def branch_name(self) -> str:
        """Generate branch name from issue"""
        # Clean title for branch name
        clean_title = re.sub(r'[^\w\s-]', '', self.title.lower())
        clean_title = re.sub(r'\s+', '-', clean_title.strip())
        clean_title = clean_title[:50]  # Limit length
        
        return f"{self.issue_type}/issue-{self.number}-{clean_title}"
    
    @property
    def requirements(self) -> List[str]:
        """Extract requirements from issue body"""
        requirements = []
        
        # Look for checklist items
        checklist_pattern = r'[-*]\s*\[[ x]\]\s*(.+)'
        checklists = re.findall(checklist_pattern, self.body, re.MULTILINE)
        requirements.extend(checklists)
        
        # Look for numbered lists
        numbered_pattern = r'^\d+\.\s*(.+)'
        numbered = re.findall(numbered_pattern, self.body, re.MULTILINE)
        requirements.extend(numbered)
        
        # Look for acceptance criteria
        acceptance_pattern = r'(?:acceptance criteria|requirements?)[:\s]*\n((?:[-*]\s*.+\n?)+)'
        acceptance_match = re.search(acceptance_pattern, self.body, re.IGNORECASE | re.MULTILINE)
        if acceptance_match:
            acceptance_items = re.findall(r'[-*]\s*(.+)', acceptance_match.group(1))
            requirements.extend(acceptance_items)
        
        return [req.strip() for req in requirements if req.strip()]


class GitHubIssueAnalyzer:
    """Analyzes GitHub issues using gh CLI"""
    
    def __init__(self, repo: str = None):
        self.repo = repo or self._get_current_repo()
    
    def _get_current_repo(self) -> str:
        """Get current repository from git remote"""
        try:
            result = subprocess.run(
                ['git', 'remote', 'get-url', 'origin'],
                capture_output=True,
                text=True,
                check=True
            )
            remote_url = result.stdout.strip()
            
            # Extract owner/repo from URL
            if 'github.com' in remote_url:
                if remote_url.startswith('git@'):
                    # SSH format: git@github.com:owner/repo.git
                    match = re.search(r'github\.com:([^/]+/[^/]+)\.git', remote_url)
                else:
                    # HTTPS format: https://github.com/owner/repo.git
                    match = re.search(r'github\.com/([^/]+/[^/]+)\.git', remote_url)
                
                if match:
                    return match.group(1)
            
            raise ValueError("Could not parse GitHub repository from remote URL")
        except subprocess.CalledProcessError:
            raise ValueError("Not in a git repository or no origin remote found")
    
    def fetch_issue(self, issue_number: int) -> IssueInfo:
        """Fetch issue details from GitHub"""
        try:
            # Fetch issue as JSON
            result = subprocess.run([
                'gh', 'issue', 'view', str(issue_number),
                '--repo', self.repo,
                '--json', 'number,title,body,labels,assignees,state,url'
            ], capture_output=True, text=True, check=True)
            
            issue_data = json.loads(result.stdout)
            
            return IssueInfo(
                number=issue_data['number'],
                title=issue_data['title'],
                body=issue_data.get('body', ''),
                labels=[label['name'] for label in issue_data.get('labels', [])],
                assignees=[assignee['login'] for assignee in issue_data.get('assignees', [])],
                state=issue_data['state'],
                url=issue_data['url']
            )
        except subprocess.CalledProcessError as e:
            raise ValueError(f"Failed to fetch issue #{issue_number}: {e}")
    
    def analyze_complexity(self, issue: IssueInfo) -> str:
        """Analyze issue complexity"""
        complexity_indicators = {
            'simple': ['typo', 'documentation', 'readme', 'comment'],
            'medium': ['feature', 'endpoint', 'view', 'model', 'form'],
            'complex': ['authentication', 'deployment', 'database', 'migration', 'security']
        }
        
        text = (issue.title + ' ' + issue.body).lower()
        
        for complexity, keywords in complexity_indicators.items():
            if any(keyword in text for keyword in keywords):
                return complexity
        
        # Default based on requirements count
        req_count = len(issue.requirements)
        if req_count <= 2:
            return 'simple'
        elif req_count <= 5:
            return 'medium'
        else:
            return 'complex'
    
    def extract_files_to_modify(self, issue: IssueInfo) -> List[str]:
        """Extract likely files that need modification"""
        files = []
        text = (issue.title + ' ' + issue.body).lower()
        
        # Look for explicit file mentions
        file_patterns = [
            r'`([^`]+\.(py|js|html|css|md|txt|json|yml|yaml))`',
            r'([a-zA-Z_][a-zA-Z0-9_]*\.py)',
            r'(settings\.py|urls\.py|models\.py|views\.py|serializers\.py)',
        ]
        
        for pattern in file_patterns:
            matches = re.findall(pattern, text)
            for match in matches:
                if isinstance(match, tuple):
                    files.append(match[0])
                else:
                    files.append(match)
        
        # Infer files based on keywords
        if 'model' in text or 'database' in text:
            files.append('models.py')
        if 'api' in text or 'endpoint' in text:
            files.append('views.py')
            files.append('serializers.py')
            files.append('urls.py')
        if 'admin' in text:
            files.append('admin.py')
        if 'test' in text:
            files.append('tests.py')
        if 'migration' in text:
            files.append('migrations/')
        if 'deployment' in text or 'docker' in text:
            files.extend(['Dockerfile', 'docker-compose.yml', 'requirements.txt'])
        
        return list(set(files))


def parse_issue_reference(reference: str) -> int:
    """Parse issue number from various formats"""
    # GitHub URL
    url_match = re.search(r'github\.com/[^/]+/[^/]+/issues/(\d+)', reference)
    if url_match:
        return int(url_match.group(1))
    
    # Issue number with #
    hash_match = re.search(r'#(\d+)', reference)
    if hash_match:
        return int(hash_match.group(1))
    
    # Plain number
    if reference.isdigit():
        return int(reference)
    
    raise ValueError(f"Could not parse issue number from: {reference}")


def main():
    """Main CLI interface"""
    if len(sys.argv) != 2:
        print("Usage: python issue-analyzer.py <issue-number-or-url>")
        sys.exit(1)
    
    try:
        issue_ref = sys.argv[1]
        issue_number = parse_issue_reference(issue_ref)
        
        analyzer = GitHubIssueAnalyzer()
        issue = analyzer.fetch_issue(issue_number)
        
        print(f"Issue #{issue.number}: {issue.title}")
        print(f"Type: {issue.issue_type}")
        print(f"Branch: {issue.branch_name}")
        print(f"Complexity: {analyzer.analyze_complexity(issue)}")
        print(f"Labels: {', '.join(issue.labels)}")
        
        if issue.requirements:
            print("\nRequirements:")
            for req in issue.requirements:
                print(f"  - {req}")
        
        files = analyzer.extract_files_to_modify(issue)
        if files:
            print(f"\nLikely files to modify:")
            for file in files:
                print(f"  - {file}")
        
        # Output JSON for programmatic use
        output = {
            'issue': {
                'number': issue.number,
                'title': issue.title,
                'body': issue.body,
                'type': issue.issue_type,
                'branch_name': issue.branch_name,
                'complexity': analyzer.analyze_complexity(issue),
                'requirements': issue.requirements,
                'files_to_modify': files,
                'labels': issue.labels,
                'url': issue.url
            }
        }
        
        with open(f'/tmp/issue-{issue.number}-analysis.json', 'w') as f:
            json.dump(output, f, indent=2)
        
        print(f"\nAnalysis saved to: /tmp/issue-{issue.number}-analysis.json")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()