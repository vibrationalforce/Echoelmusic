import Foundation

/// Website Builder
/// Professional website generation for artists, creators, and businesses
///
/// Features:
/// - Landing pages (product launch, music release, portfolio)
/// - Artist/Creator profiles
/// - E-commerce product pages
/// - Blog/News section
/// - Media gallery (audio, video, images)
/// - Contact forms
/// - SEO optimization (integrated)
/// - Analytics integration
/// - Responsive design (mobile-first)
@MainActor
class WebsiteBuilder: ObservableObject {

    // MARK: - Published Properties

    @Published var websites: [Website] = []
    @Published var templates: [WebsiteTemplate] = []

    // MARK: - Engines

    private let seoEngine: SEOOptimizationEngine
    private let paymentEngine: PaymentGatewayEngine

    // MARK: - Website

    struct Website: Identifiable {
        let id = UUID()
        var title: String
        var domain: String
        var template: WebsiteTemplate
        var pages: [Page]
        var theme: Theme
        var seoSettings: SEOSettings
        var analyticsSettings: AnalyticsSettings
        var isPublished: Bool
        var publishedAt: Date?

        struct SEOSettings {
            var siteName: String
            var defaultDescription: String
            var defaultKeywords: [String]
            var favicon: String?
            var socialImage: String?
        }

        struct AnalyticsSettings {
            var googleAnalyticsId: String?
            var facebookPixelId: String?
            var plausibleDomain: String?
        }
    }

    // MARK: - Website Template

    enum WebsiteTemplate: String, CaseIterable {
        case artistPortfolio = "Artist Portfolio"
        case musicRelease = "Music Release"
        case productLaunch = "Product Launch"
        case ecommerce = "E-Commerce Store"
        case blog = "Blog/Magazine"
        case landingPage = "Landing Page"
        case onePage = "One Page Site"

        var description: String {
            switch self {
            case .artistPortfolio:
                return "Showcase your work with a beautiful portfolio"
            case .musicRelease:
                return "Promote your latest music release"
            case .productLaunch:
                return "Launch your product with impact"
            case .ecommerce:
                return "Sell products and services online"
            case .blog:
                return "Share your thoughts and stories"
            case .landingPage:
                return "Convert visitors into customers"
            case .onePage:
                return "Everything on one scrolling page"
            }
        }

        var defaultPages: [PageType] {
            switch self {
            case .artistPortfolio:
                return [.home, .about, .portfolio, .contact]
            case .musicRelease:
                return [.home, .music, .videos, .tour, .shop]
            case .productLaunch:
                return [.home, .features, .pricing, .contact]
            case .ecommerce:
                return [.home, .shop, .product, .cart, .checkout]
            case .blog:
                return [.home, .blog, .about, .contact]
            case .landingPage:
                return [.home]
            case .onePage:
                return [.home]
            }
        }
    }

    // MARK: - Page

    struct Page: Identifiable {
        let id = UUID()
        var type: PageType
        var title: String
        var slug: String
        var sections: [Section]
        var seo: PageSEO

        enum PageType {
            case home, about, portfolio, music, videos, tour, shop
            case product, cart, checkout, blog, post, contact, features, pricing
        }

        struct PageSEO {
            var title: String
            var description: String
            var keywords: [String]
            var ogImage: String?
        }
    }

    // MARK: - Section

    struct Section: Identifiable {
        let id = UUID()
        var type: SectionType
        var content: SectionContent
        var style: SectionStyle

        enum SectionType {
            case hero               // Hero banner
            case features          // Feature grid
            case gallery           // Image/video gallery
            case musicPlayer       // Music player
            case videoPlayer       // Video player
            case text              // Text content
            case callToAction      // CTA button
            case contactForm       // Contact form
            case pricing           // Pricing table
            case testimonials      // Customer reviews
            case team              // Team members
            case stats             // Statistics
            case newsletter        // Email signup
            case socialLinks       // Social media links
        }

        struct SectionContent {
            var heading: String?
            var subheading: String?
            var text: String?
            var image: String?
            var video: String?
            var items: [[String: String]]?  // Flexible data structure
            var ctaText: String?
            var ctaLink: String?
        }

