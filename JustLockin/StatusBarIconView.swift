import Quartz
import SwiftUI

struct PercentageFillDiscView: View {
  var progress: Double
  var fillColor: Color = .white

  var body: some View {
    GeometryReader { geometry in
      let radius = min(geometry.size.width, geometry.size.height) / 2
      let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

      ZStack {
        Circle()
          .fill(fillColor)

        Path { path in
          // Move to center to make a pie wedge shape for the mask
          path.move(to: center)
          path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + (360 * progress)),
            clockwise: false
          )
          path.closeSubpath()  // Close path back to center
        }
        .blendMode(.destinationOut)

      }
      .compositingGroup()

    }
  }
}

struct QLImage: NSViewRepresentable {
  private let name: String

  init(_ name: String) {
    self.name = name
  }

  func makeNSView(context: NSViewRepresentableContext<QLImage>) -> QLPreviewView {
    guard let url = Bundle.main.url(forResource: name, withExtension: "gif")
    else {
      let _ = print("Cannot get image \(name)")
      return QLPreviewView()
    }

    let preview = QLPreviewView(frame: .zero, style: .normal)
    preview?.autostarts = true
    preview?.previewItem = url as QLPreviewItem

    return preview ?? QLPreviewView()
  }

  func updateNSView(_ nsView: QLPreviewView, context: NSViewRepresentableContext<QLImage>) {
    // Don't update the preview item if it's already set to prevent GIF restart/flicker
    // Only update if the URL is actually different (which shouldn't happen in our case)
    guard let url = Bundle.main.url(forResource: name, withExtension: "gif"),
      let currentItem = nsView.previewItem as? URL,
      currentItem != url
    else {
      return
    }
    nsView.previewItem = url as QLPreviewItem
  }

  typealias NSViewType = QLPreviewView
}

// Helper extension for Hex Colors (if you don't have it already)
extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a: UInt64
    let r: UInt64
    let g: UInt64
    let b: UInt64
    switch hex.count {
    case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default: (a, r, g, b) = (255, 0, 0, 0)  // Default to black
    }
    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }
}

struct StatusBarIconView: View {
  var timeString: String
  var progress: Double
  var sessionType: SessionType
  var timerState: TimerState

  private var themeColor: Color {
    switch sessionType {
    case .work:
      return .primary
    case .shortBreak, .longBreak:
      return .green
    case .overflow:
      return .primary
    }
  }

  var circleFillColor: Color {
    if sessionType == .longBreak || sessionType == .shortBreak {
      Color(hex: "#0b3a07")
    } else {
      .primary
    }
  }

  var body: some View {
    HStack(spacing: 2) {
      if sessionType == .overflow {
        QLImage("fire")
          .frame(width: 15, height: 13, alignment: .center)
          .id("fire_gif")
      } else if timerState == .paused {
        // Show pause icon when timer is paused (but not during overflow)
        Image(systemName: "pause.fill")
          .font(.system(size: 11))
          .foregroundColor(circleFillColor)
          .frame(width: 15, height: 11)
      } else {
        PercentageFillDiscView(progress: progress, fillColor: circleFillColor)
          .frame(width: 15, height: 11)
      }

      Text(timeString)
        .font(.subheadline)
        .frame(width: 32)
    }
    .padding(.horizontal, 4)
	.padding(.vertical, 0.5)
    .modifier(BackgroundModifier(sessionType: sessionType))
  }

  struct BackgroundModifier: ViewModifier {
    var sessionType: SessionType

    func body(content: Content) -> some View {
      if sessionType == .longBreak || sessionType == .shortBreak {
        content.background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "#23554d")))

      } else {
        content.background(RoundedRectangle(cornerRadius: 6).stroke())
      }
    }
  }
}
