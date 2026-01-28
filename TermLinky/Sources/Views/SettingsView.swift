//
//  SettingsView.swift
//  TermLinkky
//
//  App settings and command customization.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingCommandsEditor = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Terminal") {
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(settingsManager.fontSize))")
                            .foregroundStyle(.secondary)
                        Stepper("", value: $settingsManager.fontSize, in: 10...24, step: 1)
                            .labelsHidden()
                    }
                    
                    Toggle("Show Timestamps", isOn: $settingsManager.showTimestamps)
                }
                
                Section("Commands") {
                    Button {
                        showingCommandsEditor = true
                    } label: {
                        HStack {
                            Label("Quick Commands", systemImage: "command")
                            Spacer()
                            Text("\(settingsManager.quickCommands.count)")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    NavigationLink {
                        CategoryFilterView()
                    } label: {
                        Label("Category Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                
                Section("Behavior") {
                    Toggle("Haptic Feedback", isOn: $settingsManager.hapticFeedback)
                    Toggle("Auto-Reconnect", isOn: $settingsManager.autoReconnect)
                    Toggle("Keep Screen On", isOn: $settingsManager.keepScreenOn)
                }
                
                Section {
                    Button(role: .destructive) {
                        settingsManager.resetToDefaults()
                    } label: {
                        Label("Reset Commands to Default", systemImage: "arrow.counterclockwise")
                    }
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("TermLinkky - Remote terminal for developers")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingCommandsEditor) {
                CommandsEditorView()
            }
            .onChange(of: settingsManager.fontSize) { _, _ in
                settingsManager.saveSettings()
            }
        }
    }
}

// MARK: - Category Filter

struct CategoryFilterView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        List {
            ForEach(CommandCategory.allCases) { category in
                Toggle(isOn: Binding(
                    get: { settingsManager.enabledCategories.contains(category) },
                    set: { enabled in
                        if enabled {
                            settingsManager.enabledCategories.insert(category)
                        } else {
                            settingsManager.enabledCategories.remove(category)
                        }
                        settingsManager.saveSettings()
                    }
                )) {
                    Label(category.rawValue, systemImage: category.icon)
                }
            }
        }
        .navigationTitle("Categories")
    }
}

// MARK: - Commands Editor

struct CommandsEditorView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) var dismiss
    @State private var showingAddCommand = false
    @State private var editingCommand: QuickCommand?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(settingsManager.quickCommands) { command in
                    HStack {
                        Image(systemName: command.icon)
                            .foregroundStyle(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(command.name)
                                .font(.headline)
                            Text(command.command)
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if command.isBuiltIn {
                            Text("Built-in")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            settingsManager.removeQuickCommand(command)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            editingCommand = command
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                .onMove { from, to in
                    settingsManager.moveQuickCommand(from: from, to: to)
                }
                
                Section {
                    Button {
                        showingAddCommand = true
                    } label: {
                        Label("Add Command", systemImage: "plus.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Quick Commands")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddCommand) {
                AddCommandSheet()
            }
            .sheet(item: $editingCommand) { command in
                EditCommandSheet(command: command)
            }
        }
    }
}

// MARK: - Add Command Sheet

struct AddCommandSheet: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var command = ""
    @State private var category: CommandCategory = .custom
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Command", text: $command)
                    .fontDesign(.monospaced)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                Picker("Category", selection: $category) {
                    ForEach(CommandCategory.allCases) { cat in
                        Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                    }
                }
            }
            .navigationTitle("Add Command")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        settingsManager.addQuickCommand(QuickCommand(
                            name: name,
                            command: command,
                            category: category
                        ))
                        dismiss()
                    }
                    .disabled(name.isEmpty || command.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Command Sheet

struct EditCommandSheet: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) var dismiss
    let command: QuickCommand
    
    @State private var name = ""
    @State private var commandText = ""
    @State private var category: CommandCategory = .custom
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Command", text: $commandText)
                    .fontDesign(.monospaced)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                Picker("Category", selection: $category) {
                    ForEach(CommandCategory.allCases) { cat in
                        Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                    }
                }
            }
            .navigationTitle("Edit Command")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = command
                        updated.name = name
                        updated.command = commandText
                        updated.category = category
                        settingsManager.updateQuickCommand(updated)
                        dismiss()
                    }
                    .disabled(name.isEmpty || commandText.isEmpty)
                }
            }
            .onAppear {
                name = command.name
                commandText = command.command
                category = command.category
            }
        }
    }
}
