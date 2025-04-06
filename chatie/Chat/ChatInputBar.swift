import SwiftUI
import AppKit

class CustomNSTextView: NSTextView {
    var onSend: (() -> Void)?
    var placeholder: String = "type anything..."
    var placeholderColor: NSColor = .placeholderTextColor
    var autoFocus: Bool = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if autoFocus, let currentWindow = self.window {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self, let win = self.window else { return }
                if win === currentWindow && win.firstResponder !== self {
                    win.makeFirstResponder(self)
                }
            }
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty {
            let insets = textContainerInset
            let linePadding = textContainer?.lineFragmentPadding ?? 0
            let placeholderRect = bounds.insetBy(dx: insets.width + linePadding,
                                                 dy: insets.height)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = alignment
            
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: placeholderColor,
                .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .paragraphStyle: paragraphStyle
            ]
            
            placeholder.draw(in: placeholderRect, withAttributes: attributes)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 {
            if event.modifierFlags.contains(.shift) {
                insertNewlineIgnoringFieldEditor(self)
            } else {
                if !string.isEmpty {
                    onSend?()
                }
                return
            }
        }
        super.keyDown(with: event)
    }
    
    override func paste(_ sender: Any?) {
        if let pasteboardString = NSPasteboard.general.string(forType: .string) {
            insertText(pasteboardString, replacementRange: selectedRange())
        }
    }
}

struct GrowingTextView: NSViewRepresentable {
    @Binding var text: String
    var onSend: (() -> Void)?
    @Binding var dynamicHeight: CGFloat
    var autoFocus: Bool = false
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        
        let textView = CustomNSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        
        textView.isRichText = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.textContainer?.lineFragmentPadding = 0
        
        textView.autoresizingMask = [.width]
        textView.backgroundColor = .clear
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.string = text
        textView.onSend = onSend
        textView.placeholder = "type anything..."
        textView.autoFocus = autoFocus
        
        if let container = textView.textContainer {
            container.containerSize = NSSize(width: scrollView.contentSize.width,
                                             height: .greatestFiniteMagnitude)
            container.widthTracksTextView = true
        }
        
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
            let usedRect = layoutManager.usedRect(for: textContainer)
            let initialHeight = min(usedRect.height + 2 * textView.textContainerInset.height, 250)
            DispatchQueue.main.async {
                self.dynamicHeight = initialHeight
            }
        }
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            textView.string = text
        }
        
        if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
            let usedRect = layoutManager.usedRect(for: textContainer)
            let newHeight = min(usedRect.height + 2 * textView.textContainerInset.height, 250)
            DispatchQueue.main.async {
                self.dynamicHeight = newHeight
            }
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: GrowingTextView
        
        init(_ parent: GrowingTextView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                parent.text = textView.string
                if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                    let usedRect = layoutManager.usedRect(for: textContainer)
                    let newHeight = min(usedRect.height + 2 * textView.textContainerInset.height, 250)
                    DispatchQueue.main.async {
                        self.parent.dynamicHeight = newHeight
                    }
                }
            }
        }
    }
}

struct ChatInputBar: View {
    @Binding var message: String
    var onSend: () -> Void
    @State private var textViewHeight: CGFloat = 30

    var body: some View {
        VStack(spacing: 6) {
            GrowingTextView(
                text: $message,
                onSend: onSend,
                dynamicHeight: $textViewHeight,
                autoFocus: true
            )
            .frame(height: textViewHeight)
            .padding(4)
            .cornerRadius(8)

            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    FlatIcon(systemName: "plus")
                    FlatIcon(systemName: "globe")
                    FlatIcon(systemName: "mic.slash")
                }
                Spacer()
                HStack(spacing: 8) {
                    FlatIcon(systemName: "mic")
                    IconButton(systemName: "arrow.up", iconColor: .black, backgroundColor: .white)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .brightness(0.08)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 1)
        )
    }
}
