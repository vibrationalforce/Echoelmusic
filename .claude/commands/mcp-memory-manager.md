# Echoelmusic MCP Memory Manager

Du bist ein MCP Server für intelligentes Memory Management und Context Optimization.

## MCP Memory Server:

### 1. Server Definition
```typescript
{
  "name": "echoelmusic-memory",
  "version": "1.0.0",
  "description": "Intelligent memory and context management",
  "capabilities": {
    "tools": true,
    "resources": true,
    "memory": true
  }
}
```

### 2. Memory Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    MEMORY HIERARCHY                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐                                        │
│  │ Working Memory  │ ← Current session context              │
│  │   (Hot Cache)   │   TTL: Session duration                │
│  └────────┬────────┘                                        │
│           │                                                  │
│  ┌────────▼────────┐                                        │
│  │ Session Memory  │ ← Recent interactions                  │
│  │  (Warm Cache)   │   TTL: 24 hours                        │
│  └────────┬────────┘                                        │
│           │                                                  │
│  ┌────────▼────────┐                                        │
│  │ Project Memory  │ ← CLAUDE.md + learned patterns         │
│  │  (Cold Cache)   │   TTL: Persistent                      │
│  └────────┬────────┘                                        │
│           │                                                  │
│  ┌────────▼────────┐                                        │
│  │ Universal Memory│ ← Cross-project knowledge              │
│  │   (Archive)     │   TTL: Forever                         │
│  └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
```

### 3. Available Tools

#### store_memory
```json
{
  "name": "store_memory",
  "description": "Store information in memory with importance scoring",
  "inputSchema": {
    "type": "object",
    "properties": {
      "key": { "type": "string" },
      "value": { "type": "any" },
      "category": {
        "type": "string",
        "enum": ["code", "preference", "pattern", "issue", "solution", "todo"]
      },
      "importance": {
        "type": "number",
        "minimum": 0,
        "maximum": 1,
        "default": 0.5
      },
      "ttl": {
        "type": "string",
        "enum": ["session", "day", "week", "month", "forever"],
        "default": "week"
      }
    },
    "required": ["key", "value"]
  }
}
```

#### recall_memory
```json
{
  "name": "recall_memory",
  "description": "Recall stored memories with semantic search",
  "inputSchema": {
    "type": "object",
    "properties": {
      "query": { "type": "string" },
      "category": { "type": "string" },
      "limit": { "type": "integer", "default": 10 },
      "minImportance": { "type": "number", "default": 0 }
    },
    "required": ["query"]
  }
}
```

#### forget_memory
```json
{
  "name": "forget_memory",
  "description": "Remove memory entries",
  "inputSchema": {
    "type": "object",
    "properties": {
      "key": { "type": "string" },
      "category": { "type": "string" },
      "olderThan": { "type": "string" }
    }
  }
}
```

#### analyze_context
```json
{
  "name": "analyze_context",
  "description": "Analyze current context for relevance",
  "inputSchema": {
    "type": "object",
    "properties": {
      "context": { "type": "string" },
      "task": { "type": "string" }
    },
    "required": ["context", "task"]
  }
}
```

#### optimize_context
```json
{
  "name": "optimize_context",
  "description": "Optimize context window usage",
  "inputSchema": {
    "type": "object",
    "properties": {
      "maxTokens": { "type": "integer", "default": 100000 },
      "prioritize": {
        "type": "array",
        "items": { "type": "string" }
      }
    }
  }
}
```

#### get_project_summary
```json
{
  "name": "get_project_summary",
  "description": "Get compressed project knowledge",
  "inputSchema": {
    "type": "object",
    "properties": {
      "depth": {
        "type": "string",
        "enum": ["brief", "standard", "detailed"],
        "default": "standard"
      },
      "focus": { "type": "string" }
    }
  }
}
```

### 4. Swift Implementation

```swift
// MCPMemoryManager.swift
import Foundation
import NaturalLanguage

