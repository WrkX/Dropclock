import SwiftUI

struct SettingsRow<Content: View>: View {
  let title: String
  let helpText: String
  let content: () -> Content
  @State private var isShowingHelp = false

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
        Button {
          isShowingHelp.toggle()
        } label: {
          Image(systemName: "info.circle")
            .foregroundColor(.gray)
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $isShowingHelp, arrowEdge: .top) {
          Text(helpText)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .frame(width: 280, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding()
        }
      }
      Spacer()
      content()
    }
    .padding(10)
  }
}
