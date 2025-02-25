import SwiftUI

struct SettingsSection<Content: View>: View {
  let title: String
  let content: () -> Content

  init(title: String, @ViewBuilder content: @escaping () -> Content) {
    self.title = title
    self.content = content
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(Color(.gray))
        .textCase(.uppercase)
        .padding([.top, .leading], 10)

      VStack(spacing: 0) {
        content()
      }
      .background(Color(NSColor.windowBackgroundColor))
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(
            Color(NSColor.controlColor.withSystemEffect(.disabled)),
            lineWidth: 1, antialiased: true)
      )
    }
  }
}
