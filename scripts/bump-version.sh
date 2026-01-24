#!/bin/bash
# =============================================================================
# ECHOELMUSIC - VERSION BUMP SCRIPT
# =============================================================================
# Automatically increment version numbers for releases
# Usage: ./scripts/bump-version.sh [major|minor|patch]
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_FILE="project.yml"
DEPLOY_FILE=".github/workflows/deploy.yml"

# Get current version from project.yml
CURRENT_VERSION=$(grep 'MARKETING_VERSION:' "$PROJECT_FILE" | head -1 | sed 's/.*MARKETING_VERSION: "\([^"]*\)".*/\1/')

if [ -z "$CURRENT_VERSION" ]; then
    echo -e "${RED}Error: Could not find current version in $PROJECT_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}Current version: ${GREEN}$CURRENT_VERSION${NC}"

# Parse version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Determine bump type
BUMP_TYPE="${1:-patch}"

case "$BUMP_TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo -e "${RED}Error: Invalid bump type '$BUMP_TYPE'${NC}"
        echo "Usage: $0 [major|minor|patch]"
        exit 1
        ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

echo -e "${YELLOW}Bumping $BUMP_TYPE version...${NC}"
echo -e "${BLUE}New version: ${GREEN}$NEW_VERSION${NC}"

# Update project.yml
sed -i '' "s/MARKETING_VERSION: \"$CURRENT_VERSION\"/MARKETING_VERSION: \"$NEW_VERSION\"/" "$PROJECT_FILE"
echo -e "${GREEN}✓ Updated $PROJECT_FILE${NC}"

# Update deploy.yml
sed -i '' "s/VERSION: '$CURRENT_VERSION'/VERSION: '$NEW_VERSION'/" "$DEPLOY_FILE"
echo -e "${GREEN}✓ Updated $DEPLOY_FILE${NC}"

# Update release notes
RELEASE_NOTES="fastlane/metadata/release_notes.txt"
if [ -f "$RELEASE_NOTES" ]; then
    # Prepend new version header
    DATE=$(date +%Y-%m-%d)
    TEMP_FILE=$(mktemp)
    echo "v$NEW_VERSION ($DATE)" > "$TEMP_FILE"
    echo "---" >> "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
    cat "$RELEASE_NOTES" >> "$TEMP_FILE"
    mv "$TEMP_FILE" "$RELEASE_NOTES"
    echo -e "${GREEN}✓ Updated $RELEASE_NOTES${NC}"
fi

echo ""
echo -e "${GREEN}Version bump complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Commit: git commit -am 'chore: bump version to $NEW_VERSION'"
echo "  3. Tag: git tag v$NEW_VERSION"
echo "  4. Push: git push && git push --tags"
echo ""
