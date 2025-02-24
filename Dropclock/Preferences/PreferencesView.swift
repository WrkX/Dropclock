import EventKit
import SwiftUI

struct PreferencesView: View {
  @StateObject private var viewModel = PreferencesViewModel()

  var body: some View {
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
      }.padding(.top, 10)

      SettingsSection(title: "Reminders") {
        SettingsRow(
          title: "Allow Reminders",
          helpText:
            "When enabled, Dropclock will create reminders in the Apple Reminders app for each timer created. Reminders will always be rounded to the next minute due to how reminders work."
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
          helpText:
            "When enabled, reminders created by the app will be deleted if their corresponding timer entry is deleted."
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
            .onChange(of: viewModel.allowReminders) {
              viewModel.savePreferences()
            }
        }
        if viewModel.ignoreShortTimers && viewModel.allowReminders {  // Conditionally show slider

          HStack {
            Slider(
              value: $viewModel.shortTimerThresholdMinutes,
              in: 1...60,  // Range from 1 to 60 minutes
              step: 1
            )
            .frame(width: 250, alignment: .leading)
            .padding(.bottom, 15)
            .onChange(of: viewModel.shortTimerThresholdMinutes) {  // ADD THIS .onChange MODIFIER
              viewModel.savePreferences()  // Call savePreferences when slider changes
            }
            Text("\(Int(viewModel.shortTimerThresholdMinutes)) min")  // Display current value
              .frame(width: 50, alignment: .trailing)
          }

        }

      }

      SettingsSection(title: "Timers") {
        SettingsRow(
          title: "Custom Timer Names",
          helpText:
            "When enabled, you can enter custom names for your timers while creating them."
        ) {
          Toggle("", isOn: $viewModel.allowCustomNames)
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            .frame(width: 40)
            .onChange(of: viewModel.allowCustomNames) {
              viewModel.savePreferences()
            }
        }
      }
      .padding(.bottom, 20)
    }
    .padding()
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
}
