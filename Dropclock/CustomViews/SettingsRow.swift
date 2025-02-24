import SwiftUI

struct SettingsRow<Content: View>: View {
  let title: String
  let helpText: String
  let content: () -> Content

  init(
    title: String, helpText: String,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.title = title
    self.helpText = helpText
    self.content = content
  }

  var body: some View {
    HStack {
      HStack(spacing: 4) {
        Text(title)
        Button(action: {}) {
          Image(systemName: "info.circle")
            .foregroundColor(.gray)
        }
        .buttonStyle(PlainButtonStyle())
        .help(helpText)
      }
      Spacer()
      content()
    }
    .padding(10)
  }
}
