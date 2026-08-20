//
//  OrbitWebSearchService.swift
//  Orbit
//
//  Created by EVA on 03/08/26.
//

import Foundation

struct OrbitWebSearchResult: Sendable, Equatable {
    let title: String
    let snippet: String
    let url: String
}

enum OrbitWebSearchService {
    private struct DuckDuckGoResponse: Decodable {
        let abstractText: String?
        let abstractURL: String?
        let heading: String?
        let relatedTopics: [RelatedTopic]?

        enum CodingKeys: String, CodingKey {
            case abstractText = "AbstractText"
            case abstractURL = "AbstractURL"
            case heading = "Heading"
            case relatedTopics = "RelatedTopics"
        }
    }

    private struct RelatedTopic: Decodable {
        let text: String?
        let firstURL: String?
        let topics: [RelatedTopic]?

        enum CodingKeys: String, CodingKey {
            case text = "Text"
            case firstURL = "FirstURL"
            case topics = "Topics"
        }
    }

    static func shouldSearchWeb(for text: String) -> Bool {
        let normalized = normalizedSearchText(text)
        guard normalized.isEmpty == false else { return false }

        let explicitSearchMarkers = [
            "pesquise",
            "pesquisa",
            "pesquisar",
            "procure",
            "procure na internet",
            "procurar na internet",
            "busque",
            "busque na internet",
            "buscar na internet",
            "olhe na internet",
            "consulte a internet",
            "na web",
            "online"
        ]

        if explicitSearchMarkers.contains(where: { normalized.contains($0) }) {
            return true
        }

        if isStableKnowledgeQuestion(normalized) {
            return false
        }

        let currentInformationMarkers = [
            "hoje",
            "amanha",
            "amanhã",
            "agora",
            "atual",
            "atuais",
            "atualmente",
            "nesse momento",
            "neste momento",
            "esta semana",
            "essa semana",
            "este mes",
            "este mês",
            "esse mes",
            "esse mês",
            "fim de semana",
            "recente",
            "recentes",
            "horario",
            "horarios",
            "horário",
            "horários",
            "abre hoje",
            "fecha hoje",
            "aberto agora",
            "funcionando",
            "preco",
            "precos",
            "preço",
            "preços",
            "cotacao",
            "cotação",
            "dolar",
            "dólar",
            "euro",
            "bitcoin",
            "noticia",
            "noticias",
            "notícia",
            "notícias",
            "ultimo",
            "ultimos",
            "último",
            "últimos",
            "mais recente",
            "loja",
            "lojas",
            "mercado",
            "mercados",
            "restaurante",
            "restaurantes",
            "site",
            "sites",
            "endereco",
            "telefone",
            "lugar",
            "lugares",
            "clima",
            "temperatura",
            "previsao do tempo",
            "previsão do tempo",
            "vai chover",
            "chuva",
            "transito",
            "trânsito",
            "voo",
            "voos",
            "passagem",
            "passagens",
            "hotel",
            "hoteis",
            "hotéis",
            "show",
            "shows",
            "evento",
            "eventos",
            "cinema",
            "sessao",
            "sessão",
            "ingresso",
            "ingressos",
            "produto",
            "produtos",
            "modelo",
            "versao",
            "versão",
            "lançamento",
            "lancamento",
            "cupom",
            "promocao",
            "promoção",
            "melhor",
            "melhores",
            "recomenda",
            "recomendacao",
            "recomendação",
            "vale a pena",
            "comparar",
            "comparativo"
        ]

        if currentInformationMarkers.contains(where: { normalized.contains($0) }) {
            return true
        }

        let lookupQuestionPrefixes = [
            "quem e ",
            "quem é ",
            "o que aconteceu",
            "o que esta acontecendo",
            "o que está acontecendo",
            "quando vai",
            "quando lança",
            "quando lanca",
            "quando estreia",
            "onde fica",
            "onde comprar",
            "qual o site",
            "qual e o site",
            "qual é o site",
            "qual o telefone",
            "qual o endereco",
            "qual o endereço",
            "como chegar",
            "como esta",
            "como está"
        ]

        if lookupQuestionPrefixes.contains(where: { normalized.hasPrefix($0) || normalized.contains(" " + $0) }) {
            return true
        }

        if containsYearLikeCurrentReference(normalized) {
            return true
        }

        return false
    }

