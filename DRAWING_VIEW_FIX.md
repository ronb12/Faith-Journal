# Fix for Apple Pencil Drawing View Not Closing

## Issue
When users select the Apple Pencil feature in the journal, the drawing toolbar/area never closes, forcing users to close the entire page to navigate away.

## Solution
Add a dismiss button (Done/Close) to the drawing view so users can close it and return to the journal.

## Implementation

The drawing view should be presented in a sheet or fullScreenCover with a navigation bar that includes a "Done" or "Close" button. Here's the pattern to follow:

```swift
// In JournalView.swift, the drawing sheet should look like this:

@State private var showDrawingView = false
@State private var drawingImage: UIImage?

// When presenting the drawing view:
.sheet(isPresented: $showDrawingView) {
    DrawingView(drawingImage: $drawingImage)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    showDrawingView = false
                }
            }
        }
}

// OR if using fullScreenCover:
.fullScreenCover(isPresented: $showDrawingView) {
    NavigationView {
        DrawingView(drawingImage: $drawingImage)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showDrawingView = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showDrawingView = false
                        // Save the drawing here if needed
                    }
                }
            }
    }
}
```

## DrawingView Implementation

If you have a separate DrawingView component, it should look like this:

```swift
import SwiftUI
import PencilKit

struct DrawingView: View {
    @Binding var drawingImage: UIImage?
    @Environment(\.dismiss) var dismiss
    @State private var canvas = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    
    var body: some View {
        NavigationView {
            ZStack {
                DrawingCanvas(canvas: $canvas, toolPicker: toolPicker)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                dismiss()
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                // Save drawing
                                drawingImage = canvas.drawing.image(from: canvas.bounds, scale: 1.0)
                                dismiss()
                            }
                        }
                    }
            }
        }
    }
}

struct DrawingCanvas: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    var toolPicker: PKToolPicker
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 15)
        toolPicker.addObserver(canvas)
        toolPicker.setVisible(true, forFirstResponder: canvas)
        canvas.becomeFirstResponder()
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Update if needed
    }
}
```

## Key Points

1. **Always provide a dismiss button** - Either "Done" or "Cancel" in the navigation bar
2. **Use @Environment(\.dismiss)** - This is the SwiftUI way to dismiss sheets/modals
3. **Save before dismissing** - If the drawing should be saved, do it in the "Done" button action
4. **Cancel option** - Give users a way to cancel without saving

## Quick Fix Steps

1. Find where the drawing view is presented (look for `.sheet` or `.fullScreenCover` with drawing-related code)
2. Add a NavigationView wrapper if not present
3. Add a toolbar with "Done" and/or "Cancel" buttons
4. Use `@Environment(\.dismiss)` or set the binding to `false` to close

## Testing

After implementing:
1. Open journal entry
2. Tap "Add Drawing" or Apple Pencil icon
3. Verify "Done" or "Cancel" button appears in navigation bar
4. Tap the button - drawing view should close
5. User should return to journal entry view

