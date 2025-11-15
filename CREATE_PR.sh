#!/bin/bash
# Create Pull Request via gh CLI

echo "🚀 Creating Pull Request for Echoelmusic Ecosystem..."

gh pr create \
  --base main \
  --head claude/reorganize-echoelmusic-unified-structure-01BamFYsWe5q8yJUoKqCSR4T \
  --title "🌟 Echoelmusic Ecosystem - Complete Reorganization & DAW Foundation" \
  --body-file PR_DESCRIPTION.md \
  --assignee @me

echo "✅ Pull Request created!"
echo ""
echo "Next steps:"
echo "1. Review the PR on GitHub"
echo "2. Run tests if configured"
echo "3. Merge when ready"
