import SwiftUI
import PhotosUI

struct CreativeView: View {
    @State private var selectedTab = 0
    @State private var showingNewCreation = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("View", selection: $selectedTab) {
                    Text("Gallery").tag(0)
                    Text("Templates").tag(1)
                    Text("My Art").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                TabView(selection: $selectedTab) {
                    GalleryView()
                        .tag(0)
                    
                    TemplatesView()
                        .tag(1)
                    
                    MyArtView()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Create")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewCreation = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewCreation) {
                NewCreationView()
            }
        }
    }
}

struct GalleryView: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150))
            ], spacing: 20) {
                ForEach(0..<6) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.gray.opacity(0.2))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding()
        }
    }
}

struct TemplatesView: View {
    var body: some View {
        List {
            Section("Scripture Art") {
                Text("Scripture art templates will appear here")
                    .foregroundStyle(.secondary)
            }
            
            Section("Custom Templates") {
                Text("Your custom templates will appear here")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MyArtView: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150))
            ], spacing: 20) {
                ForEach(0..<4) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.gray.opacity(0.2))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding()
        }
    }
}

struct NewCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: Template?
    @State private var selectedVerse = ""
    @State private var selectedFont = "System"
    @State private var selectedColor = Color.blue
    @State private var selectedBackground: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    Picker("Select Template", selection: $selectedTemplate) {
                        Text("Choose a template").tag(nil as Template?)
                        ForEach(Template.allCases) { template in
                            Text(template.rawValue).tag(template as Template?)
                        }
                    }
                }
                
                Section("Content") {
                    TextField("Enter verse", text: $selectedVerse)
                    
                    Picker("Font", selection: $selectedFont) {
                        Text("System").tag("System")
                        Text("Serif").tag("Serif")
                        Text("Sans Serif").tag("Sans Serif")
                    }
                    
                    ColorPicker("Text Color", selection: $selectedColor)
                }
                
                Section("Background") {
                    PhotosPicker(selection: $selectedBackground, matching: .images) {
                        Label("Select Background", systemImage: "photo")
                    }
                }
            }
            .navigationTitle("New Creation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        // Create artwork
                        dismiss()
                    }
                }
            }
        }
    }
}

enum Template: String, CaseIterable, Identifiable {
    case minimal = "Minimal"
    case elegant = "Elegant"
    case modern = "Modern"
    case classic = "Classic"
    case artistic = "Artistic"
    
    var id: String { rawValue }
}

#Preview {
    CreativeView()
} 