import EventKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

fileprivate extension View {
  @ViewBuilder
  func onChangeCompat<Value: Equatable>(_ value: Value, publisher: Published<Value>.Publisher, perform: @escaping (Value) -> Void) -> some View {
    if #available(macOS 14, *) {
      self.onChange(of: value) { newValue in
        perform(newValue)
      }
    } else {
      self.onReceive(publisher.dropFirst()) { newValue in
        perform(newValue)
      }
    }
  }

  @ViewBuilder
  func onChangeCompat<Value>(_ publisher: Published<Value>.Publisher, perform: @escaping (Value) -> Void) -> some View {
    self.onReceive(publisher.dropFirst(), perform: perform)
  }
}

enum PreferenceTab {
  case general
  case reminders
  case timers
}

struct PreferencesView: View {
  @StateObject private var viewModel = PreferencesViewModel()
  @State private var selectedTab: PreferenceTab = .general
  @State private var hoverStates: [PreferenceTab: Bool] = [:]
  @State private var isShowingSoundImporter: Bool = false

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        ForEach(
          [
            (tab: PreferenceTab.general, icon: "gearshape", label: "General"),
            (
              tab: PreferenceTab.reminders, icon: "bell.fill",
              label: "Reminders"
            ),
            (tab: PreferenceTab.timers, icon: "timer", label: "Timers"),
          ], id: \.tab
        ) { tabInfo in
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
        }
      }
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
    .fileImporter(
      isPresented: $isShowingSoundImporter,
      allowedContentTypes: SoundManager.shared.allowedExtensions.compactMap {
        UTType(filenameExtension: $0)
      }
    ) { result in
      switch result {
      case .success(let url):
        viewModel.storeCustomAlarmSound(url: url)
      case .failure(let error):
        print("File import failed: \(error)")
      }
    }
    .onChangeCompat(viewModel.allowReminders, publisher: viewModel.$allowReminders) { newValue in
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
            .onChangeCompat(viewModel.startAtLogin, publisher: viewModel.$startAtLogin) { _ in
              viewModel.savePreferences()
            }
        }
        SettingsRow(
          title: "Show next timer in menu bar",
          helpText: "Shows the next timer in the menu bar. Replaces Icon"
        ) {
          Toggle("", isOn: $viewModel.showNextTimerInMenuBar)
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            .frame(width: 40)
            .onChangeCompat(viewModel.showNextTimerInMenuBar, publisher: viewModel.$showNextTimerInMenuBar) { _ in
              viewModel.savePreferences()
            }
        }
        SettingsRow(
          title: "Alternative Menu Bar Icon",
          helpText: "Changes the menu bar icon to a different style."
        ) {
          Toggle("", isOn: $viewModel.useAlternativeMenuBarIcon)
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            .frame(width: 40)
            .onChangeCompat(viewModel.useAlternativeMenuBarIcon, publisher: viewModel.$useAlternativeMenuBarIcon) { _ in
              viewModel.savePreferences()
            }
        }
        SettingsRow(
          title: "Custom Menu Bar Text",
          helpText: "Changes the menu bar icon to text."
        ) {
          Toggle("", isOn: $viewModel.useCustomMenuBarIcon)
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            .frame(width: 40)
            .onChangeCompat(viewModel.useCustomMenuBarIcon, publisher: viewModel.$useCustomMenuBarIcon) { _ in
              viewModel.savePreferences()
            }
        }
        if viewModel.useCustomMenuBarIcon {
          SettingsRow(
            title: "Custom Menu Bar Text",
            helpText: "Enter custom text for the menu bar icon."
          ) {
            TextField("Enter text", text: $viewModel.customMenuBarWord)
              .textFieldStyle(RoundedBorderTextFieldStyle())
              .frame(width: 100)
              .onChangeCompat(viewModel.customMenuBarWord, publisher: viewModel.$customMenuBarWord) { _ in
                viewModel.savePreferences()
              }
          }
        }
        SettingsRow(
          title: "Custom Menu Bar Symbol",
          helpText: "Changes the menu bar icon to a custom SF Symbol."
        ) {
          Toggle("", isOn: $viewModel.useCustomMenuBarSymbol)
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            .frame(width: 40)
            .onChangeCompat(viewModel.useCustomMenuBarSymbol, publisher: viewModel.$useCustomMenuBarSymbol) { _ in
              viewModel.savePreferences()
            }
        }
        if viewModel.useCustomMenuBarSymbol {
          SettingsRow(
            title: "Custom Menu Bar Symbol Name",
            helpText: "Enter the name of the SF Symbol."
          ) {
            TextField("Enter text", text: $viewModel.customMenuBarSymbol)
              .textFieldStyle(RoundedBorderTextFieldStyle())
              .frame(width: 100)
              .onChangeCompat(viewModel.customMenuBarSymbol, publisher: viewModel.$customMenuBarSymbol) { _ in
                viewModel.savePreferences()
              }
          }
        }
      }
      .padding(.top, 10)

      SettingsSection(title: "View") {
        SettingsRow(
          title: "Show time in minutes only",
          helpText:
            "When enabled, the time will be shown in minutes only and not be formatet to hours and minutes"
        ) {
          Toggle("", isOn: $viewModel.viewAsMinutes)
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            .frame(width: 40)
            .onChangeCompat(viewModel.viewAsMinutes, publisher: viewModel.$viewAsMinutes) { _ in
              viewModel.savePreferences()
            }
        }
        SettingsRow(
          title: "Show Rubberband",
          helpText:
            "When enabled, a rubberband will be shown from the menubar icon to the mouse cursor"
        ) {
          Toggle("", isOn: $viewModel.showDragIndicator)
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            .frame(width: 40)
            .onChangeCompat(viewModel.showDragIndicator, publisher: viewModel.$showDragIndicator) { _ in
              viewModel.savePreferences()
            }
        }
        if viewModel.showDragIndicator {
          HStack {
            SettingsRow(
              title: "Change Rubberband Color",
              helpText: "When enabled, a rubberband can be manually set"
            ) {
              Toggle("", isOn: $viewModel.changeRubberbandColor)
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
                .frame(width: 40)
                .onChangeCompat(viewModel.changeRubberbandColor, publisher: viewModel.$changeRubberbandColor) { _ in
                  viewModel.savePreferences()
                }
            }
          }
          if viewModel.changeRubberbandColor {
            HStack {
              SettingsRow(
                title: "Rubberband Color",
                helpText: "Select the color of the rubberband."
              ) {
                ColorPicker("", selection: $viewModel.dragLineColor)
                  .frame(width: 40, alignment: .trailing)
              }
            }
          }
        }

      }
    }
  }

  var reminderSettingsView: some View {
    VStack(spacing: 20) {
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
            .onChangeCompat(viewModel.allowReminders, publisher: viewModel.$allowReminders) { _ in
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
          .onChangeCompat(viewModel.$selectedList) { _ in
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
            .onChangeCompat(viewModel.deleteReminders, publisher: viewModel.$deleteReminders) { _ in
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
            .onChangeCompat(viewModel.ignoreShortTimers, publisher: viewModel.$ignoreShortTimers) { _ in
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
            .onChangeCompat(viewModel.shortTimerThresholdMinutes, publisher: viewModel.$shortTimerThresholdMinutes) { _ in
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
          helpText:
            "When enabled, you can enter custom names for your timers while creating them."
        ) {
          Toggle("", isOn: $viewModel.allowCustomNames)
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            .frame(width: 40)
            .onChangeCompat(viewModel.allowCustomNames, publisher: viewModel.$allowCustomNames) { _ in
              viewModel.savePreferences()
            }
        }

        Divider()

        SettingsRow(
            title: "Play Alarm Sound",
            helpText:
              "When enabled, Dropclock plays an alarm sound as soon as a timer finishes."
          ) {
            Toggle("", isOn: $viewModel.playAlarmSound)
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            .frame(width: 40)
            .onChangeCompat(viewModel.playAlarmSound, publisher: viewModel.$playAlarmSound) { _ in
              viewModel.savePreferences()
            }
        }

        if viewModel.playAlarmSound {
          SettingsRow(
            title: "Keep playing until manually stopped",
            helpText:
              "Loops the alarm and keeps the finished timer in the list until you remove it."
          ) {
            Toggle("", isOn: $viewModel.loopAlarmUntilStopped)
              .toggleStyle(SwitchToggleStyle())
              .labelsHidden()
              .frame(width: 40)
              .onChangeCompat(viewModel.loopAlarmUntilStopped, publisher: viewModel.$loopAlarmUntilStopped) { _ in
                viewModel.savePreferences()
              }
          }

          SettingsRow(
            title: "Alarm Sound File",
            helpText:
              "Select one of the .mp3/.wav files that are part of the app."
          ) {
            VStack(alignment: .trailing, spacing: 6) {
              Toggle("Use custom sound file", isOn: $viewModel.useCustomAlarmSound)
                .toggleStyle(SwitchToggleStyle())
                .frame(width: 220, alignment: .trailing)
                .onChangeCompat(viewModel.useCustomAlarmSound, publisher: viewModel.$useCustomAlarmSound) { _ in
                  viewModel.savePreferences()
                }

              if viewModel.useCustomAlarmSound {
                HStack {
                  Text(
                    viewModel.customAlarmSoundName.isEmpty
                      ? "No file selected"
                      : viewModel.customAlarmSoundName
                  )
                  .foregroundColor(.secondary)
                  .lineLimit(1)
                  Button("Choose File…") {
                    isShowingSoundImporter = true
                  }
                }
              } else {
                if viewModel.availableAlarmSounds.isEmpty {
                  Text("No sound files found")
                    .foregroundColor(.secondary)
                    .frame(width: 180, alignment: .trailing)
                } else {
                  Picker("", selection: $viewModel.selectedAlarmSound) {
                    ForEach(viewModel.availableAlarmSounds, id: \.self) { sound in
                      Text(viewModel.displayName(for: sound)).tag(sound)
                    }
                  }
                  .pickerStyle(MenuPickerStyle())
                  .frame(width: 180, alignment: .trailing)
                  .onChangeCompat(viewModel.selectedAlarmSound, publisher: viewModel.$selectedAlarmSound) { _ in
                    viewModel.savePreferences()
                  }
                }
              }
            }
          }

          Divider()
        }

        SettingsRow(
          title: "Enable 5 Minute Mode",
          helpText:
            "When enabled, dragging while CTRL-Key is held down will increase in 5 minute increments."
        ) {
          Toggle("", isOn: $viewModel.allowFiveMinuteMode)
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            .frame(width: 40)
            .onChangeCompat(viewModel.allowFiveMinuteMode, publisher: viewModel.$allowFiveMinuteMode) { _ in
              viewModel.savePreferences()
            }
        }

        Divider()

        SettingsRow(
          title: "Enable Seconds Mode",
          helpText:
            "When enabled, dragging while Shift-Key is held down will only increment in seconds."
        ) {
          Toggle("", isOn: $viewModel.allowSecondsMode)
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            .frame(width: 40)
            .onChangeCompat(viewModel.allowSecondsMode, publisher: viewModel.$allowSecondsMode) { _ in
              viewModel.savePreferences()
            }
        }
      }
      .padding(.bottom, 20)
    }
  }
}
