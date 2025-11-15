#!/bin/bash
# Run this AFTER merging the PR on GitHub

echo "🔄 Updating local repository after merge..."

# Switch to main branch
git checkout main

# Pull latest changes (including your merged PR)
git pull origin main

# Verify we're up to date
git log --oneline -5

echo ""
echo "✅ Local main branch updated!"
echo ""
echo "Current status:"
git status

echo ""
echo "📊 Repository overview:"
echo "Total commits: $(git rev-list --count main)"
echo "Total files: $(git ls-files | wc -l)"
echo "Latest commit: $(git log -1 --pretty=format:'%h - %s')"

echo ""
echo "🎉 Echoelmusic Ecosystem is now on main!"
