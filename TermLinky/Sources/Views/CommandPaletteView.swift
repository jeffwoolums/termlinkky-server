//
//  CommandPaletteView.swift
//  TermLinky
//
//  Quick command popup with categories and search.
//

import SwiftUI

struct CommandPaletteView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var connectionManager: ConnectionManager
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var confirmingCommand: QuickCommand?
    
    var filteredCommands: [(category: CommandCategory, commands: [QuickCommand])] {
        if searchText.isEmpty {
            return settingsManager.commandsByCategory
        }
        
        let search = searchText.lowercased()
        let filtered = settingsManager.filteredCommands.filter {
            $0.name.lowercased().contains(search) ||
            $0.command.lowercased().contains(search)
        }
        
        let grouped = Dictionary(grouping: filtered) { $0.category }
        return CommandCategory.allCases.compactMap { category in
            guard let commands = grouped[category], !commands.isEmpty else { return nil }
            return (category: category, commands: commands)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                    ForEach(filteredCommands, id: \.category) { group in
                        Section {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(group.commands) { command in
                                    CommandButton(command: command) {
                                        executeCommand(command)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } header: {
                            CategoryHeader(category: group.category)
                        }
                    }
                }
                .padding(.vertical)
            }
            .searchable(text: $searchText, prompt: "Search commands...")
            .navigationTitle("Commands")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Confirm", isPresented: .init(
                get: { confirmingCommand != nil },
                set: { if !$0 { confirmingCommand = nil } }
            )) {
                Button("Cancel", role: .cancel) { confirmingCommand = nil }
                Button("Run") {
                    if let cmd = confirmingCommand {
                        runCommand(cmd)
                    }
                }
            } message: {
                if let cmd = confirmingCommand {
                    Text("Run '\(cmd.command)'?")
                }
            }
        }
    }
    
    private func executeCommand(_ command: QuickCommand) {
        if command.confirmBeforeRun {
            confirmingCommand = command
        } else {
            runCommand(command)
        }
    }
    
    private func runCommand(_ command: QuickCommand) {
        if settingsManager.hapticFeedback {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        connectionManager.sendCommand(command.command)
        dismiss()
    }
}

// MARK: - Command Button

struct CommandButton: View {
    let command: QuickCommand
    let action: () -> Void
    
    var categoryColor: Color {
        switch command.category.color {
        case "purple": return .purple
        case "orange": return .orange
        case "green": return .green
        case "blue": return .blue
        case "cyan": return .cyan
        case "gray": return .gray
        case "yellow": return .yellow
        case "mint": return .mint
        case "pink": return .pink
        default: return .primary
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: command.icon)
                    .font(.title2)
                    .foregroundStyle(categoryColor)
                
                Text(command.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(command.command)
                    .font(.caption2)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Header

struct CategoryHeader: View {
    let category: CommandCategory
    
    var body: some View {
        HStack {
            Image(systemName: category.icon)
            Text(category.rawValue)
                .fontWeight(.semibold)
            Spacer()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Floating Command Button

struct FloatingCommandButton: View {
    @Binding var showingPalette: Bool
    let isConnected: Bool
    
    var body: some View {
        Button {
            showingPalette = true
        } label: {
            Image(systemName: "command")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(isConnected ? Color.green : Color.gray)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .disabled(!isConnected)
    }
}
