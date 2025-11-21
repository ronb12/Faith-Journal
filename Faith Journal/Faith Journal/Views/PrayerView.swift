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
                    .background(Color(.systemGray6))
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
                .background(Color(.systemBackground))
                
                if filteredRequests.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "hands.sparkles")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Prayer Requests")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Begin your prayer journey by adding your first prayer request")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: { showingNewRequest = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add First Prayer")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(themeManager.colors.primary)
                            .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
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
            }
            .navigationTitle("Prayer Requests")
            .navigationViewStyle(.stack) // Force full-width layout on iPad
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewRequest = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewRequest) {
                NewPrayerRequestView()
            }
        }
        .onAppear {
            // Create sample data if no requests exist
            if requests.isEmpty {
                createSamplePrayers()
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
    
    private func createSamplePrayers() {
        let samplePrayers = [
            PrayerRequest(
                title: "Guidance for Career Decision",
                details: "I'm facing a major career decision and need God's wisdom to choose the right path. Please pray that I would clearly hear His voice and have the courage to follow where He leads.",
                tags: ["career", "guidance", "wisdom"],
                isPrivate: false
            ),
            PrayerRequest(
                title: "Healing for Family Member",
                details: "My mother is dealing with health issues and I'm praying for her complete healing. I trust in God's power to restore her health and bring peace to our family during this difficult time.",
                tags: ["healing", "family", "health"],
                isPrivate: true
            ),
            PrayerRequest(
                title: "Financial Provision",
                details: "We're facing some financial challenges and need God's provision. I'm praying for wisdom in managing our resources and for God to open doors of opportunity.",
                tags: ["finances", "provision", "trust"],
                isPrivate: false
            )
        ]
        
        // Make one prayer answered as an example
        samplePrayers[0].status = .answered
        samplePrayers[0].isAnswered = true
        samplePrayers[0].answerDate = Date().addingTimeInterval(-86400) // Yesterday
        samplePrayers[0].answerNotes = "God provided clear guidance through a conversation with a mentor. I feel confident about the direction He's leading me."
        
        for prayer in samplePrayers {
            modelContext.insert(prayer)
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
                                .background(themeManager.colors.primary.opacity(0.1))
                                .foregroundColor(themeManager.colors.primary)
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
    @State private var description = ""
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
                    TextEditor(text: $description)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveRequest() }
                        .disabled(title.isEmpty || description.isEmpty)
                }
            }
        }
    }
    
    private func saveRequest() {
        var allTags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if !selectedCategory.isEmpty {
            allTags.insert(selectedCategory, at: 0)
        }
        
        let request = PrayerRequest(
            title: title,
            details: description,
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
    @State private var showingShareSheet = false
    
    var shareText: String {
        """
        Prayer Request: \(request.title)
        
        \(request.details)
        
        Status: \(request.status.rawValue)
        Date: \(request.date.formatted())
        Tags: \(request.tags.joined(separator: ", "))
        """
    }
    
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingShareSheet = true }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
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
        .sheet(isPresented: $showingShareSheet) {
            ActivityView(activityItems: [shareText])
        }
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveAnswer() }
                }
            }
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
    @State private var description: String
    @State private var tags: String
    @State private var isPrivate: Bool
    @State private var selectedCategory: String
    
    init(request: PrayerRequest) {
        self.request = request
        _title = State(initialValue: request.title)
        _description = State(initialValue: request.details)
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
                    TextEditor(text: $description)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveChanges() }
                        .disabled(title.isEmpty || description.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        var allTags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if !selectedCategory.isEmpty {
            allTags.insert(selectedCategory, at: 0)
        }
        
        request.title = title
        request.details = description
        request.tags = allTags
        request.isPrivate = isPrivate
        request.updatedAt = Date()
        
        try? modelContext.save()
        dismiss()
    }
} 