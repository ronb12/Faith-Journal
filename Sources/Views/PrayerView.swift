import SwiftUI
import SwiftData

struct PrayerView: View {
    @Query(sort: [SortDescriptor(\PrayerRequest.date, order: .reverse)]) var requests: [PrayerRequest]
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewRequest = false
    @State private var searchText = ""
    @State private var selectedFilter: PrayerFilter = .all
    @State private var showingFilterSheet = false
    
    var filteredRequests: [PrayerRequest] {
        var filtered = requests
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { request in
                request.title.localizedCaseInsensitiveContains(searchText) ||
                request.details.localizedCaseInsensitiveContains(searchText) ||
                request.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.status == .active }
        case .answered:
            filtered = filtered.filter { $0.status == .answered }
        case .archived:
            filtered = filtered.filter { $0.status == .archived }
        case .private:
            filtered = filtered.filter { $0.isPrivate }
        case .public:
            filtered = filtered.filter { !$0.isPrivate }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search prayers...", text: $searchText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.platformSystemGray6)
                    .cornerRadius(10)
                    
                    HStack {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(title: "All", isSelected: selectedFilter == .all) {
                                    selectedFilter = .all
                                }
                                FilterChip(title: "Active", isSelected: selectedFilter == .active) {
                                    selectedFilter = .active
                                }
                                FilterChip(title: "Answered", isSelected: selectedFilter == .answered) {
                                    selectedFilter = .answered
                                }
                                FilterChip(title: "Private", isSelected: selectedFilter == .private) {
                                    selectedFilter = .private
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding()
                .background(Color.platformSystemBackground)
                
                // Prayer Requests List
                List {
                    ForEach(filteredRequests) { request in
                        NavigationLink(destination: PrayerRequestDetailView(request: request)) {
                            PrayerRequestRow(request: request)
                        }
                    }
                    .onDelete(perform: deleteRequest)
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Prayer Requests")
#if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewRequest = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
#endif
            .sheet(isPresented: $showingNewRequest) {
                NewPrayerRequestView()
            }
        }
    }
    
    private func deleteRequest(at offsets: IndexSet) {
        for index in offsets {
            let request = filteredRequests[index]
            modelContext.delete(request)
        }
        try? modelContext.save()
    }
}

struct PrayerRequestRow: View {
    let request: PrayerRequest
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var statusColor: Color {
        switch request.status {
        case .active:
            return .blue
        case .answered:
            return .green
        case .archived:
            return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(request.title)
                    .font(.headline)
                    .foregroundColor(themeManager.colors.primary)
                
                Spacer()
                
                if request.isPrivate {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                if request.isAnswered {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            Text(request.details)
                .font(.body)
                .lineLimit(3)
                .foregroundColor(themeManager.colors.textSecondary)
            
            HStack {
                Text(request.date, style: .date)
                    .font(.caption)
                    .foregroundColor(themeManager.colors.textSecondary)
                
                Spacer()
                
                Text(request.status.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.1))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
            }
            
            if !request.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(request.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.1))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

enum PrayerFilter {
    case all, active, answered, archived, `private`, `public`
}

struct NewPrayerRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var details = ""
    @State private var tags = ""
    @State private var isPrivate = false
    @State private var selectedCategory: String = ""
    
    let categories = ["", "Health", "Family", "Work", "Relationships", "Spiritual Growth", "Financial", "Emotional", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title")) {
                    TextField("Prayer Title", text: $title)
                }
                
                Section(header: Text("Description")) {
                    TextEditor(text: $details)
                        .frame(height: 100)
                }
                
                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        Text("No category").tag("")
                        ForEach(categories.dropFirst(), id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Tags (comma separated)")) {
                    TextField("Tags", text: $tags)
                }
                
                Section {
                    Toggle("Private Prayer", isOn: $isPrivate)
                }
            }
            .navigationTitle("New Prayer Request")
#if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveRequest() }
                        .disabled(title.isEmpty || details.isEmpty)
                }
            }
#endif
        }
    }
    
    private func saveRequest() {
        var allTags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if !selectedCategory.isEmpty {
            allTags.insert(selectedCategory, at: 0)
        }
        
        let request = PrayerRequest(
            title: title,
            details: details,
            tags: allTags,
            isPrivate: isPrivate
        )
        modelContext.insert(request)
        try? modelContext.save()
        dismiss()
    }
}

struct PrayerRequestDetailView: View {
    let request: PrayerRequest
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false
    @State private var showingAnswerSheet = false
    @State private var showingDeleteAlert = false
    
