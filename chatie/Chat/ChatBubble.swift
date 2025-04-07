import AppKit
import MarkdownUI
import Splash
import SwiftUI

struct TextOutputFormat: OutputFormat {
    private let theme: Splash.Theme

    init(theme: Splash.Theme) {
        self.theme = theme
    }

    func makeBuilder() -> Builder {
        Builder(theme: self.theme)
    }
}

extension TextOutputFormat {
    struct Builder: OutputBuilder {
        private let theme: Splash.Theme
        private var accumulatedText: [Text]

        fileprivate init(theme: Splash.Theme) {
            self.theme = theme
            self.accumulatedText = []
        }

        mutating func addToken(_ token: String, ofType type: TokenType) {
            let color = self.theme.tokenColors[type] ?? self.theme.plainTextColor
            self.accumulatedText.append(Text(token).foregroundColor(Color(color)))
        }

        mutating func addPlainText(_ text: String) {
            self.accumulatedText.append(
                Text(text).foregroundColor(Color(self.theme.plainTextColor))
            )
        }

        mutating func addWhitespace(_ whitespace: String) {
            self.accumulatedText.append(Text(whitespace))
        }

        func build() -> Text {
            self.accumulatedText.reduce(Text(""), +)
        }
    }
}

struct SplashCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    private let syntaxHighlighter: SyntaxHighlighter<TextOutputFormat>

    init(theme: Splash.Theme) {
        self.syntaxHighlighter = SyntaxHighlighter(format: TextOutputFormat(theme: theme))
    }

    func highlightCode(_ content: String, language: String?) -> Text {
        guard language != nil else {
            return Text(content)
        }
        return self.syntaxHighlighter.highlight(content)
    }
}

extension CodeSyntaxHighlighter where Self == SplashCodeSyntaxHighlighter {
    static func splash(theme: Splash.Theme) -> Self {
        SplashCodeSyntaxHighlighter(theme: theme)
    }
}

struct MarkdownStreamedText: View {
    let finalizedText: String
    let streamingText: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Markdown(finalizedText)
                .markdownBlockStyle(\.codeBlock) { configuration in
                    self.codeBlock(configuration)
                }
                .markdownCodeSyntaxHighlighter(.splash(theme: splashTheme))
            
            Text(streamingText)
                .foregroundColor(Color(splashTheme.plainTextColor))
                .frame(minHeight: streamingText.isEmpty ? 0 : nil)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
        }
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func codeBlock(_ configuration: CodeBlockConfiguration) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                HStack {
                    Text(configuration.language ?? "plain text")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(splashTheme.plainTextColor))
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(splashTheme.backgroundColor))
                .overlay(
                    HStack {
                        Spacer()
                        Button(action: {
                            copyToClipboard(configuration.content)
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .padding(.trailing, 12)
                    }
                )
                
                Divider()
                
                ScrollView(.horizontal) {
                    configuration.label
                        .relativeLineSpacing(.em(0.25))
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.85))
                        }
                        .padding()
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .markdownMargin(top: .zero, bottom: .em(0.8))
    }
    
    private var splashTheme: Splash.Theme {
        switch colorScheme {
        case .dark:
            return .wwdc17(withFont: .init(size: 16))
        default:
            return .sunset(withFont: .init(size: 16))
        }
    }
    
    private func copyToClipboard(_ string: String) {
        if let pasteboard = NSPasteboard.general as NSPasteboard? {
            pasteboard.clearContents()
            pasteboard.setString(string, forType: .string)
        }
    }
}

struct ChatBubble: View {
    @ObservedObject var message: ChatMessageViewModel
    let parentWidth: CGFloat

    var body: some View {
        HStack {
            if message.sender == .assistant {
                MarkdownStreamedText(
                    finalizedText: message.textBlocks.joined(separator: "\n"),
                    streamingText: message.openBlock
                )
                .padding(12)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
                .cornerRadius(12)
                .frame(maxWidth: parentWidth, alignment: .leading)
            } else {
                Spacer(minLength: 0)
                Text(message.text)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.9).brightness(0.08))
                    .cornerRadius(12)
                    .frame(maxWidth: parentWidth * 0.7, alignment: .trailing)
            }
        }
    }
}
