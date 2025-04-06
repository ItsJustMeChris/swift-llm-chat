import SwiftUI

struct FadeInTextWithDelay: View {
    let text: String
    let delay: Double
    @State private var hasAnimated: Bool = false

    var body: some View {
        Text(text)
            .opacity(hasAnimated ? 1 : 0)
            .onAppear {
                if !hasAnimated {
                    withAnimation(Animation.easeIn(duration: 0.3).delay(delay)) {
                        hasAnimated = true
                    }
                }
            }
    }
}

struct AnimatedTokenLine: View {
    let line: String

    private var tokens: [String] {
        line.split(separator: " ", omittingEmptySubsequences: false).map { String($0) }
    }

    private var groupedTokens: [[String]] {
        let groupSize = tokens.count > 20 ? 20 : 5
        return stride(from: 0, to: tokens.count, by: groupSize).map { start in
            Array(tokens[start..<min(start + groupSize, tokens.count)])
        }
    }

    var body: some View {
        LazyHStack(spacing: 0) {

            ForEach(Array(groupedTokens.enumerated()), id: \.offset) { groupIndex, tokenGroup in
                HStack(spacing: 0) {

                    ForEach(Array(tokenGroup.enumerated()), id: \.offset) { tokenIndex, token in
                        FadeInTextWithDelay(
                            text: token + " ",
                            delay: Double(groupIndex) * 0.15 + Double(tokenIndex) * 0.05
                        )
                    }
                }
            }
        }
    }
}

struct StaticTokenLine: View {
    let line: String
    var body: some View {
        Text(line)
    }
}

struct AnimatedStreamedText: View {
    let textBlocks: [String]
    let openBlock: String

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 4) {

            ForEach(textBlocks.indices.dropLast(), id: \.self) { index in
                StaticTokenLine(line: textBlocks[index])
            }

            if let last = textBlocks.last {
                AnimatedTokenLine(line: last)
            }

            if !openBlock.isEmpty {
                AnimatedTokenLine(line: openBlock)
            }
        }
        .drawingGroup()
    }
}

struct ChatBubble: View {
    @ObservedObject var message: ChatMessageViewModel
    let parentWidth: CGFloat

    var body: some View {
        HStack {
            if message.sender == .assistant {
                AnimatedStreamedText(textBlocks: message.textBlocks, openBlock: message.openBlock)
                    .padding(12)
                    .frame(maxWidth: parentWidth, alignment: .leading)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
            } else {
                Spacer(minLength: 0)
                Text(message.text)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .brightness(0.08)
                    )
                    .frame(maxWidth: parentWidth * 0.7, alignment: .trailing)
            }
        }
    }
}
