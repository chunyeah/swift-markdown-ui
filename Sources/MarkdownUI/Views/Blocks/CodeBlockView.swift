import SwiftUI

struct CodeBlockView: View {
  @Environment(\.theme.codeBlock) private var codeBlock
  @Environment(\.codeSyntaxHighlighter) private var codeSyntaxHighlighter

  private let fenceInfo: String?
  private let content: String

  init(fenceInfo: String?, content: String) {
    self.fenceInfo = fenceInfo
    self.content = content.hasSuffix("\n") ? String(content.dropLast()) : content
  }

  var body: some View {
    self.codeBlock.makeBody(
      configuration: .init(
        language: self.fenceInfo,
        content: self.content,
        label: .init(self.label)
      )
    )
  }

  private var label: some View {
    // 避免第三方高亮器构造极深的 Text 连接树：
    // 对极长代码块或超长行数，降级为单个 Text(AttributedString)
    // 阈值经验值：字符 > 8k 或 行数 > 500
    if self.content.count > 8_000 || self.content.split(separator: "\n").count > 500 {
      return Text(self.content)
        .textStyleFont()
        .textStyleForegroundColor()
    }

    return self.codeSyntaxHighlighter.highlightCode(self.content, language: self.fenceInfo)
      .textStyleFont()
      .textStyleForegroundColor()
  }
}