@MainActor
public class MCPMemoryManager {
    static let shared = MCPMemoryManager()

    // MARK: - Memory Stores

    private var workingMemory: [String: MemoryEntry] = [:]
    private var sessionMemory: [String: MemoryEntry] = [:]
    private var projectMemory: [String: MemoryEntry] = [:]

    // MARK: - Memory Entry

    struct MemoryEntry: Codable {
        let key: String
        var value: String
        let category: MemoryCategory
        var importance: Double
        let createdAt: Date
        var accessedAt: Date
        var accessCount: Int
        let ttl: TTL

        enum MemoryCategory: String, Codable {
            case code, preference, pattern, issue, solution, todo
        }

        enum TTL: String, Codable {
            case session, day, week, month, forever
        }

        var isExpired: Bool {
            switch ttl {
            case .session: return false // Managed externally
            case .day: return Date().timeIntervalSince(createdAt) > 86400
            case .week: return Date().timeIntervalSince(createdAt) > 604800
            case .month: return Date().timeIntervalSince(createdAt) > 2592000
            case .forever: return false
            }
        }
    }

    // MARK: - Tool Handlers

    func handleToolCall(name: String, arguments: [String: Any]) async -> MCPResult {
        switch name {
        case "store_memory":
            return storeMemory(arguments)
        case "recall_memory":
            return await recallMemory(arguments)
        case "forget_memory":
            return forgetMemory(arguments)
        case "analyze_context":
            return await analyzeContext(arguments)
        case "optimize_context":
            return await optimizeContext(arguments)
        case "get_project_summary":
            return await getProjectSummary(arguments)
        default:
            return .error("Unknown tool: \(name)")
        }
    }

    // MARK: - Store Memory

    private func storeMemory(_ args: [String: Any]) -> MCPResult {
        guard let key = args["key"] as? String,
              let value = args["value"] else {
            return .error("Missing key or value")
        }

        let category = MemoryEntry.MemoryCategory(rawValue: args["category"] as? String ?? "pattern") ?? .pattern
        let importance = args["importance"] as? Double ?? 0.5
        let ttl = MemoryEntry.TTL(rawValue: args["ttl"] as? String ?? "week") ?? .week

        let entry = MemoryEntry(
            key: key,
            value: String(describing: value),
            category: category,
            importance: importance,
            createdAt: Date(),
            accessedAt: Date(),
            accessCount: 0,
            ttl: ttl
        )

        // Store in appropriate memory level
        switch ttl {
        case .session:
            workingMemory[key] = entry
        case .day, .week:
            sessionMemory[key] = entry
        case .month, .forever:
            projectMemory[key] = entry
        }

        // Persist project memory
        if ttl == .forever || ttl == .month {
            persistProjectMemory()
        }

        return .success([
            "stored": true,
            "key": key,
            "level": ttl.rawValue
        ])
    }

    // MARK: - Recall Memory

    private func recallMemory(_ args: [String: Any]) async -> MCPResult {
        guard let query = args["query"] as? String else {
            return .error("Missing query")
        }

        let category = args["category"] as? String
        let limit = args["limit"] as? Int ?? 10
        let minImportance = args["minImportance"] as? Double ?? 0

        // Combine all memories
        var allMemories: [MemoryEntry] = []
        allMemories.append(contentsOf: workingMemory.values)
        allMemories.append(contentsOf: sessionMemory.values)
        allMemories.append(contentsOf: projectMemory.values)

        // Filter by category if specified
        if let cat = category, let memCat = MemoryEntry.MemoryCategory(rawValue: cat) {
            allMemories = allMemories.filter { $0.category == memCat }
        }

        // Filter by importance
        allMemories = allMemories.filter { $0.importance >= minImportance }

        // Filter expired
        allMemories = allMemories.filter { !$0.isExpired }

        // Semantic search using NLEmbedding
        let rankedMemories = await semanticSearch(query: query, memories: allMemories)

        // Take top results
        let results = rankedMemories.prefix(limit).map { memory -> [String: Any] in
            return [
                "key": memory.key,
                "value": memory.value,
                "category": memory.category.rawValue,
                "importance": memory.importance,
                "accessCount": memory.accessCount
            ]
        }

        // Update access counts
        for memory in rankedMemories.prefix(limit) {
            updateAccessCount(memory.key)
        }

        return .success([
            "results": Array(results),
            "total": rankedMemories.count
        ])
    }

