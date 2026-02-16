//
//  StringUtilities.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11.
//  Reusable string utilities for text manipulation and comparison
//

import Foundation

extension String {

  /// Calculate Levenshtein distance between two strings
  /// Used for fuzzy matching and approximate string comparison
  ///
  /// - Parameter other: The string to compare against
  /// - Returns: The minimum number of single-character edits (insertions, deletions, substitutions) required to change one string into the other
  ///
  /// - Complexity: O(m*n) where m and n are the lengths of the two strings
  ///
  /// - Example:
  ///   ```
  ///   "kitten".levenshteinDistance(to: "sitting") // Returns 3
  ///   ```
  nonisolated func levenshteinDistance(to other: String) -> Int {
    let s1Array = Array(self)
    let s2Array = Array(other)
    let m = s1Array.count
    let n = s2Array.count

    // Base cases
    if m == 0 { return n }
    if n == 0 { return m }

    // Create distance matrix
    var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

    // Initialize first column and row
    for i in 0...m {
      matrix[i][0] = i
    }

    for j in 0...n {
      matrix[0][j] = j
    }

    // Fill matrix using dynamic programming
    for i in 1...m {
      for j in 1...n {
        let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
        matrix[i][j] = min(
          min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),      // deletion, insertion
          matrix[i - 1][j - 1] + cost                            // substitution
        )
      }
    }

    return matrix[m][n]
  }
}
