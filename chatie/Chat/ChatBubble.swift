import SwiftUI
import AppKit

class IntrinsicTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
        guard let layoutManager = layoutManager, let textContainer = textContainer else {
            return super.intrinsicContentSize
        }
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        return NSSize(width: textContainer.containerSize.width, height: usedRect.height)
    }
}

class IntrinsicScrollView: NSScrollView {
    override var intrinsicContentSize: NSSize {
        if let documentView = documentView {
            return documentView.intrinsicContentSize
        }
        return super.intrinsicContentSize
    }
}

struct OptimizedStreamedText: NSViewRepresentable {
    @Binding var text: String
    var availableWidth: CGFloat

    func makeNSView(context: Context) -> IntrinsicScrollView {
        let scrollView = IntrinsicScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        
        let textView = IntrinsicTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: IntrinsicScrollView, context: Context) {
        guard let textView = nsView.documentView as? IntrinsicTextView else { return }
        textView.string = text
        
        let currentWidth = availableWidth
        textView.textContainer?.containerSize = NSSize(width: currentWidth, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let newSize = textView.intrinsicContentSize
        textView.frame = NSRect(x: 0, y: 0, width: currentWidth, height: newSize.height)
        
        nsView.invalidateIntrinsicContentSize()
    }
}

struct ChatBubble: View {
    @ObservedObject var message: ChatMessageViewModel
    let parentWidth: CGFloat

    var body: some View {
        HStack {
            if message.sender == .assistant {
                OptimizedStreamedText(text: $message.text, availableWidth: parentWidth - 24)
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
