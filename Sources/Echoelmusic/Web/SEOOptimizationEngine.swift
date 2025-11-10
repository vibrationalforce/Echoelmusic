import Foundation

/// SEO Optimization Engine
/// Professional search engine optimization for maximum discoverability
///
/// Features:
/// - Meta tags optimization (Open Graph, Twitter Cards)
/// - Structured data (Schema.org, JSON-LD)
/// - Sitemap generation (XML, HTML)
/// - Performance optimization (Core Web Vitals)
/// - Multi-language SEO (hreflang)
/// - Rich snippets (Music, Video, Product)
/// - Analytics integration
@MainActor
class SEOOptimizationEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var seoScore: SEOScore
    @Published var recommendations: [SEORecommendation] = []

    // MARK: - SEO Score

    struct SEOScore {
        var overallScore: Int  // 0-100
        var technicalSEO: Int
        var contentSEO: Int
        var performanceSEO: Int
        var mobileSEO: Int

        var grade: String {
            switch overallScore {
            case 90...100: return "A+"
            case 80..<90: return "A"
            case 70..<80: return "B"
            case 60..<70: return "C"
            default: return "D"
            }
        }
    }

    struct SEORecommendation: Identifiable {
        let id = UUID()
        let category: Category
        let title: String
        let description: String
        let priority: Priority
        let impact: String

        enum Category {
            case technical, content, performance, mobile, social
        }

        enum Priority {
            case critical, high, medium, low

            var icon: String {
                switch self {
                case .critical: return "🔴"
                case .high: return "🟠"
                case .medium: return "🟡"
                case .low: return "🟢"
                }
            }
        }
    }

    // MARK: - Meta Tags

    struct MetaTags {
        // Basic Meta Tags
        var title: String
        var description: String
        var keywords: [String]
        var author: String
        var canonical: String

        // Open Graph (Facebook, LinkedIn)
        var ogTitle: String?
        var ogDescription: String?
        var ogImage: String?
        var ogType: String  // website, music.song, video.movie, article
        var ogUrl: String?
        var ogSiteName: String

        // Twitter Cards
        var twitterCard: TwitterCardType
        var twitterTitle: String?
        var twitterDescription: String?
        var twitterImage: String?
        var twitterCreator: String?

        // Music-Specific (Spotify, Apple Music)
        var musicDuration: Int?  // seconds
        var musicArtist: String?
        var musicAlbum: String?
        var musicReleaseDate: String?

        enum TwitterCardType: String {
            case summary = "summary"
            case summaryLargeImage = "summary_large_image"
            case player = "player"
            case app = "app"
        }

        func generateHTML() -> String {
            var html = """
            <!-- Basic Meta Tags -->
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            <meta name="description" content="\(description)">
            <meta name="keywords" content="\(keywords.joined(separator: ", "))">
            <meta name="author" content="\(author)">
            <link rel="canonical" href="\(canonical)">

            <!-- Open Graph Meta Tags -->
            <meta property="og:title" content="\(ogTitle ?? title)">
            <meta property="og:description" content="\(ogDescription ?? description)">
            <meta property="og:type" content="\(ogType)">
            <meta property="og:site_name" content="\(ogSiteName)">

            """

            if let ogImage = ogImage {
                html += """
                <meta property="og:image" content="\(ogImage)">
                <meta property="og:image:width" content="1200">
                <meta property="og:image:height" content="630">

                """
            }

            if let ogUrl = ogUrl {
                html += "<meta property=\"og:url\" content=\"\(ogUrl)\">\n"
            }

            // Music-specific Open Graph
            if ogType == "music.song", let artist = musicArtist {
                html += """
                <meta property="music:musician" content="\(artist)">

                """
                if let album = musicAlbum {
                    html += "<meta property=\"music:album\" content=\"\(album)\">\n"
                }
                if let duration = musicDuration {
                    html += "<meta property=\"music:duration\" content=\"\(duration)\">\n"
                }
                if let releaseDate = musicReleaseDate {
                    html += "<meta property=\"music:release_date\" content=\"\(releaseDate)\">\n"
                }
            }

            // Twitter Card Meta Tags
            html += """

            <!-- Twitter Card Meta Tags -->
            <meta name="twitter:card" content="\(twitterCard.rawValue)">
            <meta name="twitter:title" content="\(twitterTitle ?? title)">
            <meta name="twitter:description" content="\(twitterDescription ?? description)">

            """

            if let twitterImage = twitterImage {
                html += "<meta name=\"twitter:image\" content=\"\(twitterImage)\">\n"
            }

            if let twitterCreator = twitterCreator {
                html += "<meta name=\"twitter:creator\" content=\"@\(twitterCreator)\">\n"
            }

            return html
        }
    }

    // MARK: - Structured Data (Schema.org)

    struct StructuredData {
        var type: SchemaType
        var data: [String: Any]

        enum SchemaType: String {
            case musicRecording = "MusicRecording"
            case musicAlbum = "MusicAlbum"
            case videoObject = "VideoObject"
            case product = "Product"
            case person = "Person"
            case organization = "Organization"
            case article = "Article"
            case event = "Event"
        }

        func generateJSONLD() -> String {
            var jsonLD: [String: Any] = [
                "@context": "https://schema.org",
                "@type": type.rawValue
            ]

            for (key, value) in data {
                jsonLD[key] = value
            }

            guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonLD, options: .prettyPrinted),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return ""
            }

            return """
            <script type="application/ld+json">
            \(jsonString)
            </script>
            """
        }

        // Factory methods for common schemas

        static func musicRecording(
            name: String,
            artist: String,
            album: String? = nil,
            duration: String? = nil,  // ISO 8601 duration (PT3M45S)
            isrc: String? = nil,
            genre: String? = nil,
            recordingOf: String? = nil
        ) -> StructuredData {
            var data: [String: Any] = [
                "name": name,
                "byArtist": [
                    "@type": "MusicGroup",
                    "name": artist
                ]
            ]

            if let album = album {
                data["inAlbum"] = [
                    "@type": "MusicAlbum",
                    "name": album
                ]
            }

            if let duration = duration {
                data["duration"] = duration
            }

            if let isrc = isrc {
                data["isrcCode"] = isrc
            }

            if let genre = genre {
                data["genre"] = genre
            }

            if let recordingOf = recordingOf {
                data["recordingOf"] = [
                    "@type": "MusicComposition",
                    "name": recordingOf
                ]
            }

            return StructuredData(type: .musicRecording, data: data)
        }

        static func videoObject(
            name: String,
            description: String,
            thumbnailUrl: String,
            uploadDate: String,  // ISO 8601 (2025-01-10)
            duration: String,    // ISO 8601 (PT1H30M)
            contentUrl: String,
            embedUrl: String? = nil
        ) -> StructuredData {
            var data: [String: Any] = [
                "name": name,
                "description": description,
                "thumbnailUrl": thumbnailUrl,
                "uploadDate": uploadDate,
                "duration": duration,
                "contentUrl": contentUrl
            ]

            if let embedUrl = embedUrl {
                data["embedUrl"] = embedUrl
            }

            return StructuredData(type: .videoObject, data: data)
        }

        static func product(
            name: String,
            description: String,
            price: Double,
            currency: String,
            availability: String = "https://schema.org/InStock",
            brand: String? = nil,
            sku: String? = nil,
            image: String? = nil
        ) -> StructuredData {
            var data: [String: Any] = [
                "name": name,
                "description": description,
                "offers": [
                    "@type": "Offer",
                    "price": price,
                    "priceCurrency": currency,
                    "availability": availability
                ]
            ]

            if let brand = brand {
                data["brand"] = [
                    "@type": "Brand",
                    "name": brand
                ]
            }

            if let sku = sku {
                data["sku"] = sku
            }

            if let image = image {
                data["image"] = image
            }

            return StructuredData(type: .product, data: data)
        }
    }

    // MARK: - Sitemap Generation

    struct Sitemap {
        var urls: [URLEntry]

        struct URLEntry {
            let loc: String  // URL
            let lastmod: String?  // ISO 8601 date
            let changefreq: ChangeFrequency?
            let priority: Double?  // 0.0 - 1.0

            enum ChangeFrequency: String {
                case always, hourly, daily, weekly, monthly, yearly, never
            }
        }

        func generateXML() -> String {
            var xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">

            """

            for url in urls {
                xml += "  <url>\n"
                xml += "    <loc>\(url.loc)</loc>\n"

                if let lastmod = url.lastmod {
                    xml += "    <lastmod>\(lastmod)</lastmod>\n"
                }

                if let changefreq = url.changefreq {
                    xml += "    <changefreq>\(changefreq.rawValue)</changefreq>\n"
                }

                if let priority = url.priority {
                    xml += "    <priority>\(String(format: "%.1f", priority))</priority>\n"
                }

                xml += "  </url>\n"
            }

            xml += "</urlset>"

            return xml
        }

        func generateHTML() -> String {
            var html = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Sitemap - Echoelmusic</title>
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; padding: 20px; }
                    h1 { color: #1DB954; }
                    ul { list-style: none; padding: 0; }
                    li { margin: 10px 0; }
                    a { color: #1DB954; text-decoration: none; }
                    a:hover { text-decoration: underline; }
                </style>
            </head>
            <body>
                <h1>Sitemap</h1>
                <ul>

            """

            for url in urls {
                html += "        <li><a href=\"\(url.loc)\">\(url.loc)</a></li>\n"
            }

            html += """
                </ul>
            </body>
            </html>
            """

            return html
        }
    }

    // MARK: - Multi-Language Support

    struct HreflangTags {
        var alternates: [LanguageAlternate]

        struct LanguageAlternate {
            let lang: String  // en, de, fr, es, ja
            let url: String

            var hreflangCode: String {
                lang  // Can be extended to include region: en-US, en-GB, de-DE, de-AT
            }
        }

        func generateHTML() -> String {
            var html = "<!-- Hreflang Tags -->\n"

            for alternate in alternates {
                html += "<link rel=\"alternate\" hreflang=\"\(alternate.hreflangCode)\" href=\"\(alternate.url)\">\n"
            }

            // x-default for international/unknown users
            if let defaultURL = alternates.first?.url {
                html += "<link rel=\"alternate\" hreflang=\"x-default\" href=\"\(defaultURL)\">\n"
            }

            return html
        }
    }

    // MARK: - Performance Optimization

    struct PerformanceOptimization {
        var coreWebVitals: CoreWebVitals
        var optimizations: [Optimization]

        struct CoreWebVitals {
            var largestContentfulPaint: Double  // LCP (ms) - Target: <2.5s
            var firstInputDelay: Double         // FID (ms) - Target: <100ms
            var cumulativeLayoutShift: Double   // CLS - Target: <0.1
            var firstContentfulPaint: Double    // FCP (ms) - Target: <1.8s
            var timeToInteractive: Double       // TTI (ms) - Target: <3.8s

            var isGood: Bool {
                largestContentfulPaint < 2500 &&
                firstInputDelay < 100 &&
                cumulativeLayoutShift < 0.1
            }

            var grade: String {
                if isGood { return "Good 🟢" }
                if largestContentfulPaint < 4000 && firstInputDelay < 300 && cumulativeLayoutShift < 0.25 {
                    return "Needs Improvement 🟡"
                }
                return "Poor 🔴"
            }
        }

        struct Optimization {
            let title: String
            let description: String
            let technique: OptimizationTechnique

            enum OptimizationTechnique {
                case imageOptimization      // WebP, AVIF, lazy loading
                case codeMinification       // Minify JS/CSS
                case codeSplitting          // Dynamic imports
                case caching               // Service workers, CDN
                case compression           // Gzip, Brotli
                case criticalCSS           // Inline critical CSS
                case prefetching           // DNS prefetch, preconnect
                case http2Push             // HTTP/2 Server Push
            }
        }

        static func recommendations() -> [Optimization] {
            return [
                Optimization(
                    title: "Image Optimization",
                    description: "Use modern formats (WebP, AVIF) and lazy loading",
                    technique: .imageOptimization
                ),
                Optimization(
                    title: "Code Minification",
                    description: "Minify JavaScript and CSS files",
                    technique: .codeMinification
                ),
                Optimization(
                    title: "Code Splitting",
                    description: "Split code into chunks with dynamic imports",
                    technique: .codeSplitting
                ),
                Optimization(
                    title: "Browser Caching",
                    description: "Implement service workers and CDN caching",
                    technique: .caching
                ),
                Optimization(
                    title: "Compression",
                    description: "Enable Gzip/Brotli compression",
                    technique: .compression
                ),
                Optimization(
                    title: "Critical CSS",
                    description: "Inline critical CSS for above-the-fold content",
                    technique: .criticalCSS
                )
            ]
        }
    }

    // MARK: - Initialization

    init() {
        print("🔍 SEO Optimization Engine initialized")

        self.seoScore = SEOScore(
            overallScore: 0,
            technicalSEO: 0,
            contentSEO: 0,
            performanceSEO: 0,
            mobileSEO: 0
        )
    }

    // MARK: - SEO Analysis

    func analyzePage(url: String, content: PageContent) async -> SEOScore {
        print("🔍 Analyzing SEO for: \(url)")

        var technicalScore = 0
        var contentScore = 0
        var performanceScore = 0
        var mobileScore = 0

        recommendations = []

        // 1. Technical SEO
        technicalScore += analyzeTechnicalSEO(content: content)

        // 2. Content SEO
        contentScore += analyzeContentSEO(content: content)

        // 3. Performance SEO
        performanceScore += analyzePerformance(content: content)

        // 4. Mobile SEO
        mobileScore += analyzeMobileFriendliness(content: content)

        let overallScore = (technicalScore + contentScore + performanceScore + mobileScore) / 4

        let score = SEOScore(
            overallScore: overallScore,
            technicalSEO: technicalScore,
            contentSEO: contentScore,
            performanceSEO: performanceScore,
            mobileSEO: mobileScore
        )

        seoScore = score

        print("   ✅ SEO Analysis completed")
        print("      Overall Score: \(overallScore)/100 (Grade: \(score.grade))")
        print("      Technical: \(technicalScore)/100")
        print("      Content: \(contentScore)/100")
        print("      Performance: \(performanceScore)/100")
        print("      Mobile: \(mobileScore)/100")
        print("      Recommendations: \(recommendations.count)")

        return score
    }

    struct PageContent {
        var html: String
        var metaTags: MetaTags?
        var structuredData: [StructuredData]
        var images: [ImageInfo]
        var links: [LinkInfo]
        var headings: [HeadingInfo]

        struct ImageInfo {
            let src: String
            let alt: String?
            let width: Int?
            let height: Int?
        }

        struct LinkInfo {
            let href: String
            let text: String
            let isExternal: Bool
        }

        struct HeadingInfo {
            let level: Int  // 1-6 (h1-h6)
            let text: String
        }
    }

    private func analyzeTechnicalSEO(content: PageContent) -> Int {
        var score = 100

        // Check meta tags
        if content.metaTags == nil {
            score -= 30
            recommendations.append(SEORecommendation(
                category: .technical,
                title: "Missing Meta Tags",
                description: "Add title, description, and Open Graph tags",
                priority: .critical,
                impact: "Critical for search engines and social sharing"
            ))
        } else {
            // Check title length
            if let title = content.metaTags?.title, title.count > 60 {
                score -= 5
                recommendations.append(SEORecommendation(
                    category: .technical,
                    title: "Title Too Long",
                    description: "Keep title under 60 characters",
                    priority: .medium,
                    impact: "May be truncated in search results"
                ))
            }

            // Check description length
            if let desc = content.metaTags?.description, desc.count > 160 {
                score -= 5
                recommendations.append(SEORecommendation(
                    category: .technical,
                    title: "Description Too Long",
                    description: "Keep description under 160 characters",
                    priority: .medium,
                    impact: "May be truncated in search results"
                ))
            }
        }

        // Check structured data
        if content.structuredData.isEmpty {
            score -= 20
            recommendations.append(SEORecommendation(
                category: .technical,
                title: "Missing Structured Data",
                description: "Add Schema.org markup for rich snippets",
                priority: .high,
                impact: "Enables rich results in search"
            ))
        }

        // Check canonical URL
        if content.metaTags?.canonical.isEmpty != false {
            score -= 10
            recommendations.append(SEORecommendation(
                category: .technical,
                title: "Missing Canonical URL",
                description: "Add canonical link to prevent duplicate content",
                priority: .high,
                impact: "Prevents SEO dilution from duplicate content"
            ))
        }

        return max(0, score)
    }

    private func analyzeContentSEO(content: PageContent) -> Int {
        var score = 100

        // Check H1 tags
        let h1Count = content.headings.filter { $0.level == 1 }.count
        if h1Count == 0 {
            score -= 20
            recommendations.append(SEORecommendation(
                category: .content,
                title: "Missing H1 Tag",
                description: "Add one H1 tag per page",
                priority: .critical,
                impact: "H1 is crucial for page topic identification"
            ))
        } else if h1Count > 1 {
            score -= 10
            recommendations.append(SEORecommendation(
                category: .content,
                title: "Multiple H1 Tags",
                description: "Use only one H1 tag per page",
                priority: .medium,
                impact: "Can confuse search engines about page topic"
            ))
        }

        // Check image alt tags
        let imagesWithoutAlt = content.images.filter { $0.alt == nil || $0.alt?.isEmpty == true }
        if !imagesWithoutAlt.isEmpty {
            score -= 15
            recommendations.append(SEORecommendation(
                category: .content,
                title: "Missing Image Alt Text",
                description: "\(imagesWithoutAlt.count) images missing alt text",
                priority: .high,
                impact: "Affects accessibility and image search ranking"
            ))
        }

        // Check internal links
        let internalLinks = content.links.filter { !$0.isExternal }
        if internalLinks.count < 3 {
            score -= 10
            recommendations.append(SEORecommendation(
                category: .content,
                title: "Few Internal Links",
                description: "Add more internal links for better site structure",
                priority: .medium,
                impact: "Improves crawlability and user navigation"
            ))
        }

        return max(0, score)
    }

    private func analyzePerformance(content: PageContent) -> Int {
        var score = 100

        // Simulated performance checks
        // In production: Use Lighthouse API, PageSpeed Insights API

        recommendations.append(SEORecommendation(
            category: .performance,
            title: "Optimize Images",
            description: "Use WebP/AVIF and lazy loading",
            priority: .high,
            impact: "Improves LCP and overall page speed"
        ))

        recommendations.append(SEORecommendation(
            category: .performance,
            title: "Minify Resources",
            description: "Minify JavaScript and CSS files",
            priority: .medium,
            impact: "Reduces file size and load time"
        ))

        return score
    }

    private func analyzeMobileFriendliness(content: PageContent) -> Int {
        var score = 100

        // Check viewport meta tag
        if !content.html.contains("viewport") {
            score -= 30
            recommendations.append(SEORecommendation(
                category: .mobile,
                title: "Missing Viewport Meta Tag",
                description: "Add viewport meta tag for mobile responsiveness",
                priority: .critical,
                impact: "Page won't be mobile-friendly"
            ))
        }

        return max(0, score)
    }

    // MARK: - Generate Complete SEO Package

    func generateSEOPackage(for page: PageInfo) -> String {
        print("📦 Generating complete SEO package...")

        let metaTags = MetaTags(
            title: page.title,
            description: page.description,
            keywords: page.keywords,
            author: "Echoelmusic",
            canonical: page.url,
            ogTitle: page.title,
            ogDescription: page.description,
            ogImage: page.imageUrl,
            ogType: page.type,
            ogUrl: page.url,
            ogSiteName: "Echoelmusic",
            twitterCard: .summaryLargeImage,
            twitterTitle: page.title,
            twitterDescription: page.description,
            twitterImage: page.imageUrl,
            twitterCreator: page.creator,
            musicDuration: page.duration,
            musicArtist: page.artist,
            musicAlbum: page.album,
            musicReleaseDate: page.releaseDate
        )

        var html = metaTags.generateHTML()

        // Add structured data
        for schema in page.structuredData {
            html += "\n" + schema.generateJSONLD()
        }

        // Add hreflang tags
        if !page.languageAlternates.isEmpty {
            let hreflang = HreflangTags(alternates: page.languageAlternates)
            html += "\n" + hreflang.generateHTML()
        }

        print("   ✅ SEO package generated")

        return html
    }

    struct PageInfo {
        let title: String
        let description: String
        let keywords: [String]
        let url: String
        let imageUrl: String?
        let type: String  // website, music.song, video.movie
        let creator: String?
        let duration: Int?
        let artist: String?
        let album: String?
        let releaseDate: String?
        let structuredData: [StructuredData]
        let languageAlternates: [HreflangTags.LanguageAlternate]
    }
}
