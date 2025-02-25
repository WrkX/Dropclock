import SwiftUI
import EventKit

enum PreferenceTab {
    case general
    case reminders
    case timers
}

struct PreferencesView: View {
    @StateObject private var viewModel = PreferencesViewModel()
    @State private var selectedTab: PreferenceTab = .general
    @State private var hoverStates: [PreferenceTab: Bool] = [:]
  
    var body: some View {
        VStack(spacing: 0) {
          HStack(spacing: 0) {
            ForEach([
              (tab: PreferenceTab.general, icon: "gearshape", label: "General"),
              (tab: PreferenceTab.reminders, icon: "bell.fill", label: "Reminders"),
              (tab: PreferenceTab.timers, icon: "timer", label: "Timers")
            ], id: \.tab) { tabInfo in
              Button {
                selectedTab = tabInfo.tab
              } label: {
                ZStack {
                  Color.clear
                    .contentShape(Rectangle())
                    .overlay(
                      Group {
                        if hoverStates[tabInfo.tab] ?? false {
                          Color.gray.opacity(0.1)
                        } else if selectedTab == tabInfo.tab {
                          Color.blue.opacity(0.2)
                        } else {
                          Color.clear
                        }
                      }
                    )
                  
                  VStack(spacing: 4) {
                    Image(systemName: tabInfo.icon)
                      .font(.system(size: 16))
                    Text(tabInfo.label)
                      .font(.system(size: 10))
                  }
                  .padding(.vertical, 8)
                }
                .frame(height: 50)
                .frame(minWidth: 60)
                .foregroundColor(selectedTab == tabInfo.tab ? .blue : .gray)
              }
              .buttonStyle(BorderlessButtonStyle())
              .cornerRadius(8)
              .onHover { hover in
                hoverStates[tabInfo.tab] = hover
              }
            }}
            .padding(.horizontal)
            .padding(.top)
            ScrollView {
                VStack {
                    switch selectedTab {
                    case .general:
                        generalSettingsView
                    case .reminders:
                        reminderSettingsView
                    case .timers:
                        timerSettingsView
                    }
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.loadPreferences()
        }
        .onChange(of: viewModel.allowReminders) { _, newValue in
            if newValue {
                Task {
                    await viewModel.ensureReminderAccess()
                }
            }
        }
    }
    
    var generalSettingsView: some View {
        VStack(spacing: 20) {
            SettingsSection(title: "General") {
                SettingsRow(
                    title: "Start at Login",
                    helpText: "Automatically start Dropclock when you log in to your Mac."
                ) {
                    Toggle("", isOn: $viewModel.startAtLogin)
                        .toggleStyle(SwitchToggleStyle())
                        .labelsHidden()
                        .frame(width: 40)
                        .onChange(of: viewModel.startAtLogin) {
                            viewModel.savePreferences()
                        }
                }
            }
            .padding(.top, 10)
        }
    }
    
    var reminderSettingsView: some View {
        VStack(spacing: 20) {
            SettingsSection(title: "Reminders") {
                SettingsRow(
                    title: "Allow Reminders",
                    helpText: "When enabled, Dropclock will create reminders in the Apple Reminders app for each timer created. Reminders will always be rounded to the next minute due to how reminders work."
                ) {
                    Toggle("", isOn: $viewModel.allowReminders)
                        .toggleStyle(SwitchToggleStyle())
                        .labelsHidden()
                        .frame(width: 40)
                        .onChange(of: viewModel.allowReminders) {
                            viewModel.savePreferences()
                        }
                }
                
                Divider()
                
                SettingsRow(
                    title: "Reminder List",
                    helpText: "Choose the list where reminders will be created."
                ) {
                    Picker("", selection: $viewModel.selectedList) {
                        ForEach(viewModel.reminderLists, id: \.self) { list in
                            Text(list.title).tag(list as EKCalendar?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 140, alignment: .trailing)
                    .disabled(!viewModel.allowReminders)
                    .onChange(of: viewModel.selectedList) {
                        viewModel.savePreferences()
                    }
                }
                
                Divider()
                
                SettingsRow(
                    title: "Delete Reminders",
                    helpText: "When enabled, reminders created by the app will be deleted if their corresponding timer entry is deleted."
                ) {
                    Toggle("", isOn: $viewModel.deleteReminders)
                        .toggleStyle(SwitchToggleStyle())
                        .labelsHidden()
                        .frame(width: 40)
                        .disabled(!viewModel.allowReminders)
                        .onChange(of: viewModel.deleteReminders) {
                            viewModel.savePreferences()
                        }
                }
                
                Divider()
                
                SettingsRow(
                    title: "Ignore Short Timers",
                    helpText: "When enabled, short timers will not be created as Reminder"
                ) {
                    Toggle("", isOn: $viewModel.ignoreShortTimers)
                        .toggleStyle(SwitchToggleStyle())
                        .labelsHidden()
                        .frame(width: 40)
                        .disabled(!viewModel.allowReminders)
                        .onChange(of: viewModel.ignoreShortTimers) {
                            viewModel.savePreferences()
                        }
                }
                
                if viewModel.ignoreShortTimers && viewModel.allowReminders {
                    HStack {
                        Slider(
                            value: $viewModel.shortTimerThresholdMinutes,
                            in: 1...60,
                            step: 1
                        )
                        .frame(width: 250, alignment: .leading)
                        .padding(.bottom, 15)
                        .onChange(of: viewModel.shortTimerThresholdMinutes) {
                            viewModel.savePreferences()
                        }
                        Text("\(Int(viewModel.shortTimerThresholdMinutes)) min")
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
        }
    }
    
    var timerSettingsView: some View {
        VStack(spacing: 20) {
            SettingsSection(title: "Timers") {
                SettingsRow(
                    title: "Custom Timer Names",
                    helpText: "When enabled, you can enter custom names for your timers while creating them."
                ) {
                    Toggle("", isOn: $viewModel.allowCustomNames)
                        .toggleStyle(SwitchToggleStyle())
                        .labelsHidden()
                        .frame(width: 40)
                        .onChange(of: viewModel.allowCustomNames) {
                            viewModel.savePreferences()
                        }
                }
                
                Divider()
                
                SettingsRow(
                    title: "Enable 5 Minute Mode",
                    helpText: "When enabled, dragging while CTRL-Key is held down will increase in 5 minute increments."
                ) {
                    Toggle("", isOn: $viewModel.allowFiveMinuteMode)
                        .toggleStyle(SwitchToggleStyle())
                        .labelsHidden()
                        .frame(width: 40)
                        .onChange(of: viewModel.allowFiveMinuteMode) {
                            viewModel.savePreferences()
                        }
                }
                
                Divider()
                
                SettingsRow(
                    title: "Enable Seconds Mode",
                    helpText: "When enabled, dragging while Shift-Key is held down will only increment in seconds."
                ) {
                    Toggle("", isOn: $viewModel.allowSecondsMode)
                        .toggleStyle(SwitchToggleStyle())
                        .labelsHidden()
                        .frame(width: 40)
                        .onChange(of: viewModel.allowSecondsMode) {
                            viewModel.savePreferences()
                        }
                }
            }
            .padding(.bottom, 20)
        }
    }
}