        struct SectionStyle {
            var backgroundColor: String
            var textColor: String
            var padding: Padding
            var alignment: Alignment

            enum Padding {
                case none, small, medium, large
            }

            enum Alignment {
                case left, center, right
            }
        }
    }

    // MARK: - Theme

    struct Theme {
        var name: String
        var primaryColor: String
        var secondaryColor: String
        var accentColor: String
        var backgroundColor: String
        var textColor: String
        var fontFamily: FontFamily

        enum FontFamily: String {
            case inter = "Inter"
            case roboto = "Roboto"
            case openSans = "Open Sans"
            case lato = "Lato"
            case montserrat = "Montserrat"
            case playfair = "Playfair Display"
        }

        static let defaultTheme = Theme(
            name: "Default",
            primaryColor: "#1DB954",  // Spotify green
            secondaryColor: "#191414",
            accentColor: "#FF6B6B",
            backgroundColor: "#FFFFFF",
            textColor: "#191414",
            fontFamily: .inter
        )

        static let darkTheme = Theme(
            name: "Dark",
            primaryColor: "#1DB954",
            secondaryColor: "#191414",
            accentColor: "#FF6B6B",
            backgroundColor: "#121212",
            textColor: "#FFFFFF",
            fontFamily: .inter
        )
    }

    // MARK: - Initialization

    init() {
        print("🌐 Website Builder initialized")

        self.seoEngine = SEOOptimizationEngine()
        self.paymentEngine = PaymentGatewayEngine()

        // Load templates
        self.templates = WebsiteTemplate.allCases.map { template in
            template
        }

        print("   ✅ \(templates.count) templates available")
    }

    // MARK: - Create Website

    func createWebsite(
        title: String,
        domain: String,
        template: WebsiteTemplate,
        theme: Theme = .defaultTheme
    ) -> Website {
        print("🌐 Creating website...")
        print("   Title: \(title)")
        print("   Domain: \(domain)")
        print("   Template: \(template.rawValue)")

        // Create pages based on template
        let pages = template.defaultPages.map { pageType in
            createPage(type: pageType, template: template)
        }

        let website = Website(
            title: title,
            domain: domain,
            template: template,
            pages: pages,
            theme: theme,
            seoSettings: Website.SEOSettings(
                siteName: title,
                defaultDescription: "Official website of \(title)",
                defaultKeywords: [],
                favicon: nil,
                socialImage: nil
            ),
            analyticsSettings: Website.AnalyticsSettings(
                googleAnalyticsId: nil,
                facebookPixelId: nil,
                plausibleDomain: nil
            ),
            isPublished: false
        )

        websites.append(website)

        print("   ✅ Website created with \(pages.count) pages")

        return website
    }

    private func createPage(type: Page.PageType, template: WebsiteTemplate) -> Page {
        let sections = createDefaultSections(for: type, template: template)

        let title = getPageTitle(for: type)

        return Page(
            type: type,
            title: title,
            slug: getPageSlug(for: type),
            sections: sections,
            seo: Page.PageSEO(
                title: title,
                description: "Learn more about \(title.lowercased())",
                keywords: [],
                ogImage: nil
            )
        )
    }

    private func getPageTitle(for type: Page.PageType) -> String {
        switch type {
        case .home: return "Home"
        case .about: return "About"
        case .portfolio: return "Portfolio"
        case .music: return "Music"
        case .videos: return "Videos"
        case .tour: return "Tour"
        case .shop: return "Shop"
        case .product: return "Product"
        case .cart: return "Cart"
        case .checkout: return "Checkout"
        case .blog: return "Blog"
        case .post: return "Post"
        case .contact: return "Contact"
        case .features: return "Features"
        case .pricing: return "Pricing"
        }
    }

    private func getPageSlug(for type: Page.PageType) -> String {
        switch type {
        case .home: return "/"
        case .about: return "/about"
        case .portfolio: return "/portfolio"
        case .music: return "/music"
        case .videos: return "/videos"
        case .tour: return "/tour"
        case .shop: return "/shop"
        case .product: return "/product"
        case .cart: return "/cart"
        case .checkout: return "/checkout"
        case .blog: return "/blog"
        case .post: return "/post"
        case .contact: return "/contact"
        case .features: return "/features"
        case .pricing: return "/pricing"
        }
    }

