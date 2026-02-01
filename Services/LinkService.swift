import Foundation
import AppKit
import UniformTypeIdentifiers
import LinkPresentation

class LinkService {
    static let shared = LinkService()
    
    private init() {}
    
    // MARK: - URL Cleaning
    
    /// Clean tracking parameters from URLs
    func cleanURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        
        // List of common tracking parameters to remove
        let trackingParams = Set([
            "_trkparms", "_trksid", "amclksrc", "aid", "algo", "ao", "asc",
            "meid", "pid", "rk", "rkt", "itm", "pmt", "noa", "pg", "algv",
            "brand", "pd_rd_w", "content-id", "pf_rd_p", "pf_rd_r", "pd_rd_wg",
            "pd_rd_r", "pd_rd_i", "ref", "ref_", "source", "utm_source",
            "utm_medium", "utm_campaign", "utm_term", "utm_content", "fbclid",
            "gclid", "msclkid", "tag", "linkCode", "camp", "creative"
        ])
        
        // Filter out tracking parameters
        if let queryItems = components.queryItems {
            let filteredItems = queryItems.filter { item in
                !trackingParams.contains(item.name.lowercased())
            }
            components.queryItems = filteredItems.isEmpty ? nil : filteredItems
        }
        
        return components.url ?? url
    }
    
    /// Extract YouTube video ID from URL
    private func extractYouTubeVideoId(from url: URL) -> String? {
        // Handle youtu.be/VIDEO_ID
        if url.host?.contains("youtu.be") == true {
            let videoId = url.pathComponents.last
            if let id = videoId, !id.isEmpty && id != "/" {
                return id
            }
        }
        
        // Handle youtube.com/watch?v=VIDEO_ID
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return videoId
        }
        
        // Handle youtube.com/embed/VIDEO_ID or youtube.com/v/VIDEO_ID
        let pathComponents = url.pathComponents
        for (index, component) in pathComponents.enumerated() {
            if (component == "embed" || component == "v") && index + 1 < pathComponents.count {
                return pathComponents[index + 1]
            }
        }
        
        return nil
    }
    
    /// Extract the essential item ID from eBay URLs
    func extractEbayItemId(from url: URL) -> String? {
        // eBay URLs: /itm/406469006898 or /itm/product-name/406469006898
        let components = url.pathComponents
        for (index, component) in components.enumerated() {
            if component == "itm" {
                // Look for numeric ID in subsequent components
                for i in (index + 1)..<components.count {
                    let part = components[i]
                    // Item IDs are typically 12-digit numbers
                    if part.allSatisfy({ $0.isNumber }) && part.count >= 10 {
                        return part
                    }
                }
            }
        }
        
        // Also check query parameter
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let itemParam = components.queryItems?.first(where: { $0.name == "itm" })?.value {
            return itemParam
        }
        
        return nil
    }
    
    // MARK: - URL Detection
    
    func isYouTube(url: URL) -> Bool {
        return url.host?.contains("youtube.com") == true || url.host?.contains("youtu.be") == true
    }
    
    func isVimeo(url: URL) -> Bool {
        return url.host?.contains("vimeo.com") == true
    }
    
    func isGitHub(url: URL) -> Bool {
        return url.host?.contains("github.com") == true
    }
    
    func isAppStore(url: URL) -> Bool {
        return url.host?.contains("apps.apple.com") == true
    }
    
    func isAmazon(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("amazon.com") || host.contains("amazon.co") || host.contains("amzn.to")
    }
    
    func isEbay(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("ebay.com") || host.contains("ebay.co")
    }
    
    func isPinterest(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("pinterest.com") || host.contains("pin.it")
    }
    
    func isSteam(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("store.steampowered.com") || host.contains("steamcommunity.com")
    }
    
    func isXbox(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("xbox.com") || host.contains("microsoft.com/store") || host.contains("microsoft.com/en-us/p/")
    }
    
    func isPlayStation(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("playstation.com") || host.contains("store.playstation.com")
    }
    
    func isBestBuy(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("bestbuy.com")
    }
    
    func detectIconType(for url: URL) -> IconType {
        if isYouTube(url: url) { return .youtube }
        if isGitHub(url: url) { return .github }
        if isAppStore(url: url) { return .appstore }
        if isVimeo(url: url) { return .vimeo }
        if isAmazon(url: url) { return .amazon }
        if isEbay(url: url) { return .ebay }
        if isPinterest(url: url) { return .pinterest }
        if isSteam(url: url) { return .steam }
        if isXbox(url: url) { return .xbox }
        if isPlayStation(url: url) { return .playstation }
        if isBestBuy(url: url) { return .bestbuy }
        return .none
    }
    
    // MARK: - Filename Generation
    
    func generateFilename(for url: URL, title: String? = nil) -> String {
        let iconType = detectIconType(for: url)
        
        switch iconType {
        case .youtube:
            if let title = title {
                let safeTitle = sanitizeFilename(title)
                return "YT-\(safeTitle).l1nk"
            }
            // Fallback: try to get video ID
            if let videoId = extractYouTubeVideoId(from: url) {
                return "YT-\(videoId).l1nk"
            }
            return "YouTube.l1nk"
            
        case .vimeo:
            if let title = title {
                let safeTitle = sanitizeFilename(title)
                return "Vimeo-\(safeTitle).l1nk"
            }
            // Fallback: try to get video ID from path
            if let videoId = url.pathComponents.last, videoId.allSatisfy({ $0.isNumber }) {
                return "Vimeo-\(videoId).l1nk"
            }
            return "Vimeo.l1nk"
            
        case .github:
            let components = url.pathComponents
            if components.count >= 3 {
                return "GitHub-\(components[2]).l1nk"
            } else if components.count >= 2 {
                return "GitHub-\(components[1]).l1nk"
            }
            return "GitHub.l1nk"
            
        case .appstore:
            let name = url.deletingLastPathComponent().lastPathComponent
            if !name.isEmpty && name != "app" {
                return "AppStore-\(name).l1nk"
            }
            return "AppStore.l1nk"
            
        case .amazon:
            // Try to extract product name from Amazon URL
            if let productName = extractAmazonProductName(from: url, title: title) {
                let safeTitle = sanitizeFilename(productName)
                return "Amazon-\(safeTitle).l1nk"
            }
            // Fallback: try to get ASIN
            if let asin = extractAmazonASIN(from: url) {
                return "Amazon-\(asin).l1nk"
            }
            return "Amazon.l1nk"
            
        case .ebay:
            // Try to extract item name from eBay URL
            if let itemName = extractEbayItemName(from: url, title: title) {
                let safeTitle = sanitizeFilename(itemName)
                return "eBay-\(safeTitle).l1nk"
            }
            // Fallback to item ID
            if let itemId = extractEbayItemId(from: url) {
                return "eBay-\(itemId).l1nk"
            }
            return "eBay.l1nk"
            
        case .pinterest:
            if let title = title {
                let safeTitle = sanitizeFilename(title)
                return "Pinterest-\(safeTitle).l1nk"
            }
            // Try to extract from URL path
            if let pinName = extractPinterestName(from: url) {
                let safeTitle = sanitizeFilename(pinName)
                return "Pinterest-\(safeTitle).l1nk"
            }
            return "Pinterest.l1nk"
            
        case .steam:
            if let title = title {
                let safeTitle = sanitizeFilename(title)
                return "Steam-\(safeTitle).l1nk"
            }
            // Try to extract game name from Steam URL
            if let gameName = extractSteamGameName(from: url) {
                let safeTitle = sanitizeFilename(gameName)
                return "Steam-\(safeTitle).l1nk"
            }
            // Fallback: try to get app ID
            if let appId = extractSteamAppId(from: url) {
                return "Steam-\(appId).l1nk"
            }
            return "Steam.l1nk"
            
        case .xbox:
            if let title = title {
                let safeTitle = sanitizeFilename(title)
                return "Xbox-\(safeTitle).l1nk"
            }
            // Fallback: try to get product ID from path
            if let productId = url.pathComponents.last, !productId.isEmpty && productId != "/" {
                let safeId = sanitizeFilename(productId)
                return "Xbox-\(safeId).l1nk"
            }
            return "Xbox.l1nk"
            
        case .playstation:
            if let title = title {
                let safeTitle = sanitizeFilename(title)
                return "PlayStation-\(safeTitle).l1nk"
            }
            // Fallback: try to get product ID from path
            if let productId = url.pathComponents.last, !productId.isEmpty && productId != "/" {
                let safeId = sanitizeFilename(productId)
                return "PlayStation-\(safeId).l1nk"
            }
            return "PlayStation.l1nk"
            
        case .bestbuy:
            if let title = title {
                let safeTitle = sanitizeFilename(title)
                return "BestBuy-\(safeTitle).l1nk"
            }
            // Try to extract product name from URL
            if let productName = extractBestBuyProductName(from: url) {
                let safeTitle = sanitizeFilename(productName)
                return "BestBuy-\(safeTitle).l1nk"
            }
            // Fallback: try to get SKU
            if let sku = extractBestBuySKU(from: url) {
                return "BestBuy-\(sku).l1nk"
            }
            return "BestBuy.l1nk"
            
        case .none:
            if let title = title {
                let safeTitle = sanitizeFilename(title)
                return "\(safeTitle).l1nk"
            }
            return formatDomainFilename(from: url)
        }
    }
    
    /// Create a clean filename from the domain name
    private func formatDomainFilename(from url: URL) -> String {
        guard let host = url.host?.lowercased() else {
            return "link.l1nk"
        }
        
        // Remove common prefixes
        var domain = host
        if domain.hasPrefix("www.") {
            domain = String(domain.dropFirst(4))
        }
        if domain.hasPrefix("m.") {
            domain = String(domain.dropFirst(2))
        }
        
        // Get just the main domain name (before first dot)
        if let dotIndex = domain.firstIndex(of: ".") {
            domain = String(domain[..<dotIndex])
        }
        
        // Capitalize first letter
        if let first = domain.first {
            domain = first.uppercased() + domain.dropFirst()
        }
        
        return "\(domain).l1nk"
    }
    
    /// Sanitize a string for use as a filename
    private func sanitizeFilename(_ name: String) -> String {
        // Remove invalid filename characters
        var sanitized = name.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined()
        // Replace multiple spaces with single space
        while sanitized.contains("  ") {
            sanitized = sanitized.replacingOccurrences(of: "  ", with: " ")
        }
        // Trim and limit length
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.count > 80 {
            sanitized = String(sanitized.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return sanitized
    }
    
    /// Extract Amazon ASIN from URL
    private func extractAmazonASIN(from url: URL) -> String? {
        let components = url.pathComponents
        for (index, component) in components.enumerated() {
            if (component == "dp" || component == "gp" || component == "product") && index + 1 < components.count {
                let asin = components[index + 1]
                // ASINs are 10 characters, alphanumeric
                if asin.count == 10 && asin.allSatisfy({ $0.isLetter || $0.isNumber }) {
                    return asin
                }
            }
        }
        return nil
    }
    
    /// Extract product name from Amazon URL path
    private func extractAmazonProductName(from url: URL, title: String?) -> String? {
        // If we have a title from page scraping, use it
        if let title = title, !title.isEmpty {
            // Clean up Amazon title (remove "Amazon.com: " prefix)
            var cleaned = title
            if cleaned.lowercased().hasPrefix("amazon.com:") {
                cleaned = String(cleaned.dropFirst(11)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if cleaned.lowercased().hasPrefix("amazon.com :") {
                cleaned = String(cleaned.dropFirst(12)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return cleaned
        }
        
        // Try to extract from URL path (e.g., /Apple-Studio-16-Core-40-Core-Unified/dp/...)
        let components = url.pathComponents
        for (index, component) in components.enumerated() {
            if component == "dp" && index > 0 {
                // The component before "dp" is usually the product name
                let productSlug = components[index - 1]
                // Convert slug to readable name (replace hyphens with spaces)
                let readable = productSlug.replacingOccurrences(of: "-", with: " ")
                if !readable.isEmpty && readable != "gp" {
                    return readable
                }
            }
        }
        
        return nil
    }
    
    /// Extract item name from eBay URL path
    private func extractEbayItemName(from url: URL, title: String?) -> String? {
        // If we have a title from page scraping, use it
        if let title = title, !title.isEmpty {
            // Clean up eBay title (remove "| eBay" suffix)
            var cleaned = title
            if let range = cleaned.range(of: " | eBay", options: .caseInsensitive) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
            return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Try to extract from URL path (e.g., /itm/Product-Name-Here/...)
        let components = url.pathComponents
        for (index, component) in components.enumerated() {
            if component == "itm" && index + 1 < components.count {
                // The component after "itm" is usually the item name
                let itemSlug = components[index + 1]
                // Convert slug to readable name (replace hyphens with spaces)
                let readable = itemSlug.replacingOccurrences(of: "-", with: " ")
                if !readable.isEmpty {
                    return readable
                }
            }
        }
        
        return nil
    }
    
    /// Extract name from Pinterest URL path
    private func extractPinterestName(from url: URL) -> String? {
        let components = url.pathComponents
        
        // Pinterest URLs can be like /pin/123456/ or /username/board-name/
        for (index, component) in components.enumerated() {
            if component == "pin" && index + 1 < components.count {
                // It's a pin URL, return generic name
                return "Pin \(components[index + 1].prefix(8))"
            }
        }
        
        // For board URLs, try to get board name
        if components.count >= 3 {
            let boardName = components[2].replacingOccurrences(of: "-", with: " ")
            if !boardName.isEmpty && boardName != "pin" && boardName != "_saved" {
                return boardName
            }
        }
        
        return nil
    }
    
    /// Extract game name from Steam URL path
    private func extractSteamGameName(from url: URL) -> String? {
        let components = url.pathComponents
        
        // Steam URLs are like /app/123456/Game_Name/
        for (index, component) in components.enumerated() {
            if component == "app" && index + 2 < components.count {
                // The component two after "app" is the game name slug
                let gameSlug = components[index + 2]
                // Convert underscores to spaces
                let readable = gameSlug.replacingOccurrences(of: "_", with: " ")
                if !readable.isEmpty {
                    return readable
                }
            }
        }
        
        return nil
    }
    
    /// Extract Steam app ID from URL
    private func extractSteamAppId(from url: URL) -> String? {
        let components = url.pathComponents
        for (index, component) in components.enumerated() {
            if component == "app" && index + 1 < components.count {
                let appId = components[index + 1]
                if appId.allSatisfy({ $0.isNumber }) {
                    return appId
                }
            }
        }
        return nil
    }
    
    /// Extract product name from Best Buy URL path
    private func extractBestBuyProductName(from url: URL) -> String? {
        let components = url.pathComponents
        
        // Best Buy URLs are like /site/product-name/1234567.p
        for (index, component) in components.enumerated() {
            if component == "site" && index + 1 < components.count {
                let productSlug = components[index + 1]
                // Convert hyphens to spaces
                let readable = productSlug.replacingOccurrences(of: "-", with: " ")
                if !readable.isEmpty && !readable.contains(".p") {
                    return readable
                }
            }
        }
        
        return nil
    }
    
    /// Extract Best Buy SKU from URL
    private func extractBestBuySKU(from url: URL) -> String? {
        let components = url.pathComponents
        for component in components {
            // SKUs end with .p and are numeric
            if component.hasSuffix(".p") {
                let sku = String(component.dropLast(2))
                if sku.allSatisfy({ $0.isNumber }) {
                    return sku
                }
            }
        }
        return nil
    }
    
    // MARK: - Title Fetching
    
    /// Fetch title for URLs - uses direct HTTP scraping (more reliable in sandbox)
    /// Has a hard timeout to prevent app hangs
    func fetchTitle(for url: URL, completion: @escaping (String?) -> Void) {
        // Fetch titles for video sites, shopping sites, social sites, and gaming stores
        // Skip eBay - they block scrapers aggressively
        let shouldFetchTitle = isYouTube(url: url) || isVimeo(url: url) || isAmazon(url: url) || isPinterest(url: url) || isSteam(url: url) || isXbox(url: url) || isPlayStation(url: url) || isBestBuy(url: url)
        
        guard shouldFetchTitle else {
            completion(nil)
            return
        }
        
        // Hard timeout - complete with nil after 5 seconds no matter what
        var hasCompleted = false
        let completionLock = NSLock()
        
        let safeComplete: (String?) -> Void = { title in
            completionLock.lock()
            defer { completionLock.unlock() }
            guard !hasCompleted else { return }
            hasCompleted = true
            DispatchQueue.main.async {
                completion(title)
            }
        }
        
        // Timeout after 5 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
            safeComplete(nil)
        }
        
        // Use direct scraping as primary method (works better in sandboxed apps)
        scrapeTitle(for: url) { title in
            if let title = title, !title.isEmpty {
                safeComplete(title)
            } else {
                // Fallback to LPMetadataProvider if scraping fails
                self.fetchTitleWithLinkPresentation(for: url) { lpTitle in
                    safeComplete(lpTitle)
                }
            }
        }
    }
    
    private func fetchTitleWithLinkPresentation(for url: URL, completion: @escaping (String?) -> Void) {
        let provider = LPMetadataProvider()
        provider.timeout = 3.0 // Short timeout to avoid long waits
        
        provider.startFetchingMetadata(for: url) { metadata, error in
            if let title = metadata?.title {
                let cleanTitle = self.cleanTitle(title)
                completion(cleanTitle)
            } else {
                print("LPMetadataProvider fallback failed: \(String(describing: error))")
                completion(nil)
            }
        }
    }
    
    private func scrapeTitle(for url: URL, completion: @escaping (String?) -> Void) {
        // Clean the URL to remove tracking parameters before scraping
        let cleanedURL = cleanURL(url)
        
        var request = URLRequest(url: cleanedURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 4.0  // Reduced timeout to prevent hangs
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Scrape error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            
            // Try multiple patterns to extract title
            let title = self.extractTitle(from: html)
            completion(title)
        }
        task.resume()
    }
    
    private func extractTitle(from html: String) -> String? {
        // Pattern 1: Standard <title> tag
        if let regex = try? NSRegularExpression(pattern: "<title[^>]*>(.*?)</title>", options: [.caseInsensitive, .dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)) {
            if let range = Range(match.range(at: 1), in: html) {
                let title = cleanTitle(String(html[range]))
                if !title.isEmpty {
                    return title
                }
            }
        }
        
        // Pattern 2: Open Graph title
        if let regex = try? NSRegularExpression(pattern: "<meta[^>]+property=[\"']og:title[\"'][^>]+content=[\"']([^\"']+)[\"']", options: .caseInsensitive),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)) {
            if let range = Range(match.range(at: 1), in: html) {
                let title = cleanTitle(String(html[range]))
                if !title.isEmpty {
                    return title
                }
            }
        }
        
        // Pattern 3: Twitter title
        if let regex = try? NSRegularExpression(pattern: "<meta[^>]+name=[\"']twitter:title[\"'][^>]+content=[\"']([^\"']+)[\"']", options: .caseInsensitive),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)) {
            if let range = Range(match.range(at: 1), in: html) {
                let title = cleanTitle(String(html[range]))
                if !title.isEmpty {
                    return title
                }
            }
        }
        
        return nil
    }
    
    private func cleanTitle(_ title: String) -> String {
        return title
            .replacingOccurrences(of: "&#x22;", with: "\"")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: " - YouTube", with: "")
            .replacingOccurrences(of: " on Vimeo", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - File Operations
    
    func generateUniqueURL(for url: URL) -> URL {
        var newURL = url
        var counter = 1
        let ext = newURL.pathExtension
        let base = newURL.deletingPathExtension().path
        
        while FileManager.default.fileExists(atPath: newURL.path) {
            newURL = URL(fileURLWithPath: "\(base) \(counter).\(ext)")
            counter += 1
        }
        return newURL
    }
    
    func saveLinkFile(url: URL, to destinationURL: URL) throws {
        try url.absoluteString.write(to: destinationURL, atomically: true, encoding: .utf8)
    }
}
