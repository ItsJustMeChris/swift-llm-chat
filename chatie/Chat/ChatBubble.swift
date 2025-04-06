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
            self.accumulatedText.append(Text(token).foregroundColor(.init(color)))
        }

        mutating func addPlainText(_ text: String) {
            self.accumulatedText.append(
                Text(text).foregroundColor(.init(self.theme.plainTextColor))
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

            // Render finalized text with Markdown and syntax highlighting
            Markdown(finalizedText)
                .markdownCodeSyntaxHighlighter(.splash(theme: splashTheme))
                // .textSelection(.enabled) // REMOVED: Apply to container instead
                // .fixedSize(horizontal: false, vertical: true) // Removed for performance testing
                // .animation(.none, value: finalizedText) // Removed

            // Render streaming text as plain Text for performance, with fade-in animation
            // Removed the `if !streamingText.isEmpty` to keep the view stable during updates
            Text(streamingText)
                // Removed monospaced font setting to use default system font
                .foregroundColor(Color(splashTheme.plainTextColor))
                // .textSelection(.enabled) // REMOVED: Apply to container instead
                .frame(minHeight: streamingText.isEmpty ? 0 : nil) // Avoid extra height when empty
                .transition(.opacity.animation(.easeInOut(duration: 0.2))) // Add fade-in transition
                // .fixedSize(horizontal: false, vertical: true) // Removed for performance testing
        }
        .textSelection(.enabled) // ADDED: Apply text selection to the container VStack
        // Apply fixedSize to the VStack instead, allowing internal views to size naturally
        // Removed animation modifiers from here as they are handled by the transition now
        .fixedSize(horizontal: false, vertical: true)
    }

    private var splashTheme: Splash.Theme {
        switch colorScheme {
        case .dark:
            return .wwdc17(withFont: .init(size: 16))
        default:
            return .sunset(withFont: .init(size: 16))
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
                    .textSelection(.enabled) // Make user message text selectable
                    .padding(12)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.9).brightness(0.08))
                    .cornerRadius(12)
                    .frame(maxWidth: parentWidth * 0.7, alignment: .trailing)
            }
        }
    }
}