    var statusColor: Color {
        switch request.status {
        case .active:
            return .blue
        case .answered:
            return .green
        case .archived:
            return .gray
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(request.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        if request.isPrivate {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                        }
                        
                        if request.isAnswered {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    HStack {
                        Text(request.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(request.status.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(0.1))
                            .foregroundColor(statusColor)
                            .cornerRadius(12)
                    }
                }
                
                // Description
                Text(request.details)
                    .font(.body)
                    .lineSpacing(4)
                
                // Tags
                if !request.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(request.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundColor(.purple)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // Answer Section
                if request.isAnswered {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Prayer Answered")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        
                        if let answerDate = request.answerDate {
                            Text("Answered on \(answerDate, style: .date)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let answerNotes = request.answerNotes, !answerNotes.isEmpty {
                            Text(answerNotes)
                                .font(.body)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(12)
                }
                
                // Action Buttons
                if request.status == .active {
                    Button(action: { showingAnswerSheet = true }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Mark as Answered")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Prayer Details")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if request.status == .active {
                        Button("Mark as Answered") { showingAnswerSheet = true }
                        Button("Archive") { archiveRequest() }
                    } else if request.status == .answered {
                        Button("Mark as Active") { activateRequest() }
                        Button("Archive") { archiveRequest() }
                    } else if request.status == .archived {
                        Button("Mark as Active") { activateRequest() }
                    }
                    Button("Edit") { showingEditSheet = true }
                    Button("Delete", role: .destructive) { showingDeleteAlert = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
#endif
        .sheet(isPresented: $showingEditSheet) {
            EditPrayerRequestView(request: request)
        }
        .sheet(isPresented: $showingAnswerSheet) {
            AnswerPrayerRequestView(request: request)
        }
        .alert("Delete Prayer Request", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(request)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this prayer request? This action cannot be undone.")
        }
    }
    
    private func archiveRequest() {
        request.status = .archived
        request.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func activateRequest() {
        request.status = .active
        request.updatedAt = Date()
        try? modelContext.save()
    }
}

struct AnswerPrayerRequestView: View {
    let request: PrayerRequest
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var answerNotes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("How was your prayer answered?")) {
                    TextEditor(text: $answerNotes)
                        .frame(height: 120)
                }
                
                Section {
                    Text("Marking this prayer as answered will help you track God's faithfulness in your life.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Prayer Answered")
#if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveAnswer() }
                }
            }
#endif
        }
    }
    
    private func saveAnswer() {
        request.status = .answered
        request.isAnswered = true
        request.answerDate = Date()
        request.answerNotes = answerNotes.isEmpty ? nil : answerNotes
        request.updatedAt = Date()
        
        try? modelContext.save()
        dismiss()
    }
}

struct EditPrayerRequestView: View {
    let request: PrayerRequest
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title: String
    @State private var details: String
    @State private var tags: String
    @State private var isPrivate: Bool
    @State private var selectedCategory: String
    
    init(request: PrayerRequest) {
        self.request = request
        _title = State(initialValue: request.title)
        _details = State(initialValue: request.details)
        _tags = State(initialValue: request.tags.joined(separator: ", "))
        _isPrivate = State(initialValue: request.isPrivate)
        _selectedCategory = State(initialValue: request.tags.first ?? "")
    }
    
    let categories = ["", "Health", "Family", "Work", "Relationships", "Spiritual Growth", "Financial", "Emotional", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title")) {
                    TextField("Prayer Title", text: $title)
                }
                
                Section(header: Text("Description")) {
                    TextEditor(text: $details)
                        .frame(height: 100)
                }
                
                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        Text("No category").tag("")
                        ForEach(categories.dropFirst(), id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Tags (comma separated)")) {
                    TextField("Tags", text: $tags)
                }
                
                Section {
                    Toggle("Private Prayer", isOn: $isPrivate)
                }
            }
            .navigationTitle("Edit Prayer Request")
#if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveChanges() }
                        .disabled(title.isEmpty || details.isEmpty)
                }
            }
#endif
        }
    }
    
    private func saveChanges() {
        var allTags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if !selectedCategory.isEmpty {
            allTags.insert(selectedCategory, at: 0)
        }
        
        request.title = title
        request.details = details
        request.tags = allTags
        request.isPrivate = isPrivate
        request.updatedAt = Date()
        
        try? modelContext.save()
        dismiss()
    }
} 