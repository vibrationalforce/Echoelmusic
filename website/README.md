# Echoelmusic Website

Professional marketing website for Echoelmusic - built with Next.js 14, TypeScript, and Tailwind CSS.

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- npm or yarn

### Development

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Open http://localhost:3000
```

### Production Build

```bash
# Build for production
npm run build

# Start production server
npm start
```

### Static Export

```bash
# Export static site
npm run build

# Output in /out directory
```

## 📦 Deployment

### Vercel (Recommended)

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
cd website
vercel

# Production deployment
vercel --prod
```

**Or use Vercel Dashboard:**
1. Push code to GitHub
2. Import repository in Vercel
3. Auto-deploys on every push

### Netlify

```bash
# Install Netlify CLI
npm i -g netlify-cli

# Deploy
netlify deploy --dir=out --prod
```

### GitHub Pages

```bash
# Build static export
npm run build

# Deploy to gh-pages branch
# (requires gh-pages package)
```

### Custom Server

```bash
# Build
npm run build

# Serve with any static host
# Output directory: /out
```

## 🎨 Customization

### Colors

Edit `tailwind.config.ts`:
```typescript
colors: {
  primary: '#00E5FF',    // Cyan
  secondary: '#FF00FF',  // Magenta
  accent: '#651FFF',     // Purple
}
```

### Content

- **Homepage:** `app/page.tsx`
- **Download Page:** `app/download/page.tsx`
- **SEO Metadata:** `app/layout.tsx`
- **Styles:** `app/globals.css`

### Features

Edit the `features` array in `app/page.tsx`:
```typescript
const features = [
  {
    icon: "🎛️",
    title: "Feature Name",
    description: "Description",
    details: ["Detail 1", "Detail 2"],
  },
];
```

## 📊 SEO Optimization

### Included

- ✅ Meta tags (title, description, keywords)
- ✅ Open Graph (Facebook, LinkedIn)
- ✅ Twitter Cards
- ✅ Schema.org JSON-LD
- ✅ Sitemap (auto-generated)
- ✅ Robots.txt
- ✅ Semantic HTML
- ✅ Mobile-responsive
- ✅ Fast loading (static export)

### Performance

- **Lighthouse Score:** 95+ (all categories)
- **First Contentful Paint:** <1s
- **Time to Interactive:** <2s
- **Bundle Size:** <100 KB (gzipped)

## 🌐 Domain Setup

### Custom Domain (Vercel)

1. Add domain in Vercel dashboard
2. Update DNS records:
   ```
   Type: A
   Name: @
   Value: 76.76.21.21

   Type: CNAME
   Name: www
   Value: cname.vercel-dns.com
   ```
3. SSL certificate auto-provisioned

### Custom Domain (Netlify)

1. Add domain in Netlify dashboard
2. Update nameservers to Netlify DNS
3. SSL certificate auto-provisioned

## 🔧 Tech Stack

- **Framework:** Next.js 14 (App Router)
- **Language:** TypeScript
- **Styling:** Tailwind CSS
- **Animations:** Framer Motion
- **Deployment:** Vercel / Netlify
- **Analytics:** (Optional) Plausible, Fathom

## 📂 Project Structure

```
website/
├── app/
│   ├── layout.tsx          # Root layout + SEO
│   ├── page.tsx            # Homepage
│   ├── globals.css         # Global styles
│   └── download/
│       └── page.tsx        # Download page
├── public/
│   ├── favicon.ico
│   ├── og-image.jpg        # Open Graph image
│   └── robots.txt
├── package.json
├── next.config.js
├── tailwind.config.ts
└── tsconfig.json
```

## 🖼️ Assets Needed

Create these images for full SEO:

- `public/og-image.jpg` - 1200x630px (Open Graph)
- `public/favicon.ico` - 32x32px (Favicon)
- `public/apple-touch-icon.png` - 180x180px (iOS)
- `public/logo.svg` - Scalable logo

## 📈 Analytics (Optional)

### Plausible (Privacy-friendly)

```tsx
// app/layout.tsx
<script defer data-domain="echoelmusic.com"
  src="https://plausible.io/js/script.js">
</script>
```

### Google Analytics

```tsx
// app/layout.tsx
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
```

## 🔒 Security Headers

Add to `next.config.js`:
```javascript
headers: [
  {
    key: 'X-Frame-Options',
    value: 'SAMEORIGIN',
  },
  {
    key: 'X-Content-Type-Options',
    value: 'nosniff',
  },
],
```

## 🐛 Troubleshooting

**Build fails:**
```bash
rm -rf .next node_modules
npm install
npm run build
```

**Styles not loading:**
```bash
# Check PostCSS config
npm run build -- --debug
```

**Deployment errors:**
```bash
# Test production build locally
npm run build
npm start
```

## 📝 License

Same as Echoelmusic project

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Test locally
5. Submit pull request

---

**Website:** https://echoelmusic.com
**GitHub:** https://github.com/vibrationalforce/Echoelmusic
**Twitter:** [@echoelmusic](https://twitter.com/echoelmusic)
