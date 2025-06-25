//
//  JustLockinApp.swift
//  JustLockin
//
//  Created by H470-088 on 17/6/25.
//

import SwiftUI

@main
struct JustLockInApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    Settings {
      SettingsView(viewModel: appDelegate.viewModel)
    }
  }
}
