import Cocoa
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
	private var statusItem: NSStatusItem!
	let viewModel: JustLockInViewModel
	private var cancellables = Set<AnyCancellable>()
	private var settingsWindow: NSWindow?
	private var iconView: NSHostingView<StatusBarIconView>?
	
	override init() {
		viewModel = JustLockInViewModel()
		super.init()
		
		// Hide dock icon immediately upon initialization
		NSApp.setActivationPolicy(.accessory)
	}
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Ensure dock icon remains hidden
		NSApp.setActivationPolicy(.accessory)
		
		// Prevent automatic termination and App Nap
		NSApp.disableRelaunchOnLogin()
		
		// Prevent the system from putting the app to sleep
		if #available(macOS 10.9, *) {
			ProcessInfo.processInfo.disableAutomaticTermination("Timer is running")
		}
		
		if let icon = NSImage(named: "AppIcon") {
			// Set it as the application's icon.
			// This will be used by the Dock and other system services like Mission Control.
			NSApplication.shared.applicationIconImage = icon
		}
		
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		
		// Set up callback for status updates
		viewModel.onStatusUpdate = { [weak self] in
			self?.updateStatusItem()
		}
		
		// Observe for permission alert requests
		viewModel.$shouldShowPermissionAlert
			.sink { [weak self] shouldShow in
				if shouldShow {
					self?.showPermissionAlert()
					self?.viewModel.shouldShowPermissionAlert = false
				}
			}
			.store(in: &cancellables)
		
		updateStatusItem()
		
		if let button = statusItem.button {
			button.action = #selector(statusBarButtonTapped(sender:))
			button.sendAction(on: [.leftMouseUp, .rightMouseUp])
		}
		
		// Show welcome alert for new users
		if viewModel.settings.showWelcomeAlert {
			// Delay the alert slightly to ensure the app is fully loaded
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
				self.showWelcomeAlert()
			}
		}
	}
	
	private func showPermissionAlert() {
		let alert = NSAlert()
		alert.messageText = "Notifications Disabled"
		alert.informativeText =
		"You have disabled notifications for JustLockIn. To receive session alerts, please enable them in System Settings > Notifications."
		alert.addButton(withTitle: "Open Settings")
		alert.addButton(withTitle: "OK")
		alert.alertStyle = .warning
		
		if alert.runModal() == .alertFirstButtonReturn {
			NSWorkspace.shared.open(
				URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
		}
		
		// Ensure dock icon remains hidden after showing alert
		NSApp.setActivationPolicy(.accessory)
	}
	
	private func updateStatusItem() {
		DispatchQueue.main.async { [weak self] in
			guard let self = self, let button = self.statusItem.button else { return }
			
			// Create iconView only once, then update its content
			if self.iconView == nil {
				let statusBarView = StatusBarIconView(
					timeString: self.viewModel.formattedTimeString,
					progress: self.viewModel.progress,
					sessionType: self.viewModel.currentSessionType,
					timerState: self.viewModel.timerState
				)
				self.iconView = NSHostingView(rootView: statusBarView)
				self.iconView!.frame = NSRect(x: 0, y: 0, width: 70, height: 22)
				button.addSubview(self.iconView!)
				button.frame = self.iconView!.frame
			} else {
				let updatedStatusBarView = StatusBarIconView(
					timeString: self.viewModel.formattedTimeString,
					progress: self.viewModel.progress,
					sessionType: self.viewModel.currentSessionType,
					timerState: self.viewModel.timerState
				)
				self.iconView!.rootView = updatedStatusBarView
			}
			
			let sessionName: String
			switch self.viewModel.currentSessionType {
			case .work:
				sessionName = "Work"
			case .shortBreak, .longBreak:
				sessionName = "Break"
			case .overflow:
				sessionName = "Overflow"
			}
			
			let timeDescription = self.viewModel.currentSessionType == .overflow ? "elapsed" : "remaining"
			button.setAccessibilityLabel(
				"\(sessionName) session: \(self.viewModel.formattedTimeString) \(timeDescription)")
		}
	}
	
	@objc func statusBarButtonTapped(sender: NSStatusBarButton) {
		guard let event = NSApp.currentEvent else { return }
		
		if event.type == .rightMouseUp
			|| (event.modifierFlags.contains(.control) && event.type == .leftMouseUp)
		{
			showContextMenu()
		} else if event.type == .leftMouseUp {
			// Smart one-tap behavior based on current state
			if viewModel.currentSessionType == .overflow {
				// In overflow mode: One tap = Start Break (most common action)
				skipSession()
			} else {
				// In other modes: One tap = Start/Pause
				primaryAction()
			}
		}
	}
	
	private func showContextMenu() {
		let menu = NSMenu()
		
		let progressText =
		"\(viewModel.completedWorkSessions % viewModel.settings.sessionsBeforeLongBreak) of \(viewModel.settings.sessionsBeforeLongBreak) sessions complete"
		let progressMenuItem = NSMenuItem(title: progressText, action: nil, keyEquivalent: "")
		progressMenuItem.isEnabled = false
		menu.addItem(progressMenuItem)
		menu.addItem(NSMenuItem.separator())
		
		let hintMenuItem = NSMenuItem(
			title: "👆 \(viewModel.primaryActionHint)", action: nil, keyEquivalent: "")
		hintMenuItem.isEnabled = false
		menu.addItem(hintMenuItem)
		menu.addItem(NSMenuItem.separator())
		
		if viewModel.currentSessionType == .overflow {
			menu.addItem(withTitle: "Continue overflow", action: nil, keyEquivalent: "")
			menu.addItem(withTitle: "Restart All", action: #selector(restartAll), keyEquivalent: "")
		} else {
			let primaryActionTitle = viewModel.timerState == .running ? "Pause" : "Start"
			menu.addItem(
				withTitle: primaryActionTitle, action: #selector(primaryAction), keyEquivalent: "")
			menu.addItem(withTitle: "Skip session", action: #selector(skipSession), keyEquivalent: "")
			
			// Dynamic rewind/reset menu item
			let rewindMenuItem = NSMenuItem(
				title: viewModel.rewindMenuItemTitle,
				action: #selector(rewindOrResetTapped),
				keyEquivalent: "")
			
			// Disable the item if there's no history and timer is idle
			rewindMenuItem.isEnabled =
			viewModel.canRewindToPreviousSession || viewModel.timerState != .idle
			menu.addItem(rewindMenuItem)
			
			menu.addItem(withTitle: "Restart All", action: #selector(restartAll), keyEquivalent: "")
		}
		
		menu.addItem(NSMenuItem.separator())
		menu.addItem(withTitle: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
		
		
		menu.addItem(
			withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
		
		// Add version info
		if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
		{
			let versionMenuItem = NSMenuItem(
				title: "Version \(version)", action: nil, keyEquivalent: "")
			versionMenuItem.isEnabled = false
			menu.addItem(versionMenuItem)
		}
		
		
		// Use popUpContextMenu instead of setting statusItem.menu
		// This prevents blocking the main thread and allows timer updates to continue
		statusItem.menu = menu
		statusItem.button?.performClick(nil)
		// Set menu back to nil so the button's action works for the next click.
		statusItem.menu = nil
	}
	
	@objc private func primaryAction() {
		viewModel.startTapped()
	}
	
	@objc private func skipSession() {
		viewModel.skipTapped()
	}
	
	@objc private func resetTimer() {
		viewModel.resetTapped()
	}
	
	@objc private func rewindOrResetTapped() {
		viewModel.rewindOrResetTapped()
	}
	
	@objc private func restartAll() {
		viewModel.restartAll()
	}
	
	@objc func openSettings() {
		if settingsWindow == nil {
			print("called")
			let settingsView = SettingsView(viewModel: self.viewModel)
			let hostingController = NSHostingController(rootView: settingsView)
			settingsWindow = NSWindow(contentViewController: hostingController)
			settingsWindow?.title = "JustLockIn Settings"
			settingsWindow?.isReleasedWhenClosed = false
		}
		
		settingsWindow?.center()
		settingsWindow?.makeKeyAndOrderFront(nil)
		
		// Ensure dock icon remains hidden even when showing windows
		NSApp.setActivationPolicy(.accessory)
		NSApp.activate(ignoringOtherApps: true)
	}
	
	private func showWelcomeAlert() {
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = "Welcome to JustLockIn!"
		alert.informativeText = """
	  Your menu bar focus timer is ready to help you stay productive.
	  
	  Quick Guide:
	  • Left-click the timer to start/pause sessions
	  • Right-click (or Ctrl+click) to access the menu with settings and controls
	  • The timer follows the Pomodoro technique by default
	  • Customize durations and settings via the right-click menu
	  • Enable notifications in Settings to get alerts when sessions complete
	  
	  Overflow Mode:
	  • Overflow mode activates when you continue working past your planned session time
	  • When work sessions exceed their planned duration, left-click starts your break
	  • Timer shows elapsed time instead of remaining time
	  
	  You can find all timer controls and settings by right-clicking the menu bar icon.
	  """
		
		alert.addButton(withTitle: "Get Started")
		alert.addButton(withTitle: "Open Settings")
		
		// Add checkbox for "Don't show this again"
		let checkbox = NSButton(checkboxWithTitle: "Don't show this again", target: nil, action: nil)
		checkbox.state = .off
		alert.accessoryView = checkbox
		
		let response = alert.runModal()
		
		// Handle "Don't show this again" checkbox
		if checkbox.state == .on {
			viewModel.settings.showWelcomeAlert = false
		}
		
		// If user clicked "Open Settings", show the settings window
		if response == .alertSecondButtonReturn {
			openSettings()
		}
		
		// Ensure dock icon remains hidden after showing welcome alert
		NSApp.setActivationPolicy(.accessory)
	}
	
	func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		// Allow graceful shutdown but don't prevent termination when user explicitly quits
		return .terminateNow
	}
}