    private func createDefaultSections(for pageType: Page.PageType, template: WebsiteTemplate) -> [Section] {
        switch pageType {
        case .home:
            return createHomeSections(template: template)
        case .about:
            return createAboutSections()
        case .music:
            return createMusicSections()
        case .shop:
            return createShopSections()
        case .contact:
            return createContactSections()
        case .pricing:
            return createPricingSections()
        default:
            return []
        }
    }

    private func createHomeSections(template: WebsiteTemplate) -> [Section] {
        var sections: [Section] = []

        // Hero section
        sections.append(Section(
            type: .hero,
            content: Section.SectionContent(
                heading: "Welcome to Echoelmusic",
                subheading: "With your sound it feels better!",
                text: "Professional music production, spatial audio, and immersive experiences",
                image: "/images/hero.jpg",
                ctaText: "Get Started",
                ctaLink: "/signup"
            ),
            style: Section.SectionStyle(
                backgroundColor: "#1DB954",
                textColor: "#FFFFFF",
                padding: .large,
                alignment: .center
            )
        ))

        // Features section
        if template == .productLaunch || template == .landingPage {
            sections.append(Section(
                type: .features,
                content: Section.SectionContent(
                    heading: "Features",
                    subheading: "Everything you need to create amazing music",
                    items: [
                        ["title": "Spatial Audio", "description": "Dolby Atmos, Ambisonics, Sony 360RA", "icon": "🔊"],
                        ["title": "4K/8K Video", "description": "Professional video editing and streaming", "icon": "🎬"],
                        ["title": "Distribution", "description": "Distribute to all major platforms", "icon": "🌍"]
                    ]
                ),
                style: Section.SectionStyle(
                    backgroundColor: "#FFFFFF",
                    textColor: "#191414",
                    padding: .large,
                    alignment: .center
                )
            ))
        }

        // CTA section
        sections.append(Section(
            type: .callToAction,
            content: Section.SectionContent(
                heading: "Ready to get started?",
                text: "Join thousands of creators using Echoelmusic",
                ctaText: "Start Free Trial",
                ctaLink: "/signup"
            ),
            style: Section.SectionStyle(
                backgroundColor: "#191414",
                textColor: "#FFFFFF",
                padding: .large,
                alignment: .center
            )
        ))

        return sections
    }

    private func createAboutSections() -> [Section] {
        return [
            Section(
                type: .text,
                content: Section.SectionContent(
                    heading: "About Us",
                    text: """
                    Echoelmusic is the professional creative platform for musicians,
                    producers, and content creators worldwide.

                    Our mission is to provide the best tools for creativity, without
                    the need for expensive teams or staff.
                    """
                ),
                style: Section.SectionStyle(
                    backgroundColor: "#FFFFFF",
                    textColor: "#191414",
                    padding: .large,
                    alignment: .left
                )
            )
        ]
    }

    private func createMusicSections() -> [Section] {
        return [
            Section(
                type: .musicPlayer,
                content: Section.SectionContent(
                    heading: "Latest Releases",
                    items: [
                        ["title": "Song Title", "artist": "Artist Name", "duration": "3:45"],
                    ]
                ),
                style: Section.SectionStyle(
                    backgroundColor: "#FFFFFF",
                    textColor: "#191414",
                    padding: .medium,
                    alignment: .left
                )
            )
        ]
    }

    private func createShopSections() -> [Section] {
        return [
            Section(
                type: .gallery,
                content: Section.SectionContent(
                    heading: "Products",
                    items: [
                        ["name": "Product 1", "price": "$29.99", "image": "/images/product1.jpg"],
                    ]
                ),
                style: Section.SectionStyle(
                    backgroundColor: "#FFFFFF",
                    textColor: "#191414",
                    padding: .medium,
                    alignment: .left
                )
            )
        ]
    }

