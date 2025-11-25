//
//  DrawingView.swift
//  Faith Journal
//
//  Drawing view with proper dismiss functionality
//

import SwiftUI
import PencilKit

struct DrawingView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var drawingImage: UIImage?
    
    @State private var canvas = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var isToolPickerVisible = false
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            DrawingCanvasView(canvas: $canvas, toolPicker: toolPicker)
            
            // Always-visible header with dismiss buttons - positioned in safe area
            VStack {
                // Top bar with dismiss buttons - always visible
                HStack(spacing: 12) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .bold))
                            Text("Cancel")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(minWidth: 100)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Cancel and close drawing")
                    
                    Spacer()
                    
                    Button(action: {
                        // Save the drawing as an image
                        saveDrawing()
                        dismiss()
                    }) {
                        HStack(spacing: 6) {
                            Text("Done")
                                .font(.system(size: 17, weight: .bold))
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(minWidth: 100)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Save and close drawing")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(
                    // Semi-transparent background for visibility
                    Color.black.opacity(0.4)
                        .blur(radius: 0)
                )
                
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.blue)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    saveDrawing()
                    dismiss()
                }
                .foregroundColor(.blue)
                .fontWeight(.semibold)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    // Swipe down from top area to dismiss (only if started near top)
                    if value.startLocation.y < 100 && value.translation.height > 80 {
                        dismiss()
                    }
                }
        )
        .onAppear {
            setupToolPicker()
        }
    }
    
    private func setupToolPicker() {
        toolPicker.addObserver(canvas)
        toolPicker.setVisible(true, forFirstResponder: canvas)
        canvas.becomeFirstResponder()
    }
    
    private func saveDrawing() {
        let image = canvas.drawing.image(
            from: canvas.bounds,
            scale: UIScreen.main.scale
        )
        drawingImage = image
    }
}

struct DrawingCanvasView: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    var toolPicker: PKToolPicker
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 15)
        canvas.backgroundColor = .white
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Update if needed
    }
}

