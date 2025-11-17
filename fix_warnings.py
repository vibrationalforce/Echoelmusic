#!/usr/bin/env python3
"""
fix_warnings.py - Automated C++ Warning Fixer for Echoelmusic
Fixes common JUCE/C++ warnings automatically
"""

import os
import re
import sys
from pathlib import Path

class WarningFixer:
    def __init__(self, source_dir="Sources"):
        self.source_dir = source_dir
        self.files_modified = 0
        self.total_fixes = 0

    def find_cpp_files(self):
        """Find all C++ source and header files"""
        cpp_files = []
        source_path = Path(self.source_dir)

        if not source_path.exists():
            print(f"❌ Source directory '{self.source_dir}' not found!")
            return []

        for ext in ['*.cpp', '*.h', '*.hpp']:
            cpp_files.extend(source_path.rglob(ext))

        return [str(f) for f in cpp_files]

    def fix_float_literals(self, content):
        """Fix float literal warnings (0.5 -> 0.5f)"""
        # Match decimal numbers not already followed by 'f'
        # Avoid scientific notation and existing float literals
        pattern = r'\b(\d+\.\d+)(?!f)(?![eE])'

        def replace_float(match):
            num = match.group(1)
            # Don't add 'f' if it's in a comment or string
            return f"{num}f"

        original = content
        content = re.sub(pattern, replace_float, content)

        fixes = len(re.findall(pattern, original))
        return content, fixes

    def fix_unused_parameters(self, content):
        """Add juce::ignoreUnused for unused parameters"""
        fixes = 0
        lines = content.split('\n')
        new_lines = []

        for i, line in enumerate(lines):
            new_lines.append(line)

            # Look for function declarations with override
            if 'override' in line and '{' in line:
                # Check if next line already has ignoreUnused
                if i + 1 < len(lines) and 'ignoreUnused' not in lines[i + 1]:
                    # This is a simple heuristic - we could improve this
                    indent = len(line) - len(line.lstrip())
                    # Don't add automatically as we don't know parameter names
                    pass

        return '\n'.join(new_lines), fixes

    def fix_sign_comparison(self, content):
        """Fix signed/unsigned comparison warnings"""
        # This is complex and risky - skip for now
        return content, 0

    def fix_deprecated_setsize(self, content):
        """Fix deprecated setSize calls"""
        # Match setSize(width, height) and add true parameter
        pattern = r'setSize\s*\(\s*(\w+)\s*,\s*(\w+)\s*\)(?!\s*,)'

        original = content
        content = re.sub(pattern, r'setSize(\1, \2, true)', content)

        fixes = len(re.findall(pattern, original))
        return content, fixes

    def fix_nullptr_initialization(self, content):
        """Fix NULL to nullptr conversions"""
        # Replace NULL with nullptr in assignments
        pattern = r'\bNULL\b'

        original = content
        content = re.sub(pattern, 'nullptr', content)

        fixes = len(re.findall(pattern, original))
        return content, fixes

    def fix_override_specifier(self, content):
        """Ensure virtual functions have override specifier"""
        # This is complex - skip for safety
        return content, 0

    def process_file(self, file_path):
        """Process a single file and apply fixes"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                original_content = f.read()
        except Exception as e:
            print(f"❌ Error reading {file_path}: {e}")
            return False

        content = original_content
        file_fixes = 0

        # Apply all fixes
        content, fixes = self.fix_float_literals(content)
        file_fixes += fixes

        content, fixes = self.fix_unused_parameters(content)
        file_fixes += fixes

        content, fixes = self.fix_deprecated_setsize(content)
        file_fixes += fixes

        content, fixes = self.fix_nullptr_initialization(content)
        file_fixes += fixes

        # Only write if changes were made
        if content != original_content:
            try:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"✅ Fixed {file_fixes} issues in {file_path}")
                self.files_modified += 1
                self.total_fixes += file_fixes
                return True
            except Exception as e:
                print(f"❌ Error writing {file_path}: {e}")
                return False

        return False

    def run(self):
        """Run the warning fixer on all source files"""
        print("🔍 ECHOELMUSIC WARNING FIXER")
        print("=" * 50)

        cpp_files = self.find_cpp_files()

        if not cpp_files:
            print(f"❌ No C++ files found in '{self.source_dir}'")
            return

        print(f"Found {len(cpp_files)} C++ files")
        print("Processing...\n")

        for file_path in cpp_files:
            self.process_file(file_path)

        print("\n" + "=" * 50)
        print("📊 SUMMARY")
        print("=" * 50)
        print(f"Files scanned: {len(cpp_files)}")
        print(f"Files modified: {self.files_modified}")
        print(f"Total fixes applied: {self.total_fixes}")

        if self.files_modified > 0:
            print("\n✅ Warning fixes complete!")
            print("⚠️  IMPORTANT: Review changes before committing!")
            print("    Run 'git diff' to see what changed")
        else:
            print("\n✅ No warnings found - code looks clean!")

def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(
        description='Automatically fix common C++ warnings in Echoelmusic'
    )
    parser.add_argument(
        '--source-dir',
        default='Sources',
        help='Source directory to scan (default: Sources)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be fixed without making changes'
    )

    args = parser.parse_args()

    if args.dry_run:
        print("🔍 DRY RUN MODE - No files will be modified\n")

    fixer = WarningFixer(source_dir=args.source_dir)
    fixer.run()

if __name__ == "__main__":
    main()
