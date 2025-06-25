import SwiftUI

struct SettingsView: View {
  @ObservedObject var viewModel: JustLockInViewModel
  @State private var showResetConfirmation = false

  var body: some View {
    Form {
      Section(header: Text("Timer Durations (minutes)")) {
        durationPicker(for: "Work session", duration: $viewModel.settings.workSessionDuration)
        durationPicker(for: "Short break", duration: $viewModel.settings.shortBreakDuration)
        durationPicker(for: "Long break", duration: $viewModel.settings.longBreakDuration)
      }

      Section("") {
        HStack {
          Text("Sessions before long break")
          TextField(
            "",
            value: $viewModel.settings.sessionsBeforeLongBreak,
            formatter: viewModel.sessionsFormatter
          )
        }

        Toggle("Enable overflow mode", isOn: $viewModel.settings.enableOverflowMode)

        if !viewModel.settings.enableOverflowMode {
          Text("When disabled, work sessions will immediately switch to break sessions")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 2)
            .fixedSize(horizontal: false, vertical: true)
        }

        Toggle("Auto-start sessions", isOn: $viewModel.settings.enableAutoStart)

        Toggle("Enable Notifications", isOn: $viewModel.settings.enableNotifications)
          .onChange(of: viewModel.settings.enableNotifications) { isEnabled in
            viewModel.notificationSettingChanged(isEnabled: isEnabled)
          }

        Toggle("Enable Sound Notifications", isOn: $viewModel.settings.enableSoundNotifications)
          .disabled(!viewModel.settings.enableNotifications)

        if viewModel.settings.enableNotifications && !viewModel.settings.enableSoundNotifications {
          Text("Sound notifications are disabled. Only visual notifications will be shown.")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 2)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      Section {
        Button("Reset to Defaults") {
          showResetConfirmation = true
        }
        .foregroundColor(.red)
        .frame(maxWidth: .infinity, alignment: .center)
      }
    }
    .frame(width: 350)
    .padding()
    .alert("Reset Settings", isPresented: $showResetConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Reset", role: .destructive) {
        viewModel.resetSettingsToDefaults()
      }
    } message: {
      Text(
        "This will reset all timer durations and settings to their default values. The welcome alert will also be shown again on next app launch. This action cannot be undone."
      )
    }
    .alert("Notifications Disabled", isPresented: $viewModel.shouldShowPermissionAlert) {
      Button("OK") {
        viewModel.shouldShowPermissionAlert = false
      }
    } message: {
      Text(
        "Notifications have been disabled. To enable them, please go to System Settings > Notifications > JustLockIn and allow notifications."
      )
    }
  }

  private func durationPicker(for label: String, duration: Binding<TimeInterval>) -> some View {
    let binding = Binding<Double>(
      get: { duration.wrappedValue / 60 },
      set: { duration.wrappedValue = $0 * 60 }
    )

    return HStack {
      Text(label)
      TextField("", value: binding, formatter: viewModel.durationFormatter)

    }
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView(viewModel: JustLockInViewModel())
  }
}
