import Foundation
import AppKit
import UniformTypeIdentifiers
import LinkPresentation

class LinkService {
    static let shared = LinkService()
    
    private init() {}
    
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
    
    func detectIconType(for url: URL) -> IconType {
        if isYouTube(url: url) { return .youtube }
        if isGitHub(url: url) { return .github }
        if isAppStore(url: url) { return .appstore }
        if isVimeo(url: url) { return .vimeo }
        return .none
    }
    
    // MARK: - Filename Generation
    
    func generateFilename(for url: URL, title: String? = nil) -> String {
        let iconType = detectIconType(for: url)
        
        switch iconType {
        case .youtube:
            if let title = title {
                let safeTitle = title.components(separatedBy: .init(charactersIn: "/\\:?%*|\"<>")).joined()
                return "YT-\(safeTitle).l1nk"
            }
            return (url.host ?? "youtube") + ".l1nk"
            
        case .vimeo:
            if let title = title {
                let safeTitle = title.components(separatedBy: .init(charactersIn: "/\\:?%*|\"<>")).joined()
                return "Vimeo-\(safeTitle).l1nk"
            }
            return (url.host ?? "vimeo") + ".l1nk"
            
        case .github:
            let components = url.pathComponents
            if components.count >= 3 {
                return components[2] + ".l1nk"
            } else if components.count >= 2 {
                return components[1] + ".l1nk"
            }
            return "GitHub.l1nk"
            
        case .appstore:
            let name = url.deletingLastPathComponent().lastPathComponent
            if !name.isEmpty && name != "app" {
                return name + ".l1nk"
            }
            return "AppStore.l1nk"
            
        case .none:
            return (url.host ?? "link") + ".l1nk"
        }
    }
    
    // MARK: - Title Fetching
    
    func fetchTitle(for url: URL, completion: @escaping (String?) -> Void) {
        guard isYouTube(url: url) || isVimeo(url: url) else {
            completion(nil)
            return
        }
        
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { metadata, error in
            if let title = metadata?.title {
                let cleanTitle = title.replacingOccurrences(of: " - YouTube", with: "")
                completion(cleanTitle)
            } else {
                print("LPMetadataProvider failed: \(String(describing: error))")
                self.scrapeTitle(for: url, completion: completion)
            }
        }
    }
    
    private func scrapeTitle(for url: URL, completion: @escaping (String?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            
            if let regex = try? NSRegularExpression(pattern: "<title>(.*?)</title>", options: .caseInsensitive),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.count)) {
                
                if let range = Range(match.range(at: 1), in: html) {
                    let title = String(html[range])
                        .replacingOccurrences(of: "&#x22;", with: "\"")
                        .replacingOccurrences(of: "&quot;", with: "\"")
                        .replacingOccurrences(of: "&amp;", with: "&")
                        .replacingOccurrences(of: " - YouTube", with: "")
                    completion(title)
                    return
                }
            }
            completion(nil)
        }
        task.resume()
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
