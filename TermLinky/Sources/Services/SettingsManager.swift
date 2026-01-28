//
//  SettingsManager.swift
//  TermLinkky
//
//  Manages app settings and quick commands.
//

import Foundation
import SwiftUI

struct AppSettings: Codable {
    var fontSize: CGFloat
    var fontFamily: String
    var showTimestamps: Bool
    var hapticFeedback: Bool
    var autoReconnect: Bool
    var keepScreenOn: Bool
    var enabledCategories: Set<CommandCategory>
}

@MainActor
class SettingsManager: ObservableObject {
    @Published var quickCommands: [QuickCommand] = []
    @Published var fontSize: CGFloat = 14
    @Published var fontFamily: String = "SF Mono"
    @Published var showTimestamps: Bool = false
    @Published var hapticFeedback: Bool = true
    @Published var autoReconnect: Bool = true
    @Published var keepScreenOn: Bool = true
    @Published var enabledCategories: Set<CommandCategory> = Set(CommandCategory.allCases)
    
    private let commandsKey = "quick_commands"
    private let settingsKey = "app_settings"
    
    init() {
        loadSettings()
        loadQuickCommands()
    }
    
    // MARK: - Quick Commands
    
    private func loadQuickCommands() {
        if let data = UserDefaults.standard.data(forKey: commandsKey),
           let decoded = try? JSONDecoder().decode([QuickCommand].self, from: data) {
            quickCommands = decoded
        } else {
            quickCommands = QuickCommand.builtInCommands
            saveQuickCommands()
        }
    }
    
    private func saveQuickCommands() {
        guard let encoded = try? JSONEncoder().encode(quickCommands) else { return }
        UserDefaults.standard.set(encoded, forKey: commandsKey)
    }
    
    func addQuickCommand(_ command: QuickCommand) {
        quickCommands.append(command)
        saveQuickCommands()
    }
    
    func removeQuickCommand(_ command: QuickCommand) {
        quickCommands.removeAll { $0.id == command.id }
        saveQuickCommands()
    }
    
    func updateQuickCommand(_ command: QuickCommand) {
        if let index = quickCommands.firstIndex(where: { $0.id == command.id }) {
            quickCommands[index] = command
            saveQuickCommands()
        }
    }
    
    func moveQuickCommand(from source: IndexSet, to destination: Int) {
        quickCommands.move(fromOffsets: source, toOffset: destination)
        saveQuickCommands()
    }
    
    func resetToDefaults() {
        quickCommands = QuickCommand.builtInCommands
        saveQuickCommands()
    }
    
    var filteredCommands: [QuickCommand] {
        quickCommands.filter { enabledCategories.contains($0.category) }
    }
    
    var commandsByCategory: [(category: CommandCategory, commands: [QuickCommand])] {
        let grouped = Dictionary(grouping: filteredCommands) { $0.category }
        return CommandCategory.allCases
            .filter { enabledCategories.contains($0) }
            .compactMap { category in
                guard let commands = grouped[category], !commands.isEmpty else { return nil }
                return (category: category, commands: commands)
            }
    }
    
    // MARK: - Settings
    
    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return
        }
        
        fontSize = settings.fontSize
        fontFamily = settings.fontFamily
        showTimestamps = settings.showTimestamps
        hapticFeedback = settings.hapticFeedback
        autoReconnect = settings.autoReconnect
        keepScreenOn = settings.keepScreenOn
        enabledCategories = settings.enabledCategories
    }
    
    func saveSettings() {
        let settings = AppSettings(
            fontSize: fontSize,
            fontFamily: fontFamily,
            showTimestamps: showTimestamps,
            hapticFeedback: hapticFeedback,
            autoReconnect: autoReconnect,
            keepScreenOn: keepScreenOn,
            enabledCategories: enabledCategories
        )
        
        guard let encoded = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(encoded, forKey: settingsKey)
    }
}