    private func createContactSections() -> [Section] {
        return [
            Section(
                type: .contactForm,
                content: Section.SectionContent(
                    heading: "Get in Touch",
                    text: "Send us a message and we'll get back to you as soon as possible"
                ),
                style: Section.SectionStyle(
                    backgroundColor: "#FFFFFF",
                    textColor: "#191414",
                    padding: .large,
                    alignment: .center
                )
            )
        ]
    }

    private func createPricingSections() -> [Section] {
        return [
            Section(
                type: .pricing,
                content: Section.SectionContent(
                    heading: "Choose Your Plan",
                    items: [
                        ["name": "Free", "price": "$0", "features": "Basic features"],
                        ["name": "Pro", "price": "$29.99", "features": "All features"],
                    ]
                ),
                style: Section.SectionStyle(
                    backgroundColor: "#F8F9FA",
                    textColor: "#191414",
                    padding: .large,
                    alignment: .center
                )
            )
        ]
    }

    // MARK: - Generate HTML

    func generateHTML(for website: Website) -> String {
        print("📝 Generating HTML for website: \(website.title)")

        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">

        """

        // Add SEO meta tags
        let seoTags = generateSEOTags(for: website)
        html += seoTags

        // Add theme CSS
        html += """
            <style>
                :root {
                    --primary-color: \(website.theme.primaryColor);
                    --secondary-color: \(website.theme.secondaryColor);
                    --accent-color: \(website.theme.accentColor);
                    --bg-color: \(website.theme.backgroundColor);
                    --text-color: \(website.theme.textColor);
                    --font-family: '\(website.theme.fontFamily.rawValue)', sans-serif;
                }

                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }

                body {
                    font-family: var(--font-family);
                    background-color: var(--bg-color);
                    color: var(--text-color);
                    line-height: 1.6;
                }

                /* Section styles */
                section {
                    padding: 80px 20px;
                }

                .container {
                    max-width: 1200px;
                    margin: 0 auto;
                }

                h1 { font-size: 3rem; margin-bottom: 1rem; }
                h2 { font-size: 2.5rem; margin-bottom: 1rem; }
                h3 { font-size: 2rem; margin-bottom: 0.5rem; }

                .btn {
                    display: inline-block;
                    padding: 15px 30px;
                    background-color: var(--primary-color);
                    color: white;
                    text-decoration: none;
                    border-radius: 5px;
                    font-weight: bold;
                    transition: transform 0.2s;
                }

                .btn:hover {
                    transform: translateY(-2px);
                }

                /* Responsive */
                @media (max-width: 768px) {
                    h1 { font-size: 2rem; }
                    h2 { font-size: 1.5rem; }
                    section { padding: 40px 15px; }
                }
            </style>
        </head>
        <body>

        """

        // Add navigation
        html += generateNavigation(for: website)

        // Add page content
        for page in website.pages where page.type == .home {
            for section in page.sections {
                html += generateSection(section)
            }
        }

        // Add footer
        html += generateFooter(for: website)

        // Add analytics
        if let gaId = website.analyticsSettings.googleAnalyticsId {
            html += """

            <!-- Google Analytics -->
            <script async src="https://www.googletagmanager.com/gtag/js?id=\(gaId)"></script>
            <script>
                window.dataLayer = window.dataLayer || [];
                function gtag(){dataLayer.push(arguments);}
                gtag('js', new Date());
                gtag('config', '\(gaId)');
            </script>

            """
        }

        html += """
        </body>
        </html>
        """

        print("   ✅ HTML generated")

        return html
    }

    private func generateSEOTags(for website: Website) -> String {
        let pageInfo = SEOOptimizationEngine.PageInfo(
            title: website.title,
            description: website.seoSettings.defaultDescription,
            keywords: website.seoSettings.defaultKeywords,
            url: "https://\(website.domain)",
            imageUrl: website.seoSettings.socialImage,
            type: "website",
            creator: nil,
            duration: nil,
            artist: nil,
            album: nil,
            releaseDate: nil,
            structuredData: [],
            languageAlternates: []
        )

        return seoEngine.generateSEOPackage(for: pageInfo)
    }

    private func generateNavigation(for website: Website) -> String {
        var nav = """
        <nav style="background: var(--secondary-color); padding: 20px 0;">
            <div class="container" style="display: flex; justify-content: space-between; align-items: center;">
                <div style="color: white; font-size: 1.5rem; font-weight: bold;">\(website.title)</div>
                <ul style="list-style: none; display: flex; gap: 20px;">

