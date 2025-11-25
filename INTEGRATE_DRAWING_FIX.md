# How to Integrate the Drawing View Fix

## Problem
The Apple Pencil drawing feature doesn't have a way to close/dismiss, forcing users to exit the entire journal page.

## Solution
I've created a new `DrawingView.swift` component with proper dismiss functionality. Here's how to integrate it:

## Step 1: Check Your Current JournalView Implementation

In `JournalView.swift`, find where the drawing is presented. Look for:
- `.sheet(isPresented: $showDrawingView)` 
- `.fullScreenCover(isPresented: $showDrawingView)`
- Any code related to `PKCanvasView` or `PencilKit`

## Step 2: Update Your Drawing Presentation

Replace your current drawing presentation code with this pattern:

```swift
// Add this state variable if not already present
@State private var showDrawingView = false
@State private var drawingImage: UIImage?

// In your view body, update the sheet/fullScreenCover to use the new DrawingView:

.sheet(isPresented: $showDrawingView) {
    DrawingView(drawingImage: $drawingImage)
}
```

OR if you prefer full screen:

```swift
.fullScreenCover(isPresented: $showDrawingView) {
    DrawingView(drawingImage: $drawingImage)
}
```

## Step 3: Update Your "Add Drawing" Button

Make sure your button that opens the drawing view sets the state:

```swift
Button(action: {
    showDrawingView = true
}) {
    Label("Add Drawing", systemImage: "pencil")
}
```

## Step 4: Save the Drawing (if needed)

After the user taps "Done", the drawing will be saved to `drawingImage`. You can then use it:

```swift
// After the sheet is dismissed, check if drawingImage is set
.onChange(of: showDrawingView) { isShowing in
    if !isShowing, let image = drawingImage {
        // Save the image to your journal entry
        // For example:
        // journalEntry.drawing = image
        // or add it to an array of images
    }
}
```

## Step 5: Alternative - If You Have Existing Drawing Code

If you already have drawing code in JournalView.swift, you can:

1. **Option A**: Replace it with the new `DrawingView` component
2. **Option B**: Add dismiss buttons to your existing drawing view

For Option B, wrap your existing drawing view in a NavigationView and add toolbar buttons:

```swift
NavigationView {
    YourExistingDrawingView()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    showDrawingView = false
                }
            }
        }
}
```

## Testing Checklist

After integrating:
- [ ] Tap "Add Drawing" button
- [ ] Drawing canvas opens
- [ ] "Cancel" button appears in top-left
- [ ] "Done" button appears in top-right
- [ ] Tap "Cancel" - drawing view closes, no drawing saved
- [ ] Tap "Done" - drawing view closes, drawing is saved
- [ ] Can navigate back to journal without closing entire page

## If You Need Help

If you can't find where the drawing is implemented in JournalView.swift, search for:
- `PKCanvasView`
- `PencilKit`
- `showDrawing`
- `drawing`
- `sheet` or `fullScreenCover`

The new `DrawingView.swift` file I created handles all the dismiss functionality automatically.

