#!/bin/bash
#
# deploy_privacy_policy.sh
# Automated Privacy Policy Deployment to GitHub Pages
#
# This script automates the hosting of your privacy policy on GitHub Pages
# Run this script to make your privacy policy publicly accessible
#

set -e  # Exit on error

echo "🔐 Echoelmusic - Privacy Policy Deployment Script"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if privacy-policy.html exists
if [ ! -f "privacy-policy.html" ]; then
    echo -e "${RED}❌ Error: privacy-policy.html not found!${NC}"
    echo "Please ensure you're in the Echoelmusic project directory"
    exit 1
fi

echo -e "${BLUE}📋 Deployment Options:${NC}"
echo ""
echo "1. GitHub Pages (Recommended - Free)"
echo "2. Create standalone zip for manual upload"
echo "3. Generate Firebase hosting config"
echo "4. Generate Netlify config"
echo ""
read -p "Select deployment option (1-4): " option

case $option in
    1)
        echo -e "${GREEN}🚀 Setting up GitHub Pages...${NC}"
        echo ""

        # Check if we're in a git repo
        if [ ! -d ".git" ]; then
            echo -e "${RED}❌ Error: Not a git repository!${NC}"
            exit 1
        fi

        # Check if gh-pages branch exists
        if git rev-parse --verify gh-pages >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  gh-pages branch already exists${NC}"
            read -p "Delete and recreate? (y/n): " recreate
            if [ "$recreate" = "y" ]; then
                git branch -D gh-pages
            else
                echo "Switching to existing gh-pages branch..."
                git checkout gh-pages
            fi
        fi

        if ! git rev-parse --verify gh-pages >/dev/null 2>&1; then
            # Create orphan branch for GitHub Pages
            echo -e "${BLUE}📝 Creating gh-pages branch...${NC}"
            git checkout --orphan gh-pages

            # Remove all files from staging
            git rm -rf . 2>/dev/null || true

            # Copy privacy policy as index.html
            cp privacy-policy.html index.html

            # Create README for gh-pages
            cat > README.md << 'EOF'
# Echoelmusic Privacy Policy

This branch hosts the privacy policy for the Echoelmusic iOS app.

**Privacy Policy URL:** https://vibrationalforce.github.io/Echoelmusic/

## Compliance
- GDPR (European Union)
- CCPA (California)
- PIPEDA (Canada)
- LGPD (Brazil)

## Key Points
- NO data collection
- NO tracking or analytics
- NO ads
- All processing is LOCAL
- HealthKit data never leaves device
EOF

            # Add files
            git add index.html README.md

            # Commit
            git commit -m "Add privacy policy for Echoelmusic"

            # Push to GitHub
            echo -e "${BLUE}📤 Pushing to GitHub...${NC}"
            git push -u origin gh-pages

            # Switch back to original branch
            git checkout -

            echo ""
            echo -e "${GREEN}✅ SUCCESS!${NC}"
            echo ""
            echo -e "${GREEN}Your privacy policy is now hosted at:${NC}"
            echo -e "${BLUE}https://vibrationalforce.github.io/Echoelmusic/${NC}"
            echo ""
            echo "⏱️  Note: GitHub Pages may take 5-10 minutes to become available"
            echo ""
            echo "📋 Next Steps:"
            echo "   1. Wait 5-10 minutes for GitHub Pages to build"
            echo "   2. Visit the URL to verify it's working"
            echo "   3. Add this URL to App Store Connect"
            echo ""
        fi
        ;;

    2)
        echo -e "${GREEN}📦 Creating deployment package...${NC}"
        mkdir -p deploy
        cp privacy-policy.html deploy/index.html

        cat > deploy/README.txt << 'EOF'
Echoelmusic Privacy Policy - Manual Deployment Package

CONTENTS:
- index.html (privacy policy)

DEPLOYMENT INSTRUCTIONS:

Option 1: Upload to your website
1. Upload index.html to your web server
2. Access it at: https://yourwebsite.com/index.html
3. Add this URL to App Store Connect

Option 2: Firebase Hosting
1. Install Firebase CLI: npm install -g firebase-tools
2. Run: firebase init hosting
3. Set public directory to this folder
4. Run: firebase deploy
5. Use the provided URL

Option 3: Netlify
1. Drag and drop this folder to: https://app.netlify.com/drop
2. Use the provided URL
3. Add to App Store Connect

Option 4: Vercel
1. Install Vercel CLI: npm install -g vercel
2. Run: vercel
3. Follow the prompts
4. Use the provided URL
EOF

        # Create zip
        cd deploy
        zip -r ../privacy-policy-deployment.zip .
        cd ..

        echo ""
        echo -e "${GREEN}✅ Package created: privacy-policy-deployment.zip${NC}"
        echo ""
        echo "📋 Next Steps:"
        echo "   1. Extract the zip file"
        echo "   2. Follow instructions in README.txt"
        echo "   3. Upload to your hosting provider"
        echo ""
        ;;

    3)
        echo -e "${GREEN}🔥 Creating Firebase configuration...${NC}"

        cat > firebase.json << 'EOF'
{
  "hosting": {
    "public": ".",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "/",
        "destination": "/privacy-policy.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.html",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public, max-age=3600"
          }
        ]
      }
    ]
  }
}
EOF

        cat > .firebaserc << 'EOF'
{
  "projects": {
    "default": "echoelmusic"
  }
}
EOF

        echo ""
        echo -e "${GREEN}✅ Firebase configuration created!${NC}"
        echo ""
        echo "📋 Next Steps:"
        echo "   1. Install Firebase CLI: npm install -g firebase-tools"
        echo "   2. Login: firebase login"
        echo "   3. Create project: firebase projects:create echoelmusic"
        echo "   4. Deploy: firebase deploy --only hosting"
        echo "   5. Use the provided URL in App Store Connect"
        echo ""
        ;;

    4)
        echo -e "${GREEN}🎯 Creating Netlify configuration...${NC}"

        cat > netlify.toml << 'EOF'
[build]
  publish = "."

[[redirects]]
  from = "/"
  to = "/privacy-policy.html"
  status = 200

[[headers]]
  for = "/*.html"
  [headers.values]
    Cache-Control = "public, max-age=3600"
    X-Frame-Options = "DENY"
    X-Content-Type-Options = "nosniff"
    Referrer-Policy = "strict-origin-when-cross-origin"
EOF

        echo ""
        echo -e "${GREEN}✅ Netlify configuration created!${NC}"
        echo ""
        echo "📋 Next Steps:"
        echo "   1. Install Netlify CLI: npm install -g netlify-cli"
        echo "   2. Login: netlify login"
        echo "   3. Deploy: netlify deploy --prod"
        echo "   4. Use the provided URL in App Store Connect"
        echo ""
        echo "   OR drag-and-drop to: https://app.netlify.com/drop"
        echo ""
        ;;

    *)
        echo -e "${RED}❌ Invalid option${NC}"
        exit 1
        ;;
esac

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}Privacy Policy Deployment Script Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
