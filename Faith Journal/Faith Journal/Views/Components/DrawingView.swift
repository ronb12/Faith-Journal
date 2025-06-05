import SwiftUI
import PencilKit

struct DrawingView: View {
    @Binding var drawingData: Data?
    @State private var canvasView = PKCanvasView()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("Create your drawing")
                    .font(.headline)
                    .padding()

                PKCanvasViewRepresentable(canvasView: $canvasView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(Color.gray)
                    .padding()
            }
            .navigationTitle("Add Drawing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveDrawing()
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveDrawing() {
        // PKDrawing -> Data
        drawingData = canvasView.drawing.dataRepresentation()
    }
}

struct PKCanvasViewRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        // Configure tool picker if needed
        // let toolPicker = PKToolPicker()
        // toolPicker.addObserver(canvasView)
        // toolPicker.setVisible(true, forFirstResponder: canvasView)
        // canvasView.becomeFirstResponder()
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

#Preview {
    DrawingView(drawingData: .constant(nil))
} 