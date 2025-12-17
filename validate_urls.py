#!/usr/bin/env python3
"""
Comprehensive URL validation for models_manifest.json
Tests all model URLs for accessibility, auth requirements, and correctness
"""

import json
import sys
import os
import requests
from pathlib import Path
from typing import Dict, List, Tuple
from urllib.parse import urlparse

# Fix Windows encoding issues
if sys.platform == 'win32':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

# Color codes for terminal output (disabled on Windows if needed)
class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


def check_url(name: str, url: str, auth: str, min_size: int) -> Tuple[str, str, dict]:
    """
    Check if URL is accessible
    Returns: (status, message, details)
    """
    details = {
        'status_code': None,
        'content_length': None,
        'content_type': None,
        'redirects': 0
    }
    
    try:
        # Make HEAD request to avoid downloading the file
        response = requests.head(
            url, 
            allow_redirects=True, 
            timeout=15,
            headers={'User-Agent': 'Mozilla/5.0'}
        )
        
        details['status_code'] = response.status_code
        details['content_length'] = response.headers.get('Content-Length')
        details['content_type'] = response.headers.get('Content-Type')
        details['redirects'] = len(response.history)
        
        # Check status code
        if response.status_code == 200:
            # Verify content length if available
            if details['content_length']:
                size = int(details['content_length'])
                if size < min_size:
                    return "WARNING", f"File too small: {size:,} bytes (expected >{min_size:,})", details
                return "OK", f"Accessible ({size:,} bytes)", details
            return "OK", "Accessible (size unknown)", details
            
        elif response.status_code == 401:
            if auth == "none":
                return "ERROR", "Requires auth but marked as 'none'", details
            elif auth == "hf_token":
                return "WARNING", "Auth field should be 'hf' not 'hf_token'", details
            else:
                return "OK", "Gated (auth required) ✓", details
                
        elif response.status_code == 403:
            return "ERROR", "Forbidden (403)", details
            
        elif response.status_code == 404:
            return "ERROR", "Not found (404) - URL may be dead", details
            
        elif response.status_code >= 300 and response.status_code < 400:
            return "WARNING", f"Unexpected redirect ({response.status_code})", details
            
        else:
            return "ERROR", f"HTTP {response.status_code}", details
            
    except requests.exceptions.Timeout:
        return "ERROR", "Request timeout (>15s)", details
        
    except requests.exceptions.ConnectionError:
        return "ERROR", "Connection failed", details
        
    except Exception as e:
        return "ERROR", f"Exception: {str(e)[:50]}", details

def validate_manifest(manifest_path: str) -> Dict:
    """Validate all URLs in manifest"""
    
    if not Path(manifest_path).exists():
        print(f"{Colors.RED}❌ Manifest not found: {manifest_path}{Colors.RESET}")
        sys.exit(1)
    
    with open(manifest_path, 'r') as f:
        manifest = json.load(f)
    
    results = {
        'total': 0,
        'ok': 0,
        'warnings': 0,
        'errors': 0,
        'details': []
    }
    
    print(f"\n{Colors.BOLD}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}COMPREHENSIVE MODEL URL VALIDATION{Colors.RESET}")
    print(f"{Colors.BOLD}{'='*80}{Colors.RESET}\n")
    
    for category, models in manifest.items():
        print(f"\n{Colors.BLUE}{'─'*80}{Colors.RESET}")
        print(f"{Colors.BLUE}{Colors.BOLD}📦 Category: {category.upper()}{Colors.RESET}")
        print(f"{Colors.BLUE}{'─'*80}{Colors.RESET}\n")
        
        for name, meta in models.items():
            results['total'] += 1
            url = meta.get('url', '')
            auth = meta.get('auth', 'none')
            min_size = meta.get('min_size', 1000000)
            modes = ', '.join(meta.get('modes', []))
            
            # Parse URL to get domain
            domain = urlparse(url).netloc
            
            print(f"Testing: {Colors.BOLD}{name}{Colors.RESET}")
            print(f"  Domain: {domain}")
            print(f"  Auth  : {auth}")
            print(f"  Modes : {modes}")
            print(f"  URL   : {url[:70]}{'...' if len(url) > 70 else ''}")
            
            status, message, details = check_url(name, url, auth, min_size)
            
            # Color code the result
            if status == "OK":
                color = Colors.GREEN
                icon = "[OK]"
                results['ok'] += 1
            elif status == "WARNING":
                color = Colors.YELLOW
                icon = "[WARN]"
                results['warnings'] += 1
            else:
                color = Colors.RED
                icon = "[ERROR]"
                results['errors'] += 1
            
            print(f"  {color}{icon} {status}: {message}{Colors.RESET}")
            
            # Store detailed result
            results['details'].append({
                'category': category,
                'name': name,
                'status': status,
                'message': message,
                'url': url,
                'auth': auth,
                'modes': meta.get('modes', []),
                'http_status': details['status_code'],
                'size': details['content_length']
            })
            
            print()  # Blank line between entries
    
    return results

def print_summary(results: Dict):
    """Print summary report"""
    
    print(f"\n{Colors.BOLD}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}SUMMARY REPORT{Colors.RESET}")
    print(f"{Colors.BOLD}{'='*80}{Colors.RESET}\n")
    
    total = results['total']
    ok = results['ok']
    warnings = results['warnings']
    errors = results['errors']
    
    print(f"Total models tested: {Colors.BOLD}{total}{Colors.RESET}")
    print(f"{Colors.GREEN}[OK]       : {ok} ({ok/total*100:.1f}%){Colors.RESET}")
    print(f"{Colors.YELLOW}[WARN]     : {warnings} ({warnings/total*100:.1f}%){Colors.RESET}")
    print(f"{Colors.RED}[ERROR]    : {errors} ({errors/total*100:.1f}%){Colors.RESET}")
    
    # List all issues
    if warnings > 0:
        print(f"\n{Colors.YELLOW}{Colors.BOLD}WARNINGS:{Colors.RESET}")
        for item in results['details']:
            if item['status'] == 'WARNING':
                print(f"  {Colors.YELLOW}[WARN] {item['name']}{Colors.RESET}")
                print(f"     {item['message']}")
                print(f"     Auth: {item['auth']} | Modes: {', '.join(item['modes'])}")
    
    if errors > 0:
        print(f"\n{Colors.RED}{Colors.BOLD}ERRORS:{Colors.RESET}")
        for item in results['details']:
            if item['status'] == 'ERROR':
                print(f"  {Colors.RED}[ERROR] {item['name']}{Colors.RESET}")
                print(f"     {item['message']}")
                print(f"     URL: {item['url'][:70]}{'...' if len(item['url']) > 70 else ''}")
                print(f"     Auth: {item['auth']} | Modes: {', '.join(item['modes'])}")
    
    print(f"\n{Colors.BOLD}{'='*80}{Colors.RESET}\n")
    
    # Exit code based on results
    if errors > 0:
        print(f"{Colors.RED}Validation FAILED - {errors} critical error(s) found{Colors.RESET}")
        return 1
    elif warnings > 0:
        print(f"{Colors.YELLOW}Validation PASSED with {warnings} warning(s){Colors.RESET}")
        return 0
    else:
        print(f"{Colors.GREEN}Validation PASSED - all URLs are healthy!{Colors.RESET}")
        return 0

def main():
    manifest_path = "configs/models_manifest.json"
    
    # Allow custom path as argument
    if len(sys.argv) > 1:
        manifest_path = sys.argv[1]
    
    results = validate_manifest(manifest_path)
    exit_code = print_summary(results)
    
    sys.exit(exit_code)

if __name__ == "__main__":
    main()
