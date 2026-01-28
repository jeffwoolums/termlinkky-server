//
//  ANSIParser.swift
//  TermLinkky
//
//  Parses ANSI escape codes into styled segments.
//

import Foundation
import SwiftUI

struct ANSIParser {
    static func parse(_ text: String) -> [StyledSegment] {
        var segments: [StyledSegment] = []
        var currentText = ""
        var foreground: Color? = nil
        var background: Color? = nil
        var bold = false
        var italic = false
        var underline = false
        
        let pattern = "\u{001B}\\[([0-9;]*)m"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        var lastEnd = text.startIndex
        let nsText = text as NSString
        
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) ?? []
        
        for match in matches {
            let matchRange = Range(match.range, in: text)!
            let beforeText = String(text[lastEnd..<matchRange.lowerBound])
            
            if !beforeText.isEmpty {
                segments.append(StyledSegment(
                    text: beforeText,
                    foreground: foreground,
                    background: background,
                    bold: bold,
                    italic: italic,
                    underline: underline
                ))
            }
            
            // Parse codes
            if let codeRange = Range(match.range(at: 1), in: text) {
                let codes = text[codeRange].split(separator: ";").compactMap { Int($0) }
                
                for code in codes {
                    switch code {
                    case 0:
                        foreground = nil
                        background = nil
                        bold = false
                        italic = false
                        underline = false
                    case 1: bold = true
                    case 3: italic = true
                    case 4: underline = true
                    case 22: bold = false
                    case 23: italic = false
                    case 24: underline = false
                    case 30: foreground = .black
                    case 31: foreground = .red
                    case 32: foreground = .green
                    case 33: foreground = .yellow
                    case 34: foreground = .blue
                    case 35: foreground = .purple
                    case 36: foreground = .cyan
                    case 37: foreground = .white
                    case 39: foreground = nil
                    case 40: background = .black
                    case 41: background = .red
                    case 42: background = .green
                    case 43: background = .yellow
                    case 44: background = .blue
                    case 45: background = .purple
                    case 46: background = .cyan
                    case 47: background = .white
                    case 49: background = nil
                    case 90: foreground = .gray
                    case 91: foreground = Color(red: 1.0, green: 0.4, blue: 0.4)
                    case 92: foreground = Color(red: 0.4, green: 1.0, blue: 0.4)
                    case 93: foreground = Color(red: 1.0, green: 1.0, blue: 0.4)
                    case 94: foreground = Color(red: 0.4, green: 0.4, blue: 1.0)
                    case 95: foreground = Color(red: 1.0, green: 0.4, blue: 1.0)
                    case 96: foreground = Color(red: 0.4, green: 1.0, blue: 1.0)
                    case 97: foreground = .white
                    default: break
                    }
                }
            }
            
            lastEnd = matchRange.upperBound
        }
        
        let remaining = String(text[lastEnd...])
        if !remaining.isEmpty {
            segments.append(StyledSegment(
                text: remaining,
                foreground: foreground,
                background: background,
                bold: bold,
                italic: italic,
                underline: underline
            ))
        }
        
        return segments.isEmpty ? [StyledSegment(text: text)] : segments
    }
}
