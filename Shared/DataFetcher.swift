import Foundation

struct DataFetcher {

    /// Fetch all configured data sources and return a dictionary of id → formatted display value
    static func fetchAll(sources: [DataSource], timeout: TimeInterval = 5) async -> [String: String] {
        await withTaskGroup(of: (String, String?).self) { group in
            for source in sources {
                group.addTask {
                    let value = await fetchOne(source: source, timeout: timeout)
                    return (source.id.uuidString, value)
                }
            }

            var results: [String: String] = [:]
            for await (id, value) in group {
                if let value {
                    results[id] = value
                }
            }
            return results
        }
    }

    /// Fetch a single data source. Returns formatted display string, or nil on failure.
    static func fetchOne(source: DataSource, timeout: TimeInterval = 5) async -> String? {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: config)

        guard let (data, response) = try? await session.data(from: source.url),
              let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return cachedValue(for: source)
        }

        let raw = extractValue(from: data, jsonPath: source.jsonPath)
        let formatted = formatValue(raw, format: source.displayFormat)

        if let formatted {
            cacheValue(formatted, for: source)
        }
        return formatted
    }

    // MARK: - JSON path extraction

    /// Simple JSON path extraction supporting dot notation: "$.key.nested" or "key.nested"
    static func extractValue(from data: Data, jsonPath: String?) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            // Not JSON — treat as plain text
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let path = jsonPath, !path.isEmpty else {
            // No path — return stringified root if it's a simple value
            return stringifyJSON(json)
        }

        let components = path
            .replacingOccurrences(of: "$.", with: "")
            .split(separator: ".")
            .map(String.init)

        var current: Any = json
        for key in components {
            if let dict = current as? [String: Any], let next = dict[key] {
                current = next
            } else if let array = current as? [Any], let index = Int(key), index < array.count {
                current = array[index]
            } else {
                return nil
            }
        }
        return stringifyJSON(current)
    }

    private static func stringifyJSON(_ value: Any) -> String? {
        switch value {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        case let b as Bool: return b ? "true" : "false"
        default: return nil
        }
    }

    // MARK: - Format

    /// Apply display format: "{value}°F" → "72°F"
    static func formatValue(_ raw: String?, format: String?) -> String? {
        guard let raw else { return nil }
        guard let format, !format.isEmpty else { return raw }
        return format.replacingOccurrences(of: "{value}", with: raw)
    }

    // MARK: - Cache (last successful value)

    private static let suiteName = "group.com.retropwidget"
    private static let cachePrefix = "dataCache_"

    private static func cacheValue(_ value: String, for source: DataSource) {
        UserDefaults(suiteName: suiteName)?.set(value, forKey: cachePrefix + source.id.uuidString)
    }

    private static func cachedValue(for source: DataSource) -> String? {
        UserDefaults(suiteName: suiteName)?.string(forKey: cachePrefix + source.id.uuidString)
    }
}
