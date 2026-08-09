#!/usr/bin/env python3
"""
Smart Obsidian note formatter
Context-aware checkbox conversion, typo fixes, markdown cleanup
"""
import sys
import re
from typing import List

def is_todo_file(filename: str) -> bool:
    """Check if file is a todo/task file"""
    return any(x in filename.lower() for x in ['todo', 'task', 'wishlist', 'gift'])

def should_be_checkbox(line: str, is_todo_context: bool) -> bool:
    """Determine if line should be a checkbox"""
    stripped = line.lstrip('*-• ').strip()

    # Skip if already checkbox
    if line.strip().startswith(('- [ ]', '- [x]', '- [X]')):
        return False

    # Skip headers, code, blank, special
    if not stripped or stripped.startswith(('#', '```', '[', '>', '|', '---')):
        return False

    # Skip if looks like prose (ends with punctuation, long)
    if stripped.endswith(('.', '!', '?', ':')) and len(stripped) > 40:
        return False

    # Skip metadata lines
    if ':' in stripped and len(stripped.split(':')[0]) < 20:
        return False

    # In TODO files, convert bullet lists
    if is_todo_context and line.strip().startswith(('*', '-', '•')):
        return True

    # In TODO files, convert short standalone lines
    if is_todo_context and len(stripped) < 60 and not line.strip().startswith(('#', '---')):
        return True

    # In other files, only convert if explicitly bulleted
    if not is_todo_context and line.strip().startswith(('*', '-', '•')):
        # But not if it looks like notes/prose
        if len(stripped) < 80:
            return True

    return False

def fix_typos(text: str) -> str:
    """Fix common typos while preserving names and technical terms"""
    if '`' in text:  # Skip code
        return text

    fixes = [
        (r'\btypes cript\b', 'TypeScript'),
        (r'\binstalled app just fin\b', 'installed app, just finished'),
        (r'\bdoesnt\b', "doesn't"),
        (r'\bdidnt\b', "didn't"),
        (r'\bwont\b', "won't"),
        (r'\bcant\b', "can't"),
        (r'\bim\s', "I'm "),
        (r'\bive\s', "I've "),
        (r'\btheres\b', "there's"),
    ]

    result = text
    for pattern, replacement in fixes:
        result = re.sub(pattern, replacement, result, flags=re.IGNORECASE)

    return result

def format_note(content: str, filename: str = "") -> str:
    """Format markdown note with context-aware rules"""
    is_todo = is_todo_file(filename)
    lines = content.split('\n')
    formatted = []
    in_code = False
    prev_blank = False

    for line in lines:
        # Code blocks
        if line.strip().startswith('```'):
            in_code = not in_code
            formatted.append(line)
            prev_blank = False
            continue

        if in_code:
            formatted.append(line)
            prev_blank = False
            continue

        # Blank lines (collapse multiples)
        if not line.strip():
            if not prev_blank:
                formatted.append('')
            prev_blank = True
            continue

        prev_blank = False

        # Convert to checkbox?
        if should_be_checkbox(line, is_todo):
            stripped = line.lstrip('*-• ').strip()
            indent = len(line) - len(line.lstrip())
            formatted.append(' ' * indent + f'- [ ] {stripped}')
            continue

        # Fix typos
        fixed = fix_typos(line)

        # Ensure headers have space
        if fixed.lstrip().startswith('#'):
            fixed = re.sub(r'^(\s*)(#+)([^ ])', r'\1\2 \3', fixed)

        formatted.append(fixed)

    # Trim trailing blanks
    while formatted and not formatted[-1].strip():
        formatted.pop()

    return '\n'.join(formatted) + '\n'

if __name__ == '__main__':
    filename = sys.argv[1] if len(sys.argv) > 1 else ""
    content = sys.stdin.read()
    formatted = format_note(content, filename)
    print(formatted, end='')
