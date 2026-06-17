//
//  ProfileLabel.swift
//  MenuBarFolder
//
//  Picks short, DISTINCT two-letter labels for browser profiles shown on the
//  menu-bar icon. Plain first-two-letters collide for names like
//  "ilya@ctrl8" / "ilya@wowcube" (both "il"); in that case it falls back to a
//  distinguishing token, yielding "ct" / "wo".
//

import Foundation

enum ProfileLabel {

    /// First two alphanumeric characters of a string (original case).
    private static func twoLetters(_ s: String) -> String {
        String(s.filter { $0.isLetter || $0.isNumber }.prefix(2))
    }

    /// Alphanumeric word tokens.
    private static func tokens(_ s: String) -> [String] {
        s.split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// Ordered label candidates for one name: each token's first two letters,
    /// then adjacent-token initials, then the whole-string prefix. If `drop`
    /// is given (the shared prefix others also produce), it's removed so the
    /// name is forced onto a distinguishing token.
    private static func candidates(_ name: String, drop: String?) -> [String] {
        var c: [String] = []
        let toks = tokens(name)
        for t in toks { c.append(String(t.prefix(2))) }
        if toks.count >= 2 {
            for i in 0..<(toks.count - 1) {
                if let a = toks[i].first, let b = toks[i + 1].first { c.append("\(a)\(b)") }
            }
        }
        c.append(twoLetters(name))

        var seen = Set<String>()
        var out: [String] = []
        for x in c where !x.isEmpty && seen.insert(x).inserted { out.append(x) }
        if let drop { out.removeAll { $0 == drop } }
        return out.isEmpty ? [twoLetters(name)] : out
    }

    /// Distinct two-letter labels aligned with `names`.
    static func distinct(_ names: [String]) -> [String] {
        var counts: [String: Int] = [:]
        for n in names { counts[twoLetters(n), default: 0] += 1 }

        var used = Set<String>()
        var result: [String] = []
        for name in names {
            let whole = twoLetters(name)
            let drop = (counts[whole] ?? 0) > 1 ? whole : nil
            let cands = candidates(name, drop: drop)
            let chosen = cands.first { !used.contains($0) } ?? cands.first ?? "?"
            used.insert(chosen)
            result.append(chosen)
        }
        return result
    }
}