    private func semanticSearch(query: String, memories: [MemoryEntry]) async -> [MemoryEntry] {
        // Use NLEmbedding for semantic similarity
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
            // Fallback to keyword matching
            return memories.sorted { m1, m2 in
                let score1 = keywordScore(query: query, text: m1.value)
                let score2 = keywordScore(query: query, text: m2.value)
                return score1 > score2
            }
        }

        // Calculate similarity scores
        var scored: [(MemoryEntry, Double)] = []

        for memory in memories {
            if let queryVector = embedding.vector(for: query),
               let memoryVector = embedding.vector(for: memory.value) {
                let similarity = cosineSimilarity(queryVector, memoryVector)
                scored.append((memory, similarity))
            } else {
                // Fallback score
                scored.append((memory, keywordScore(query: query, text: memory.value)))
            }
        }

        // Sort by similarity (descending)
        scored.sort { $0.1 > $1.1 }

        return scored.map { $0.0 }
    }

    private func keywordScore(query: String, text: String) -> Double {
        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))
        let textWords = Set(text.lowercased().split(separator: " ").map(String.init))
        let intersection = queryWords.intersection(textWords)
        return Double(intersection.count) / Double(max(queryWords.count, 1))
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }

        var dotProduct: Double = 0
        var normA: Double = 0
        var normB: Double = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }

    // MARK: - Forget Memory

    private func forgetMemory(_ args: [String: Any]) -> MCPResult {
        var removed = 0

        if let key = args["key"] as? String {
            if workingMemory.removeValue(forKey: key) != nil { removed += 1 }
            if sessionMemory.removeValue(forKey: key) != nil { removed += 1 }
            if projectMemory.removeValue(forKey: key) != nil { removed += 1 }
        }

        if let category = args["category"] as? String,
           let memCat = MemoryEntry.MemoryCategory(rawValue: category) {
            workingMemory = workingMemory.filter { $0.value.category != memCat }
            sessionMemory = sessionMemory.filter { $0.value.category != memCat }
            projectMemory = projectMemory.filter { $0.value.category != memCat }
        }

        if let olderThan = args["olderThan"] as? String {
            let date = parseRelativeDate(olderThan)
            workingMemory = workingMemory.filter { $0.value.createdAt > date }
            sessionMemory = sessionMemory.filter { $0.value.createdAt > date }
            projectMemory = projectMemory.filter { $0.value.createdAt > date }
        }

        persistProjectMemory()

        return .success(["removed": removed])
    }

    // MARK: - Analyze Context

    private func analyzeContext(_ args: [String: Any]) async -> MCPResult {
        guard let context = args["context"] as? String,
              let task = args["task"] as? String else {
            return .error("Missing context or task")
        }

        // Analyze relevance of context to task
        var analysis: [String: Any] = [:]

        // 1. Token estimation
        let estimatedTokens = context.count / 4 // Rough estimate

        // 2. Relevance scoring
        let relevantMemories = await semanticSearch(query: task, memories: Array(projectMemory.values))
        let relevanceScore = relevantMemories.isEmpty ? 0.5 : 1.0

        // 3. Identify key sections
        let keySections = identifyKeySections(context: context, task: task)

        // 4. Suggest optimizations
        var suggestions: [String] = []

        if estimatedTokens > 50000 {
            suggestions.append("Context is large (\(estimatedTokens) tokens). Consider summarizing.")
        }

        if relevanceScore < 0.7 {
            suggestions.append("Low task relevance. Some context may be unnecessary.")
        }

        analysis["estimatedTokens"] = estimatedTokens
        analysis["relevanceScore"] = relevanceScore
        analysis["keySections"] = keySections
        analysis["suggestions"] = suggestions

        return .success(analysis)
    }

    private func identifyKeySections(context: String, task: String) -> [[String: Any]] {
        // Split context into sections and score each
        let sections = context.components(separatedBy: "\n\n")
        var scored: [[String: Any]] = []

        for (index, section) in sections.enumerated() {
            let score = keywordScore(query: task, text: section)
            if score > 0.1 {
                scored.append([
                    "index": index,
                    "preview": String(section.prefix(100)),
                    "relevance": score
                ])
            }
        }

        return scored.sorted { ($0["relevance"] as? Double ?? 0) > ($1["relevance"] as? Double ?? 0) }
    }

    // MARK: - Optimize Context

    private func optimizeContext(_ args: [String: Any]) async -> MCPResult {
        let maxTokens = args["maxTokens"] as? Int ?? 100000
        let prioritize = args["prioritize"] as? [String] ?? []

        // Calculate current usage
        let workingTokens = estimateTokens(workingMemory)
        let sessionTokens = estimateTokens(sessionMemory)
        let projectTokens = estimateTokens(projectMemory)
        let totalTokens = workingTokens + sessionTokens + projectTokens

        var optimizations: [[String: Any]] = []

        if totalTokens > maxTokens {
            // Need to optimize

            // 1. Clear expired entries
            cleanExpired()
            optimizations.append(["action": "clean_expired", "saved": 0])

            // 2. Compress low-importance entries
            let compressed = compressLowImportance(threshold: 0.3)
            optimizations.append(["action": "compress_low_importance", "saved": compressed])

            // 3. Summarize old sessions
            let summarized = summarizeOldSessions()
            optimizations.append(["action": "summarize_old", "saved": summarized])
        }

        // Prioritize requested categories
        for category in prioritize {
            boostCategory(category)
        }

        return .success([
            "beforeTokens": totalTokens,
            "afterTokens": estimateTokens(workingMemory) + estimateTokens(sessionMemory) + estimateTokens(projectMemory),
            "optimizations": optimizations
        ])
    }

    // MARK: - Project Summary

    private func getProjectSummary(_ args: [String: Any]) async -> MCPResult {
        let depth = args["depth"] as? String ?? "standard"
        let focus = args["focus"] as? String

        var summary: [String: Any] = [:]

        // Load CLAUDE.md if available
        if let claudeMD = loadClaudeMD() {
            summary["projectContext"] = claudeMD
        }

        // Aggregate important memories
        let importantMemories = projectMemory.values
            .filter { $0.importance >= 0.7 }
            .sorted { $0.accessCount > $1.accessCount }

        switch depth {
        case "brief":
            summary["memories"] = importantMemories.prefix(5).map { $0.key }
        case "detailed":
            summary["memories"] = importantMemories.map { [
                "key": $0.key,
                "value": $0.value,
                "importance": $0.importance
            ]}
        default: // standard
            summary["memories"] = importantMemories.prefix(10).map { [
                "key": $0.key,
                "value": String($0.value.prefix(200))
            ]}
        }

        // Add patterns learned
        summary["patterns"] = projectMemory.values
            .filter { $0.category == .pattern }
            .map { $0.value }

        // Add known issues
        summary["issues"] = projectMemory.values
            .filter { $0.category == .issue && $0.importance > 0.5 }
            .map { $0.value }

        // Focus filtering
        if let focus = focus {
            summary = filterByFocus(summary, focus: focus)
        }

        return .success(summary)
    }

    // MARK: - Helper Functions

    private func updateAccessCount(_ key: String) {
        if var entry = workingMemory[key] {
            entry.accessedAt = Date()
            entry.accessCount += 1
            workingMemory[key] = entry
        }
        if var entry = sessionMemory[key] {
            entry.accessedAt = Date()
            entry.accessCount += 1
            sessionMemory[key] = entry
        }
        if var entry = projectMemory[key] {
            entry.accessedAt = Date()
            entry.accessCount += 1
            projectMemory[key] = entry
        }
    }

    private func estimateTokens(_ memory: [String: MemoryEntry]) -> Int {
        return memory.values.reduce(0) { $0 + $1.value.count / 4 }
    }

    private func cleanExpired() {
        workingMemory = workingMemory.filter { !$0.value.isExpired }
        sessionMemory = sessionMemory.filter { !$0.value.isExpired }
        projectMemory = projectMemory.filter { !$0.value.isExpired }
    }

    private func compressLowImportance(threshold: Double) -> Int {
        var saved = 0
        for (key, entry) in sessionMemory where entry.importance < threshold {
            // Compress value
            let compressed = String(entry.value.prefix(100))
            var updated = entry
            updated.value = compressed
            sessionMemory[key] = updated
            saved += entry.value.count - compressed.count
        }
        return saved / 4 // Approximate tokens
    }

    private func summarizeOldSessions() -> Int {
        // Summarize memories older than 7 days
        let weekAgo = Date().addingTimeInterval(-604800)
        var saved = 0

        for (key, entry) in sessionMemory where entry.createdAt < weekAgo {
            if entry.value.count > 500 {
                var updated = entry
                updated.value = String(entry.value.prefix(200)) + "... [summarized]"
                sessionMemory[key] = updated
                saved += entry.value.count - updated.value.count
            }
        }

        return saved / 4
    }

    private func boostCategory(_ category: String) {
        guard let memCat = MemoryEntry.MemoryCategory(rawValue: category) else { return }

        for (key, var entry) in projectMemory where entry.category == memCat {
            entry.importance = min(1.0, entry.importance + 0.2)
            projectMemory[key] = entry
        }
    }

    private func parseRelativeDate(_ relative: String) -> Date {
        switch relative {
        case "1h": return Date().addingTimeInterval(-3600)
        case "1d": return Date().addingTimeInterval(-86400)
        case "1w": return Date().addingTimeInterval(-604800)
        case "1m": return Date().addingTimeInterval(-2592000)
        default: return Date.distantPast
        }
    }

    private func loadClaudeMD() -> String? {
        let url = URL(fileURLWithPath: "CLAUDE.md")
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func filterByFocus(_ summary: [String: Any], focus: String) -> [String: Any] {
        var filtered = summary
        // Filter memories by focus keyword
        if let memories = summary["memories"] as? [[String: Any]] {
            filtered["memories"] = memories.filter {
                ($0["value"] as? String)?.lowercased().contains(focus.lowercased()) ?? false
            }
        }
        return filtered
    }

    private func persistProjectMemory() {
        // Save to disk
        let url = URL(fileURLWithPath: ".claude/memory.json")
        if let data = try? JSONEncoder().encode(projectMemory) {
            try? data.write(to: url)
        }
    }
}
```

## Memory Best Practices:

### 1. Importance Scoring
```
1.0 - Critical (breaking changes, security issues)
0.8 - High (architecture decisions, APIs)
0.6 - Medium (patterns, preferences)
0.4 - Low (temporary notes)
0.2 - Minimal (debug info)
```

### 2. TTL Guidelines
```
session  - Current task context
day      - Daily work items
week     - Sprint/feature context
month    - Project patterns
forever  - Core architecture, critical bugs
```

### 3. Category Usage
```
code       - Code snippets, examples
preference - User/project preferences
pattern    - Recurring patterns
issue      - Known issues, bugs
solution   - Solved problems
todo       - Pending tasks
```

## CCC Memory Philosophy:
- Daten minimierung (nur speichern was nötig)
- User Kontrolle (forget_memory)
- Transparenz (analyze_context zeigt was gespeichert)
- Dezentral (lokal gespeichert)
- Effizient (automatische Optimierung)
