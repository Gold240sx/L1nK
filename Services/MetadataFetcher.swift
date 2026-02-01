import Foundation
import SwiftSoup

/// Metadata extracted from a webpage
struct LinkMetadata {
    let url: String
    let domain: String
    let title: String
    let description: String?
    let faviconURLs: [String]
    
    /// Create from URL with default values
    static func placeholder(for urlString: String) -> LinkMetadata {
        let url = URL(string: urlString)
        let domain = url?.host ?? urlString
        return LinkMetadata(
            url: urlString,
            domain: domain,
            title: domain,
            description: nil,
            faviconURLs: []
        )
    }
}

/// Fetches and parses webpage metadata using SwiftSoup
@MainActor
class MetadataFetcher: ObservableObject {
    static let shared = MetadataFetcher()
    
    // MARK: - Properties
    
    /// Cache of fetched metadata
    private var cache: [String: LinkMetadata] = [:]
    
    /// Timeout for fetching pages
    private let timeout: TimeInterval = 10
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Fetch metadata for a URL
    func fetch(for urlString: String) async -> LinkMetadata {
        // Check cache first
        if let cached = cache[urlString] {
            return cached
        }
        
        // Validate URL
        guard let url = URL(string: urlString),
              let host = url.host else {
            return LinkMetadata.placeholder(for: urlString)
        }
        
        // Skip local/private hosts
        if isLocalHost(host) {
            return LinkMetadata.placeholder(for: urlString)
        }
        
        // Fetch and parse
        do {
            let metadata = try await fetchMetadata(from: url)
            cache[urlString] = metadata
            return metadata
        } catch {
            return LinkMetadata.placeholder(for: urlString)
        }
    }
    
    /// Check if host is a local/private address that shouldn't be fetched
    private func isLocalHost(_ host: String) -> Bool {
        let lowercased = host.lowercased()
        
        // Localhost variations
        if lowercased == "localhost" || lowercased == "127.0.0.1" || lowercased == "::1" {
            return true
        }
        
        // Local network ranges
        if lowercased.hasPrefix("192.168.") || lowercased.hasPrefix("10.") {
            return true
        }
        
        // 172.16.0.0 - 172.31.255.255
        if lowercased.hasPrefix("172.") {
            let parts = lowercased.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]), second >= 16 && second <= 31 {
                return true
            }
        }
        
        // No TLD (likely a local hostname)
        if !lowercased.contains(".") {
            return true
        }
        
        // IP addresses without proper domains
        let ipPattern = #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#
        if lowercased.range(of: ipPattern, options: .regularExpression) != nil {
            return true
        }
        
        return false
    }
    
    /// Clear the cache
    func clearCache() {
        cache.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// Fetch and parse metadata from URL
    private func fetchMetadata(from url: URL) async throws -> LinkMetadata {
        // Configure request
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        // Fetch HTML
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw MetadataError.invalidResponse
        }
        
        // Parse with SwiftSoup
        let document = try SwiftSoup.parse(html)
        
        // Extract domain
        let domain = extractDomain(from: url.host ?? url.absoluteString)
        
        // Extract title
        let title = try extractTitle(from: document) ?? domain
        
        // Extract description
        let description = try extractDescription(from: document)
        
        // Extract favicon URLs
        let faviconURLs = try extractFaviconURLs(from: document, baseURL: url)
        
        return LinkMetadata(
            url: url.absoluteString,
            domain: domain,
            title: title,
            description: description,
            faviconURLs: faviconURLs
        )
    }
    
    /// Extract domain from host
    private func extractDomain(from host: String) -> String {
        var domain = host.lowercased()
        if domain.hasPrefix("www.") {
            domain = String(domain.dropFirst(4))
        }
        return domain
    }
    
    /// Extract page title
    private func extractTitle(from document: Document) throws -> String? {
        // Try Open Graph title first
        if let ogTitle = try document.select("meta[property=og:title]").first()?.attr("content"),
           !ogTitle.isEmpty {
            return ogTitle
        }
        
        // Try Twitter title
        if let twitterTitle = try document.select("meta[name=twitter:title]").first()?.attr("content"),
           !twitterTitle.isEmpty {
            return twitterTitle
        }
        
        // Fall back to regular title tag
        let title = try document.title()
        if !title.isEmpty {
            return title
        }
        
        return nil
    }
    
    /// Extract page description
    private func extractDescription(from document: Document) throws -> String? {
        // Try Open Graph description first
        if let ogDesc = try document.select("meta[property=og:description]").first()?.attr("content"),
           !ogDesc.isEmpty {
            return ogDesc
        }
        
        // Try Twitter description
        if let twitterDesc = try document.select("meta[name=twitter:description]").first()?.attr("content"),
           !twitterDesc.isEmpty {
            return twitterDesc
        }
        
        // Try standard meta description
        if let metaDesc = try document.select("meta[name=description]").first()?.attr("content"),
           !metaDesc.isEmpty {
            return metaDesc
        }
        
        return nil
    }
    
    /// Extract favicon URLs from page
    private func extractFaviconURLs(from document: Document, baseURL: URL) throws -> [String] {
        var faviconURLs: [String] = []
        
        // Look for link tags with favicon references
        let selectors = [
            "link[rel=icon]",
            "link[rel=shortcut icon]",
            "link[rel=apple-touch-icon]",
            "link[rel=apple-touch-icon-precomposed]"
        ]
        
        for selector in selectors {
            let elements = try document.select(selector)
            for element in elements {
                if let href = try? element.attr("href"), !href.isEmpty {
                    // Resolve relative URLs
                    if let absoluteURL = resolveURL(href, relativeTo: baseURL) {
                        faviconURLs.append(absoluteURL)
                    }
                }
            }
        }
        
        // Add default favicon.ico location
        if let defaultFavicon = URL(string: "/favicon.ico", relativeTo: baseURL)?.absoluteString {
            faviconURLs.append(defaultFavicon)
        }
        
        return faviconURLs
    }
    
    /// Resolve a potentially relative URL
    private func resolveURL(_ href: String, relativeTo baseURL: URL) -> String? {
        // Already absolute
        if href.hasPrefix("http://") || href.hasPrefix("https://") {
            return href
        }
        
        // Protocol-relative
        if href.hasPrefix("//") {
            return "https:" + href
        }
        
        // Relative to root
        if href.hasPrefix("/") {
            guard let scheme = baseURL.scheme,
                  let host = baseURL.host else {
                return nil
            }
            return "\(scheme)://\(host)\(href)"
        }
        
        // Relative to current path
        return baseURL.deletingLastPathComponent()
            .appendingPathComponent(href)
            .absoluteString
    }
}

// MARK: - Errors

enum MetadataError: Error {
    case invalidURL
    case invalidResponse
    case parsingFailed
}