        """

        for page in website.pages {
            nav += """
                    <li><a href="\(page.slug)" style="color: white; text-decoration: none;">\(page.title)</a></li>

            """
        }

        nav += """
                </ul>
            </div>
        </nav>

        """

        return nav
    }

    private func generateSection(_ section: Section) -> String {
        let bgColor = section.style.backgroundColor
        let textColor = section.style.textColor

        switch section.type {
        case .hero:
            return """
            <section style="background: \(bgColor); color: \(textColor); text-align: center; padding: 120px 20px;">
                <div class="container">
                    <h1>\(section.content.heading ?? "")</h1>
                    <p style="font-size: 1.5rem; margin-bottom: 2rem;">\(section.content.subheading ?? "")</p>
                    <a href="\(section.content.ctaLink ?? "#")" class="btn">\(section.content.ctaText ?? "Learn More")</a>
                </div>
            </section>

            """

        case .features:
            var html = """
            <section style="background: \(bgColor); color: \(textColor);">
                <div class="container">
                    <h2 style="text-align: center; margin-bottom: 3rem;">\(section.content.heading ?? "")</h2>
                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2rem;">

            """

            if let items = section.content.items {
                for item in items {
                    html += """
                        <div style="text-align: center; padding: 2rem;">
                            <div style="font-size: 3rem; margin-bottom: 1rem;">\(item["icon"] ?? "")</div>
                            <h3>\(item["title"] ?? "")</h3>
                            <p>\(item["description"] ?? "")</p>
                        </div>

                    """
                }
            }

            html += """
                    </div>
                </div>
            </section>

            """
            return html

        case .callToAction:
            return """
            <section style="background: \(bgColor); color: \(textColor); text-align: center;">
                <div class="container">
                    <h2>\(section.content.heading ?? "")</h2>
                    <p style="font-size: 1.2rem; margin-bottom: 2rem;">\(section.content.text ?? "")</p>
                    <a href="\(section.content.ctaLink ?? "#")" class="btn">\(section.content.ctaText ?? "Get Started")</a>
                </div>
            </section>

            """

        default:
            return ""
        }
    }

    private func generateFooter(for website: Website) -> String {
        let year = Calendar.current.component(.year, from: Date())

        return """
        <footer style="background: var(--secondary-color); color: white; padding: 40px 20px; text-align: center;">
            <div class="container">
                <p>&copy; \(year) \(website.title). All rights reserved.</p>
                <p style="margin-top: 1rem;">Built with Echoelmusic 🎵</p>
            </div>
        </footer>

        """
    }

    // MARK: - Publish Website

    func publishWebsite(_ websiteId: UUID) async -> Bool {
        guard let index = websites.firstIndex(where: { $0.id == websiteId }) else {
            print("❌ Website not found")
            return false
        }

        print("🚀 Publishing website: \(websites[index].title)")
        print("   Domain: \(websites[index].domain)")

        // Generate HTML
        let html = generateHTML(for: websites[index])

        // Generate sitemap
        let sitemap = generateSitemap(for: websites[index])

        // In production: Upload to hosting (Vercel, Netlify, AWS S3, etc.)
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        websites[index].isPublished = true
        websites[index].publishedAt = Date()

        print("   ✅ Website published")
        print("   🌐 Live at: https://\(websites[index].domain)")

        return true
    }

    private func generateSitemap(for website: Website) -> SEOOptimizationEngine.Sitemap {
        let urls = website.pages.map { page in
            SEOOptimizationEngine.Sitemap.URLEntry(
                loc: "https://\(website.domain)\(page.slug)",
                lastmod: ISO8601DateFormatter().string(from: Date()),
                changefreq: .weekly,
                priority: page.type == .home ? 1.0 : 0.8
            )
        }

        return SEOOptimizationEngine.Sitemap(urls: urls)
    }
}
