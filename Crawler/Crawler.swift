//
//  Crawler.swift
//  Crawler
//
//  Created by Chris Eidhof on 21.12.21.
//

import Foundation

@MainActor
final class Crawler: ObservableObject {
    @Published var state: [URL: Page] = [:]
    
    func crawl(url: URL) async throws {
        let basePrefix = url.absoluteString
        var queue: Set<URL> = [url]
        while let job = queue.popFirst() {
            let page = try await URLSession.shared.page(from: job)
            let newURLs = page.outgoingLinks.filter { url in
                url.absoluteString.hasPrefix(basePrefix) && state[url] == nil
            }
            queue.formUnion(newURLs)
            state[job] = page
        }
    }
}

extension URLSession {
    func page(from url: URL) async throws -> Page {
        let (data, _) = try await data(from: url)
        let doc = try XMLDocument(data: data, options: .documentTidyHTML)
        let title = try doc.nodes(forXPath: "//title").first?.stringValue
        let links: [URL] = try doc.nodes(forXPath: "//a[@href]").compactMap { node in
            guard let el = node as? XMLElement else { return nil }
            guard let href = el.attribute(forName: "href")?.stringValue else { return nil }
            return URL(string: href, relativeTo: url)?.simplified
        }
        return Page(url: url, title: title ?? "", outgoingLinks: links)
    }
}

extension URL {
    var simplified: URL {
        var result = absoluteString
        if let i = result.lastIndex(of: "#") {
            result = String(result[..<i])
        }
        if result.last == "/" {
            result.removeLast()
        }
        return URL(string: result)!
    }
}

struct Page {
    var url: URL
    var title: String
    var outgoingLinks: [URL]
}
