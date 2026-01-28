//
//  TerminalLine.swift
//  TermLinky
//
//  Represents a line of terminal output with ANSI styling.
//

import Foundation
import SwiftUI

struct TerminalLine: Identifiable, Equatable {
    let id: UUID
    let text: String
    let timestamp: Date
    let segments: [StyledSegment]
    
    init(text: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.segments = ANSIParser.parse(text)
    }
}

struct StyledSegment: Equatable {
    let text: String
    let foreground: Color?
    let background: Color?
    let bold: Bool
    let italic: Bool
    let underline: Bool
    
    init(
        text: String,
        foreground: Color? = nil,
        background: Color? = nil,
        bold: Bool = false,
        italic: Bool = false,
        underline: Bool = false
    ) {
        self.text = text
        self.foreground = foreground
        self.background = background
        self.bold = bold
        self.italic = italic
        self.underline = underline
    }
}
