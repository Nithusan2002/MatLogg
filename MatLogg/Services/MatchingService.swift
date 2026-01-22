import Foundation

struct MatchResult {
    let product: MatvaretabellenProduct
    let score: Double
}

final class MatchingService {
    func bestMatch(offProduct: Product, candidates: [MatvaretabellenProduct]) -> MatchResult? {
        var best: MatchResult?
        for candidate in candidates {
            let score = confidenceScore(offProduct: offProduct, candidate: candidate)
            if let currentBest = best {
                if score > currentBest.score {
                    best = MatchResult(product: candidate, score: score)
                }
            } else {
                best = MatchResult(product: candidate, score: score)
            }
        }
        return best
    }
    
    func confidenceScore(offProduct: Product, candidate: MatvaretabellenProduct) -> Double {
        let nameScore = nameSimilarity(offProduct.name, candidate.name)
        let categoryScore = categoryMatch(offProduct.category, candidate.category)
        let brandScore = brandMatch(offProduct.brand, candidate.brand)
        let keywordScore = keywordOverlap(offProduct.name, candidate.name)
        let energyPenalty = energyDeviationPenalty(offProduct.caloriesPer100g, candidate.caloriesPer100g)
        
        var score = 0.0
        score += nameScore * 0.5
        score += categoryScore * 0.2
        score += brandScore * 0.1
        score += keywordScore * 0.1
        score += (1.0 - energyPenalty) * 0.1
        
        return min(max(score, 0.0), 1.0)
    }
    
    private func nameSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let lhsTokens = tokenize(lhs)
        let rhsTokens = tokenize(rhs)
        guard !lhsTokens.isEmpty, !rhsTokens.isEmpty else { return 0 }
        let intersection = lhsTokens.intersection(rhsTokens).count
        let union = lhsTokens.union(rhsTokens).count
        return Double(intersection) / Double(union)
    }
    
    private func categoryMatch(_ lhs: String?, _ rhs: String?) -> Double {
        guard let lhs = lhs, let rhs = rhs else { return 0 }
        return normalize(lhs) == normalize(rhs) ? 1.0 : 0.0
    }
    
    private func brandMatch(_ lhs: String?, _ rhs: String?) -> Double {
        guard let lhs = lhs, let rhs = rhs else { return 0 }
        return normalize(lhs) == normalize(rhs) ? 1.0 : 0.0
    }
    
    private func keywordOverlap(_ lhs: String, _ rhs: String) -> Double {
        let keywords = ["skummet", "kakao", "protein", "proteinmelk", "lett", "lettmelk", "helmelk", "laktosefri", "yoghurt", "brød", "fullkorn"]
        let lhsTokens = tokenize(lhs)
        let rhsTokens = tokenize(rhs)
        let matches = keywords.filter { lhsTokens.contains($0) && rhsTokens.contains($0) }
        return matches.isEmpty ? 0.0 : 1.0
    }
    
    private func energyDeviationPenalty(_ lhs: Int, _ rhs: Int) -> Double {
        let maxValue = max(lhs, rhs)
        guard maxValue > 0 else { return 0 }
        let diff = abs(lhs - rhs)
        let ratio = Double(diff) / Double(maxValue)
        return min(max(ratio, 0.0), 1.0)
    }
    
    private func tokenize(_ text: String) -> Set<String> {
        let normalized = normalize(text)
        let tokens = normalized.split(separator: " ").map(String.init)
        return Set(tokens.filter { !$0.isEmpty })
    }
    
    private func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        let cleaned = String(allowed).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
