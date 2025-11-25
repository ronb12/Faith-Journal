# Fix: Apple Pencil Drawing Not Closing in Journal Entry

## Where to Look

The Apple Pencil drawing feature is likely in one of these files:
1. **JournalView.swift** - Main journal view (most likely)
2. **SharedComponents.swift** - Reusable components
3. A journal entry detail/edit view

## How to Find It

### Step 1: Search in Xcode
1. Open the project in Xcode
2. Press `Cmd + Shift + F` (Find in Project)
3. Search for: `PKCanvasView` or `PencilKit` or `toolPicker`
4. This will show you exactly where the drawing code is

### Step 2: Look for These Patterns

The drawing feature is likely presented in one of these ways:

```swift
// Pattern 1: Sheet presentation
.sheet(isPresented: $showDrawing) {
    // Drawing view here - MISSING DISMISS BUTTON
}

// Pattern 2: Full screen cover
.fullScreenCover(isPresented: $showDrawing) {
    // Drawing view here - MISSING DISMISS BUTTON
}

// Pattern 3: Navigation link
NavigationLink(destination: DrawingView()) {
    // Missing dismiss
}
```

## The Fix

### If Drawing is in a Sheet/FullScreenCover:

Find the sheet/fullScreenCover and wrap the content in NavigationView with toolbar:

```swift
// BEFORE (broken - no way to close):
.sheet(isPresented: $showDrawingView) {
    PKCanvasView()
        .toolPicker(toolPicker)
}

// AFTER (fixed - has dismiss button):
.sheet(isPresented: $showDrawingView) {
    NavigationView {
        YourDrawingView()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showDrawingView = false
                    }
                }
            }
    }
}
```

### If Drawing is Embedded in Journal Entry View:

Add a dismiss button to the drawing area:

```swift
ZStack {
    // Your drawing canvas
    PKCanvasView()
        .toolPicker(toolPicker)
    
    // Add dismiss button overlay
    VStack {
        HStack {
            Spacer()
            Button(action: {
                // Hide drawing tools
                toolPicker.setVisible(false, forFirstResponder: canvas)
                showDrawingTools = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        Spacer()
    }
}
```

## Complete Example Fix

Here's a complete example if the drawing is in JournalView.swift:

```swift
// Add these state variables at the top of your view
@State private var showDrawingView = false
@State private var drawingImage: UIImage?

// In your "Add Drawing" button action:
Button(action: {
    showDrawingView = true
}) {
    Label("Add Drawing", systemImage: "pencil")
}

// Replace your existing drawing presentation with:
.sheet(isPresented: $showDrawingView) {
    DrawingView(drawingImage: $drawingImage)
}
```

## Using the DrawingView Component I Created

I've already created a `DrawingView.swift` component with proper dismiss functionality. To use it:

1. The file is at: `Faith Journal/Faith Journal/Views/DrawingView.swift`
2. In your journal entry view, add:

```swift
@State private var showDrawingView = false
@State private var drawingImage: UIImage?

// When user taps "Add Drawing":
Button("Add Drawing") {
    showDrawingView = true
}

// Present the drawing view:
.sheet(isPresented: $showDrawingView) {
    DrawingView(drawingImage: $drawingImage)
}
```

## Quick Test

After making the fix:
1. Open a journal entry
2. Tap the Apple Pencil/drawing button
3. Verify you see "Cancel" and "Done" buttons
4. Tap "Done" - drawing should close
5. You should return to journal entry (not forced to close entire page)

## Common Locations

The drawing feature is most likely in:
- **JournalView.swift** - Look for `PKCanvasView` or `toolPicker`
- **SharedComponents.swift** - Look for drawing-related components
- A detail view for editing journal entries

## Still Can't Find It?

1. In Xcode, use "Find in Project" (`Cmd + Shift + F`)
2. Search for: `PKCanvasView`, `PencilKit`, `toolPicker`, `Add Drawing`
3. Check the file that contains these terms
4. Look for `.sheet` or `.fullScreenCover` near the drawing code
5. Add the NavigationView + toolbar fix as shown above

