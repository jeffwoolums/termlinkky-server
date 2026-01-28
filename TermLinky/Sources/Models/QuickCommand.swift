//
//  QuickCommand.swift
//  TermLinky
//
//  Quick commands for remote terminal execution.
//

import Foundation

struct QuickCommand: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var command: String
    var category: CommandCategory
    var icon: String
    var isBuiltIn: Bool
    var confirmBeforeRun: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        category: CommandCategory = .custom,
        icon: String = "terminal",
        isBuiltIn: Bool = false,
        confirmBeforeRun: Bool = false
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.category = category
        self.icon = icon
        self.isBuiltIn = isBuiltIn
        self.confirmBeforeRun = confirmBeforeRun
    }
}

// MARK: - Categories

enum CommandCategory: String, Codable, CaseIterable, Identifiable {
    case ai = "AI Agents"
    case git = "Git"
    case node = "Node.js"
    case python = "Python"
    case docker = "Docker"
    case system = "System"
    case files = "Files"
    case terminal = "Terminal"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .ai: return "brain.head.profile"
        case .git: return "arrow.triangle.branch"
        case .node: return "shippingbox"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .docker: return "cube.box"
        case .system: return "gearshape"
        case .files: return "folder"
        case .terminal: return "terminal"
        case .custom: return "star"
        }
    }
    
    var color: String {
        switch self {
        case .ai: return "purple"
        case .git: return "orange"
        case .node: return "green"
        case .python: return "blue"
        case .docker: return "cyan"
        case .system: return "gray"
        case .files: return "yellow"
        case .terminal: return "mint"
        case .custom: return "pink"
        }
    }
}

// MARK: - Built-in Commands

extension QuickCommand {
    static let builtInCommands: [QuickCommand] = [
        // AI Agents
        QuickCommand(name: "Claude Code", command: "claude", category: .ai, icon: "brain.head.profile", isBuiltIn: true),
        QuickCommand(name: "Claude (Continue)", command: "claude --continue", category: .ai, icon: "brain.head.profile", isBuiltIn: true),
        QuickCommand(name: "Codex", command: "codex", category: .ai, icon: "sparkles", isBuiltIn: true),
        QuickCommand(name: "Aider", command: "aider", category: .ai, icon: "wand.and.stars", isBuiltIn: true),
        
        // Git
        QuickCommand(name: "Status", command: "git status", category: .git, icon: "questionmark.circle", isBuiltIn: true),
        QuickCommand(name: "Pull", command: "git pull", category: .git, icon: "arrow.down.circle", isBuiltIn: true),
        QuickCommand(name: "Push", command: "git push", category: .git, icon: "arrow.up.circle", isBuiltIn: true),
        QuickCommand(name: "Log (10)", command: "git log --oneline -10", category: .git, icon: "list.bullet", isBuiltIn: true),
        QuickCommand(name: "Diff", command: "git diff", category: .git, icon: "arrow.left.arrow.right", isBuiltIn: true),
        QuickCommand(name: "Stash", command: "git stash", category: .git, icon: "tray.and.arrow.down", isBuiltIn: true),
        QuickCommand(name: "Stash Pop", command: "git stash pop", category: .git, icon: "tray.and.arrow.up", isBuiltIn: true),
        
        // Node.js
        QuickCommand(name: "npm install", command: "npm install", category: .node, icon: "shippingbox", isBuiltIn: true),
        QuickCommand(name: "npm run dev", command: "npm run dev", category: .node, icon: "play.fill", isBuiltIn: true),
        QuickCommand(name: "npm run build", command: "npm run build", category: .node, icon: "hammer", isBuiltIn: true),
        QuickCommand(name: "npm test", command: "npm test", category: .node, icon: "checkmark.circle", isBuiltIn: true),
        
        // Python
        QuickCommand(name: "Python REPL", command: "python3", category: .python, icon: "chevron.left.forwardslash.chevron.right", isBuiltIn: true),
        QuickCommand(name: "pip install -r", command: "pip install -r requirements.txt", category: .python, icon: "shippingbox", isBuiltIn: true),
        QuickCommand(name: "pytest", command: "pytest", category: .python, icon: "checkmark.circle", isBuiltIn: true),
        
        // Docker
        QuickCommand(name: "Docker PS", command: "docker ps", category: .docker, icon: "list.bullet.rectangle", isBuiltIn: true),
        QuickCommand(name: "Compose Up", command: "docker compose up -d", category: .docker, icon: "play.fill", isBuiltIn: true),
        QuickCommand(name: "Compose Down", command: "docker compose down", category: .docker, icon: "stop.fill", isBuiltIn: true, confirmBeforeRun: true),
        
        // System
        QuickCommand(name: "Disk Usage", command: "df -h", category: .system, icon: "externaldrive", isBuiltIn: true),
        QuickCommand(name: "Memory", command: "vm_stat | head -10", category: .system, icon: "memorychip", isBuiltIn: true),
        QuickCommand(name: "Processes", command: "ps aux | head -20", category: .system, icon: "cpu", isBuiltIn: true),
        QuickCommand(name: "Top", command: "top", category: .system, icon: "chart.bar", isBuiltIn: true),
        QuickCommand(name: "htop", command: "htop", category: .system, icon: "chart.bar.fill", isBuiltIn: true),
        
        // Files
        QuickCommand(name: "List Files", command: "ls -la", category: .files, icon: "list.bullet", isBuiltIn: true),
        QuickCommand(name: "Tree", command: "tree -L 2", category: .files, icon: "list.bullet.indent", isBuiltIn: true),
        QuickCommand(name: "Find Large", command: "find . -size +100M -type f", category: .files, icon: "magnifyingglass", isBuiltIn: true),
        
        // Terminal
        QuickCommand(name: "Clear", command: "clear", category: .terminal, icon: "xmark.circle", isBuiltIn: true),
        QuickCommand(name: "Exit", command: "exit", category: .terminal, icon: "rectangle.portrait.and.arrow.right", isBuiltIn: true, confirmBeforeRun: true),
        QuickCommand(name: "Tmux Sessions", command: "tmux list-sessions", category: .terminal, icon: "rectangle.split.3x1", isBuiltIn: true),
        QuickCommand(name: "New Tmux", command: "tmux new -s dev", category: .terminal, icon: "plus.rectangle", isBuiltIn: true),
    ]
}
