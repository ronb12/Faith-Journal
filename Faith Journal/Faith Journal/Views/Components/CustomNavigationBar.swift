import SwiftUI

struct CustomNavigationBar: View {
    let title: String
    var leadingButton: (() -> Void)? = nil
    var trailingButton: (() -> Void)? = nil
    var leadingIcon: String = "chevron.left"
    var trailingIcon: String = "plus"
    
    var body: some View {
        HStack {
            if let leadingButton {
                Button(action: leadingButton) {
                    Image(systemName: leadingIcon)
                        .foregroundStyle(.primary)
                }
            }
            
            Spacer()
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            if let trailingButton {
                Button(action: trailingButton) {
                    Image(systemName: trailingIcon)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    CustomNavigationBar(
        title: "Journal",
        leadingButton: {},
        trailingButton: {}
    )
} 