import Foundation

/// Human-friendly ("natural") string ordering, shared by the library sort and the reader's
/// next-chapter lookup so "Chapter 2" sorts before "Chapter 10".
public enum NaturalOrder {
    /// Compare two strings in natural order: runs of digits compare by numeric value, everything
    /// else case-insensitively character by character. Leading zeros don't flip the order; ties
    /// fall back to a plain case-insensitive comparison for stability.
    public static func compare(_ a: String, _ b: String) -> Int {
        let ac = Array(a)
        let bc = Array(b)
        var i = 0
        var j = 0
        while i < ac.count && j < bc.count {
            let ca = ac[i]
            let cb = bc[j]
            if ca.isNumber && cb.isNumber {
                var startA = i
                var startB = j
                while i < ac.count && ac[i].isNumber { i += 1 }
                while j < bc.count && bc[j].isNumber { j += 1 }
                while startA < i - 1 && ac[startA] == "0" { startA += 1 }
                while startB < j - 1 && bc[startB] == "0" { startB += 1 }
                let lenA = i - startA
                let lenB = j - startB
                if lenA != lenB { return lenA - lenB }
                for k in 0..<lenA {
                    let d = Int(ac[startA + k].asciiValue ?? 0) - Int(bc[startB + k].asciiValue ?? 0)
                    if d != 0 { return d }
                }
            } else {
                let la = Character(ca.lowercased())
                let lb = Character(cb.lowercased())
                if la != lb {
                    return la < lb ? -1 : 1
                }
                i += 1
                j += 1
            }
        }
        let rem = (ac.count - i) - (bc.count - j)
        if rem != 0 { return rem }
        return a.lowercased() == b.lowercased() ? 0 : (a.lowercased() < b.lowercased() ? -1 : 1)
    }

    /// Whether `a` sorts before `b` in natural order.
    public static func less(_ a: String, _ b: String) -> Bool {
        compare(a, b) < 0
    }
}
