import SwiftUI

extension Sequence where Element == InlineNode {
  func renderText(
    baseURL: URL?,
    textStyles: InlineTextStyles,
    images: [String: Image],
    softBreakMode: SoftBreak.Mode,
    attributes: AttributeContainer
  ) -> Text {
    var renderer = TextInlineRenderer(
      baseURL: baseURL,
      textStyles: textStyles,
      images: images,
      softBreakMode: softBreakMode,
      attributes: attributes
    )
    renderer.render(self)
    return renderer.result
  }
}

private struct TextInlineRenderer {
  var result = Text("")
  
  // 收集所有文本片段，避免累积嵌套
  private var textSegments: [Text] = []
  private var attributedResult = AttributedString()

  private let baseURL: URL?
  private let textStyles: InlineTextStyles
  private let images: [String: Image]
  private let softBreakMode: SoftBreak.Mode
  private let attributes: AttributeContainer
  private var shouldSkipNextWhitespace = false

  init(
    baseURL: URL?,
    textStyles: InlineTextStyles,
    images: [String: Image],
    softBreakMode: SoftBreak.Mode,
    attributes: AttributeContainer
  ) {
    self.baseURL = baseURL
    self.textStyles = textStyles
    self.images = images
    self.softBreakMode = softBreakMode
    self.attributes = attributes
  }

  mutating func render<S: Sequence>(_ inlines: S) where S.Element == InlineNode {
    for inline in inlines {
      self.render(inline)
    }
    // Finalize: flush accumulated AttributedString
    self.flushAccumulatedText()
    
    // 最后一次性构建 Text，使用平衡二叉树方式减少嵌套深度
    self.result = self.buildBalancedText(from: self.textSegments)
  }

  private mutating func render(_ inline: InlineNode) {
    switch inline {
    case .text(let content):
      self.renderText(content)
    case .softBreak:
      self.renderSoftBreak()
    case .html(let content):
      self.renderHTML(content)
    case .image(let source, _):
      self.renderImage(source)
    case .quoted:
      self.defaultRender(inline)
    default:
      self.defaultRender(inline)
    }
  }

  private mutating func renderText(_ text: String) {
    var text = text

    if self.shouldSkipNextWhitespace {
      self.shouldSkipNextWhitespace = false
      text = text.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
    }

    self.defaultRender(.text(text))
  }

  private mutating func renderSoftBreak() {
    switch self.softBreakMode {
    case .space where self.shouldSkipNextWhitespace:
      self.shouldSkipNextWhitespace = false
    case .space:
      self.defaultRender(.softBreak)
    case .lineBreak:
      self.shouldSkipNextWhitespace = true
      self.defaultRender(.lineBreak)
    }
  }

  private mutating func renderHTML(_ html: String) {
    let tag = HTMLTag(html)

    switch tag?.name.lowercased() {
    case "br":
      self.defaultRender(.lineBreak)
      self.shouldSkipNextWhitespace = true
    default:
      self.defaultRender(.html(html))
    }
  }

  private mutating func renderImage(_ source: String) {
    if let image = self.images[source] {
      // Flush accumulated text before adding image
      self.flushAccumulatedText()
      // 将图片添加到片段数组，而不是直接累积
      self.textSegments.append(Text(image))
    }
  }

  private mutating func defaultRender(_ inline: InlineNode) {
    // Accumulate in AttributedString instead of concatenating Text
    let attributedString = inline.renderAttributedString(
      baseURL: self.baseURL,
      textStyles: self.textStyles,
      softBreakMode: self.softBreakMode,
      attributes: self.attributes
    )
    self.attributedResult += attributedString
  }
  
  private mutating func flushAccumulatedText() {
    guard !self.attributedResult.characters.isEmpty else { return }
    // 将文本片段添加到数组，而不是直接累积
    self.textSegments.append(Text(self.attributedResult))
    self.attributedResult = AttributedString()
  }
  
  /// 使用平衡二叉树方式构建 Text，将嵌套深度从 O(n) 降至 O(log n)
  private func buildBalancedText(from segments: [Text]) -> Text {
    guard !segments.isEmpty else { return Text("") }
    guard segments.count > 1 else { return segments[0] }
    
    // 使用分治法构建，避免线性累积
    var current = segments
    while current.count > 1 {
      var next: [Text] = []
      var i = 0
      while i < current.count {
        if i + 1 < current.count {
          // 两两配对
          next.append(current[i] + current[i + 1])
          i += 2
        } else {
          // 奇数个时，最后一个单独保留
          next.append(current[i])
          i += 1
        }
      }
      current = next
    }
    return current[0]
  }
}