    static func search(query: String, limit: Int = 5) async throws -> [OrbitWebSearchResult] {
        let cleanQuery = cleanedSearchQuery(from: query)
        guard cleanQuery.isEmpty == false else { return [] }

        var results: [OrbitWebSearchResult] = []

        if let googleResults = try? await googleHTMLSearch(query: cleanQuery, limit: limit) {
            results.append(contentsOf: googleResults)
        }

        if results.count < limit,
           let instantResults = try? await duckDuckGoInstantSearch(query: cleanQuery, limit: limit - results.count) {
            results.append(contentsOf: instantResults)
        }

        if results.count < limit,
           let duckDuckGoResults = try? await duckDuckGoHTMLSearch(query: cleanQuery, limit: limit - results.count) {
            results.append(contentsOf: duckDuckGoResults)
        }

        if results.count < limit,
           let wikipediaResults = try? await wikipediaSearch(query: cleanQuery, limit: limit - results.count) {
            results.append(contentsOf: wikipediaResults)
        }

        if results.isEmpty {
            results = fallbackSearchLinks(for: cleanQuery)
        }

        return uniqueResults(results, limit: limit)
    }

    private static func googleHTMLSearch(query cleanQuery: String, limit: Int) async throws -> [OrbitWebSearchResult] {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: cleanQuery),
            URLQueryItem(name: "hl", value: "pt-BR"),
            URLQueryItem(name: "num", value: "\(max(limit, 5))")
        ]

        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return []
        }

        let pattern = #"<a\s+[^>]*href=\"/url\?q=([^\"&]+)[^\"]*\"[^>]*>([\s\S]{0,1200}?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var results: [OrbitWebSearchResult] = []

        for match in regex.matches(in: html, range: range) {
            guard results.count < limit,
                  let urlRange = Range(match.range(at: 1), in: html),
                  let bodyRange = Range(match.range(at: 2), in: html) else {
                continue
            }

            let decodedURL = decodedGoogleRedirect(String(html[urlRange]))
            guard isSearchResultURL(decodedURL) else { continue }

            let body = String(html[bodyRange])
            let title = googleResultTitle(from: body)
            guard title.isEmpty == false else { continue }

            let snippet = googleResultSnippet(from: html, matchRange: match.range, title: title)
            results.append(OrbitWebSearchResult(
                title: title,
                snippet: snippet.isEmpty ? "Resultado encontrado no Google para \(cleanQuery)." : snippet,
                url: decodedURL
            ))
        }

        return results
    }

    private static func duckDuckGoInstantSearch(query cleanQuery: String, limit: Int) async throws -> [OrbitWebSearchResult] {
        var components = URLComponents(string: "https://api.duckduckgo.com/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: cleanQuery),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "no_html", value: "1"),
            URLQueryItem(name: "skip_disambig", value: "1")
        ]

        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Orbit/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return []
        }

        let decoded = try JSONDecoder().decode(DuckDuckGoResponse.self, from: data)
        var results: [OrbitWebSearchResult] = []

        if let abstractText = decoded.abstractText?.trimmingCharacters(in: .whitespacesAndNewlines),
           abstractText.isEmpty == false {
            results.append(OrbitWebSearchResult(
                title: cleanResultText(decoded.heading) ?? cleanQuery,
                snippet: abstractText,
                url: cleanResultText(decoded.abstractURL) ?? "https://duckduckgo.com/?q=\(cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanQuery)"
            ))
        }

        appendRelatedTopics(decoded.relatedTopics ?? [], to: &results, limit: limit)
        return results
    }

    private static func duckDuckGoHTMLSearch(query cleanQuery: String, limit: Int) async throws -> [OrbitWebSearchResult] {
        var components = URLComponents(string: "https://duckduckgo.com/html/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: cleanQuery)
        ]

        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Mozilla/5.0 Orbit/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return []
        }

        let itemPattern = #"<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>[\s\S]*?<a[^>]*class="result__snippet"[^>]*>(.*?)</a>"#
        let matches = regexMatches(pattern: itemPattern, in: html)
        return matches.prefix(limit).compactMap { groups in
            guard groups.count >= 4 else { return nil }
            let rawURL = decodedDuckDuckGoRedirect(groups[1])
            let title = cleanHTMLText(groups[2])
            let snippet = cleanHTMLText(groups[3])
            guard title.isEmpty == false else { return nil }
            return OrbitWebSearchResult(title: title, snippet: snippet, url: rawURL)
        }
    }

    private static func wikipediaSearch(query cleanQuery: String, limit: Int) async throws -> [OrbitWebSearchResult] {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "opensearch"),
            URLQueryItem(name: "search", value: cleanQuery),
            URLQueryItem(name: "limit", value: "\(max(limit, 1))"),
            URLQueryItem(name: "namespace", value: "0"),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Orbit/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let payload = try JSONSerialization.jsonObject(with: data) as? [Any],
              payload.count >= 4,
              let titles = payload[1] as? [String],
              let snippets = payload[2] as? [String],
              let urls = payload[3] as? [String] else {
            return []
        }

        return titles.indices.prefix(limit).map { index in
            OrbitWebSearchResult(
                title: titles[index],
                snippet: snippets.indices.contains(index) ? snippets[index] : "Resultado da Wikipedia para \(cleanQuery).",
                url: urls.indices.contains(index) ? urls[index] : ""
            )
        }
    }

    static func isWeatherQuery(_ text: String) -> Bool {
        let normalized = normalizedSearchText(text)
        return normalized.contains("previsao do tempo")
            || normalized.contains("previsão do tempo")
            || normalized.contains("clima")
            || normalized.contains("temperatura")
            || normalized.contains("vai chover")
            || normalized.contains("chuva")
    }

    static func weatherSummary(for query: String) async throws -> String {
        let location = weatherLocation(from: query)
        let path = location?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let urlString = path.isEmpty
            ? "https://wttr.in/?format=3&m&lang=pt"
            : "https://wttr.in/\(path)?format=3&m&lang=pt"

        guard let url = URL(string: urlString) else {
            return "Não consegui montar a consulta de previsão do tempo."
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Orbit/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let rawText = String(data: data, encoding: .utf8) else {
            return "Não consegui consultar a previsão do tempo agora."
        }

        let cleanText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanText.isEmpty == false else {
            return "A consulta de previsão do tempo não retornou dados agora."
        }

        if let location, location.isEmpty == false {
            return "Previsão do tempo para \(location): \(cleanText)"
        }

        return "Previsão do tempo pela localização aproximada da conexão: \(cleanText)"
    }

    static func contextBlock(for results: [OrbitWebSearchResult], query: String) -> String {
        guard results.isEmpty == false else {
            return """
            Pesquisa na internet para "\(query)":
            Nenhum mecanismo retornou trechos diretos. Responda com o melhor conhecimento disponível sem incluir links.
            """
        }

        let lines = results.enumerated().map { index, result in
            let snippet = result.snippet.replacingOccurrences(of: "\n", with: " ")
            let sourceName = displaySourceName(for: result.url)
            return "[\(index + 1)] \(result.title) - \(snippet) (fonte: \(sourceName))"
        }

        return """
        Pesquisa na internet para "\(query)":
        Use estes resultados como contexto disponível. Se algum trecho for limitado, ainda responda ao pedido com o melhor resultado possível. Não inclua URLs ou links na resposta final; no máximo cite o nome do site.
        \(lines.joined(separator: "\n"))
        """
    }

    static func displaySourceName(for urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host(percentEncoded: false)?.lowercased(),
              host.isEmpty == false else {
            return "site não informado"
        }

        return host
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: "m.", with: "")
    }

    static func searchQueryForSuggestion(title: String, details: String, attachmentNames: [String]) -> String {
        let source = [title, details, attachmentNames.joined(separator: " ")]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")

        let compact = source
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \Character.isWhitespace)
            .prefix(18)
            .joined(separator: " ")

        return compact.isEmpty ? source : compact
    }

    private static func appendRelatedTopics(_ topics: [RelatedTopic], to results: inout [OrbitWebSearchResult], limit: Int) {
        guard results.count < limit else { return }

        for topic in topics {
            if let nested = topic.topics, nested.isEmpty == false {
                appendRelatedTopics(nested, to: &results, limit: limit)
            } else if let text = cleanResultText(topic.text) {
                let title = text.components(separatedBy: " - ").first ?? text
                results.append(OrbitWebSearchResult(
                    title: String(title.prefix(90)),
                    snippet: text,
                    url: cleanResultText(topic.firstURL) ?? ""
                ))
            }

            if results.count >= limit { return }
        }
    }

    private static func isStableKnowledgeQuestion(_ normalized: String) -> Bool {
        let stablePrefixes = [
            "qual e a capital",
            "qual é a capital",
            "capital da",
            "capital do",
            "quanto e ",
            "quanto é ",
            "calcule ",
            "resume ",
            "resuma ",
            "traduza ",
            "explique "
        ]

        let unstableMarkers = [
            "hoje",
            "agora",
            "atual",
            "202",
            "preco",
            "preço",
            "noticia",
            "notícia",
            "site",
            "horario",
            "horário",
            "loja",
            "mercado",
            "clima"
        ]

        guard stablePrefixes.contains(where: { normalized.hasPrefix($0) }) else { return false }
        return unstableMarkers.contains(where: { normalized.contains($0) }) == false
    }

    private static func containsYearLikeCurrentReference(_ normalized: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: #"\b20[2-9][0-9]\b"#) else { return false }
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        return regex.firstMatch(in: normalized, range: range) != nil
    }

    private static func fallbackSearchLinks(for query: String) -> [OrbitWebSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return [
            OrbitWebSearchResult(
                title: "Google: \(query)",
                snippet: "A busca automática não retornou trechos diretos, mas este link abre a pesquisa no Google para continuar a consulta.",
                url: "https://www.google.com/search?q=\(encodedQuery)"
            ),
            OrbitWebSearchResult(
                title: "DuckDuckGo: \(query)",
                snippet: "Link alternativo de busca para conferir resultados públicos sobre o pedido.",
                url: "https://duckduckgo.com/?q=\(encodedQuery)"
            )
        ]
    }

    private static func uniqueResults(_ results: [OrbitWebSearchResult], limit: Int) -> [OrbitWebSearchResult] {
        var seenKeys = Set<String>()
        return results.filter { result in
            let key = result.url.isEmpty ? result.title : result.url
            return seenKeys.insert(key).inserted
        }
        .prefix(limit)
        .map { $0 }
    }

    private static func regexMatches(pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).map { match in
            (0..<match.numberOfRanges).map { index in
                guard let range = Range(match.range(at: index), in: text) else { return "" }
                return String(text[range])
            }
        }
    }

    private static func decodedDuckDuckGoRedirect(_ rawValue: String) -> String {
        let decoded = htmlDecoded(rawValue)
        guard let url = URL(string: decoded),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let uddg = components.queryItems?.first(where: { $0.name == "uddg" })?.value else {
            return decoded
        }

        return uddg
    }

    private static func decodedGoogleRedirect(_ rawValue: String) -> String {
        htmlDecoded(rawValue).removingPercentEncoding ?? htmlDecoded(rawValue)
    }

    private static func isSearchResultURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased(),
              host.isEmpty == false else {
            return false
        }

        let blockedHosts = [
            "google.com",
            "www.google.com",
            "accounts.google.com",
            "support.google.com",
            "policies.google.com",
            "maps.google.com"
        ]

        return blockedHosts.contains(host) == false
    }

    private static func googleResultTitle(from body: String) -> String {
        let h3Pattern = #"<h3[^>]*>([\s\S]*?)</h3>"#
        if let groups = regexMatches(pattern: h3Pattern, in: body).first,
           groups.count >= 2 {
            return cleanHTMLText(groups[1])
        }

        return cleanHTMLText(body)
    }

    private static func googleResultSnippet(from html: String, matchRange: NSRange, title: String) -> String {
        guard let range = Range(matchRange, in: html) else { return "" }

        let afterMatch = html[range.upperBound...]
        let limited = String(afterMatch.prefix(1800))
        let candidates = [
            #"<div[^>]*class=\"[^\"]*(?:VwiC3b|BNeawe|hgKElc|IsZvec)[^\"]*\"[^>]*>([\s\S]*?)</div>"#,
            #"<span[^>]*>([\s\S]{40,500}?)</span>"#
        ]

        for pattern in candidates {
            guard let groups = regexMatches(pattern: pattern, in: limited).first,
                  groups.count >= 2 else {
                continue
            }

            let snippet = cleanHTMLText(groups[1])
            if snippet.isEmpty == false,
               snippet != title,
               snippet.count > 20 {
                return String(snippet.prefix(280))
            }
        }

        return ""
    }

    private static func cleanHTMLText(_ html: String) -> String {
        let withoutTags = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return htmlDecoded(withoutTags)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func htmlDecoded(_ text: String) -> String {
        var decoded = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")

        let numericMatches = regexMatches(pattern: #"&#(\d+);"#, in: decoded)
        for match in numericMatches where match.count >= 2 {
            guard let scalarValue = UInt32(match[1]),
                  let scalar = UnicodeScalar(scalarValue) else { continue }
            decoded = decoded.replacingOccurrences(of: match[0], with: String(Character(scalar)))
        }

        return decoded
    }

    private static func cleanedSearchQuery(from text: String) -> String {
        var query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let removals = [
            "pesquise",
            "pesquisar",
            "procure na internet",
            "procurar na internet",
            "busque na internet",
            "buscar na internet",
            "olhe na internet",
            "consulte a internet",
            "na internet",
            "na web",
            "online"
        ]

        for removal in removals {
            query = query.replacingOccurrences(of: removal, with: "", options: [.caseInsensitive, .diacriticInsensitive])
        }

        query = query.replacingOccurrences(of: "\n", with: " ")
        query = query.split(whereSeparator: \Character.isWhitespace).joined(separator: " ")
        return String(query.prefix(220)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func weatherLocation(from text: String) -> String? {
        let normalized = text.replacingOccurrences(of: "\n", with: " ")
        let markers = [" em ", " para ", " de "]

        for marker in markers {
            guard let range = normalized.range(of: marker, options: [.caseInsensitive, .diacriticInsensitive]) else { continue }
            let suffix = normalized[range.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            if suffix.count >= 2 {
                return String(suffix.prefix(80))
            }
        }

        return nil
    }

    private static func cleanResultText(_ text: String?) -> String? {
        guard let text else { return nil }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    private static func normalizedSearchText(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}
