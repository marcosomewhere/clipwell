// Services/ContentAnalyzer.swift
// Clipwell v1.2 — Detects URLs and whether text looks like code.
// All detection is synchronous and O(n) — safe to run on the main thread.

import Foundation

enum ContentAnalyzer {

    // MARK: - Public

    static func analyze(_ text: String) -> ContentAnalysis {
        // Skip analysis for very long texts — avoids regex slowdown on megabyte pastes
        guard text.count < 100_000 else { return .empty }

        return ContentAnalysis(
            detectedURL:    detectURL(in: text),
            urlTitle:       nil,    // filled async by URLMetadataService
            urlFaviconData: nil,
            codeLanguage:   detectCode(in: text),
            isEditedByUser: false
        )
    }

    // MARK: - URL Detection

    static func detectURL(in text: String) -> String? {
        // Only treat the text as a URL if it's essentially just a URL (no surrounding prose)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count < 2048 else { return nil }     // URLs don't get this long
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        let match = detector.firstMatch(in: trimmed, range: range)
        guard let match, let url = match.url else { return nil }

        // The match must cover ≥ 80% of the text to qualify as "this is a URL"
        let matchLength = Range(match.range, in: trimmed)
            .map { trimmed.distance(from: $0.lowerBound, to: $0.upperBound) } ?? 0
        guard Double(matchLength) / Double(trimmed.count) >= 0.8 else { return nil }

        return url.absoluteString
    }

    // MARK: - Code Detection

    /// Heuristic code detection. Returns nil for plain prose and never guesses a language.
    static func detectCode(in text: String) -> CodeLanguage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Must contain at least one newline or be clearly structured — avoid flagging
        // single-line prose as code
        let lineCount = trimmed.components(separatedBy: .newlines).count
        guard lineCount >= 2 || looksLikeSingleLineCode(trimmed) else { return nil }

        // JSON — must be valid-ish object or array
        if isJSON(trimmed)       { return .code }

        // XML / HTML
        if isXML(trimmed)        { return .code }
        if isHTML(trimmed)       { return .code }

        // YAML
        if isYAML(trimmed)       { return .code }

        // SQL
        if isSQL(trimmed)        { return .code }

        // Markdown
        if isMarkdown(trimmed)   { return .code }

        // Shell
        if isBash(trimmed)       { return .code }

        if contains(trimmed, patterns: codePatterns) { return .code }

        return nil
    }

    private static let codePatterns = [
        #"\bfun\b.*\{|val\s+\w+\s*[:=]|data class\b"#,
        #"\bimport SwiftUI\b|\bvar\b.+\{.*\bget\b|\bstruct\b.+\bView\b"#,
        #"\bfunc\b.+\{|\blet\b.+:\s+\w|\bguard\b.+\belse\b"#,
        #"\bdef\b.+:|^\s*import\s+\w+$|^\s*from\s+\w+\s+import"#,
        #"\bfn\b.+\{|\blet mut\b|\bimpl\b.+\{|->.*\{"#,
        #"\binterface\b.+\{|\bpublic (class|static|void)\b|\b@Override\b"#,
        #"\bpackage main\b|\bfunc\b.+\(.*\).*\{"#,
        #"\bconst\b|\blet\b|\b=>\b|async\b.+await|\.then\("#,
        #"namespace\b|using\s+System|\.cs\b"#,
        #"#include\b|std::|cout\b|cin\b"#,
        #"\$\w+\s*=|\becho\b|\bfunction\b.+\(|\bforeach\b"#,
        #"\bdef\b.+\bdo\b|\bend\b|\.rb\b|puts\b"#,
        #"[{};].*\n.*[{};]|\bmargin:|padding:|font-size:"#
    ]

    // MARK: - Format-specific detectors

    private static func isJSON(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (t.hasPrefix("{") && t.hasSuffix("}")) ||
              (t.hasPrefix("[") && t.hasSuffix("]")) else { return false }
        return (try? JSONSerialization.jsonObject(with: Data(t.utf8))) != nil
    }

    private static func isXML(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return (t.hasPrefix("<?xml") || t.hasPrefix("<") ) &&
               t.contains("</") &&
               (try? XMLDocument(xmlString: t)) != nil
    }

    private static func isHTML(_ s: String) -> Bool {
        let lower = s.lowercased()
        return lower.contains("<div") || lower.contains("<p>") ||
               lower.contains("<span") || lower.contains("<!doctype html")
    }

    private static func isYAML(_ s: String) -> Bool {
        let lines = s.components(separatedBy: .newlines).prefix(10)
        let nonEmptyLines = lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let hasYAMLStructure = nonEmptyLines.contains { line in
            line.contains(": ") || line == "---" || line == "..."
        }
        guard hasYAMLStructure else { return false }

        let yamlLines = lines.filter {
            let t = $0.trimmingCharacters(in: .whitespaces)
            return t.contains(": ") || t == "---" || t == "..." || t.hasPrefix("  - ")
        }
        return yamlLines.count >= 2
    }

    private static func isSQL(_ s: String) -> Bool {
        let upper = s.uppercased()
        let keywords = ["SELECT ", "INSERT INTO", "UPDATE ", "DELETE FROM",
                        "CREATE TABLE", "DROP TABLE", "ALTER TABLE", "WHERE ", "FROM "]
        return keywords.filter { upper.contains($0) }.count >= 2
    }

    private static func isMarkdown(_ s: String) -> Bool {
        let indicators = ["## ", "### ", "**", "__", "```", "- [", "> "]
        return indicators.filter { s.contains($0) }.count >= 2
    }

    private static func isBash(_ s: String) -> Bool {
        let lines = s.components(separatedBy: .newlines)
        return lines.first?.hasPrefix("#!/") == true ||
               s.contains("$( ") || s.contains("${") ||
               (s.contains("| ") && (s.contains("grep") || s.contains("awk") || s.contains("sed")))
    }

    private static func looksLikeSingleLineCode(_ s: String) -> Bool {
        // A single line that starts/ends with brackets is likely a JSON value or expression
        let t = s.trimmingCharacters(in: .whitespaces)
        return (t.hasPrefix("{") && t.hasSuffix("}")) ||
               (t.hasPrefix("[") && t.hasSuffix("]"))
    }

    private static func contains(_ text: String, patterns: [String]) -> Bool {
        patterns.contains {
            (try? NSRegularExpression(pattern: $0, options: [.anchorsMatchLines]))?
                .firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }
    }
}
