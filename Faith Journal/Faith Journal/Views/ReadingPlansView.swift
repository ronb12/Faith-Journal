//
//  ReadingPlansView.swift
//  Faith Journal
//
//  Bible reading plans feature
//

import SwiftUI
import SwiftData

struct ReadingPlansView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ReadingPlan.startDate, order: .reverse)]) private var allPlans: [ReadingPlan]
    @StateObject private var readingPlanService = ReadingPlanService.shared
    @State private var showingCreatePlan = false
    @State private var selectedPlan: ReadingPlan?
    
    var body: some View {
        NavigationStack {
            List {
                // Available Plans
                Section(header: Text("Available Plans")) {
                    ForEach(readingPlanService.availablePlans, id: \.id) { planTemplate in
                        NavigationLink(destination: PlanDetailView(planTemplate: planTemplate)) {
                            PlanRow(
                                title: planTemplate.title,
                                description: planTemplate.description,
                                duration: planTemplate.duration
                            )
                        }
                    }
                }
                
                // Your Active Plans
                if !activePlans.isEmpty {
                    Section(header: Text("Active Plans")) {
                        ForEach(activePlans) { plan in
                            NavigationLink(destination: ActivePlanDetailView(plan: plan)) {
                                ActivePlanRow(plan: plan)
                            }
                        }
                    }
                }
                
                // Completed Plans
                if !completedPlans.isEmpty {
                    Section(header: Text("Completed Plans")) {
                        ForEach(completedPlans) { plan in
                            NavigationLink(destination: ActivePlanDetailView(plan: plan)) {
                                ActivePlanRow(plan: plan)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reading Plans")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreatePlan = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreatePlan) {
                CreateReadingPlanView()
            }
        }
    }
    
    var activePlans: [ReadingPlan] {
        allPlans.filter { !$0.isCompleted }
    }
    
    var completedPlans: [ReadingPlan] {
        allPlans.filter { $0.isCompleted }
    }
}

struct PlanRow: View {
    let title: String
    let description: String
    let duration: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            Text("\(duration) days")
                .font(.caption)
                .foregroundColor(.purple)
        }
        .padding(.vertical, 4)
    }
}

struct ActivePlanRow: View {
    let plan: ReadingPlan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(plan.title)
                    .font(.headline)
                Spacer()
                if plan.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Text("Day \(plan.currentDay)/\(plan.duration)")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }
            
            ProgressView(value: plan.progress)
                .tint(.purple)
            
            if !plan.isCompleted {
                Text("\(plan.daysRemaining) days remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PlanDetailView: View {
    let planTemplate: ReadingPlanTemplate
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingStartPlan = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(planTemplate.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(planTemplate.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Label("\(planTemplate.duration) days", systemImage: "calendar")
                        Label("\(planTemplate.readings.count) readings", systemImage: "book")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Divider()
                
                Text("Reading Schedule")
                    .font(.headline)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(planTemplate.readings.prefix(7), id: \.day) { reading in
                            HStack {
                                Text("Day \(reading.day)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                                    .frame(width: 60)
                                Text(reading.reference)
                                    .font(.subheadline)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        
                        if planTemplate.readings.count > 7 {
                            Text("...and \(planTemplate.readings.count - 7) more days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 68)
                        }
                    }
                }
                
                Button(action: {
                    startPlan()
                }) {
                    Text("Start This Plan")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Plan Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func startPlan() {
        // Create the plan with proper initialization
        let plan = ReadingPlan(
            title: planTemplate.title,
            description: planTemplate.description,
            duration: planTemplate.duration,
            startDate: Date()
        )
        
        // Set readings before inserting into context
        plan.readings = planTemplate.readings
        
        // Verify readings were set correctly
        guard !plan.readings.isEmpty else {
            errorMessage = "Failed to set readings for the plan. Please try again."
            showingError = true
            print("❌ Error: Readings array is empty after assignment")
            return
        }
        
        do {
            // Insert into context
            modelContext.insert(plan)
            
            // Save to persist
            try modelContext.save()
            
            print("✅ Successfully started plan: \(plan.title) with \(plan.readings.count) readings")
            
            // Dismiss the view
            dismiss()
        } catch {
            let errorMsg = "Failed to start reading plan: \(error.localizedDescription)"
            errorMessage = errorMsg
            showingError = true
            print("❌ Error starting reading plan: \(error)")
            print("   Full error: \(error)")
            
            // Try to undo the insert if save failed
            modelContext.delete(plan)
        }
    }
}

struct ActivePlanDetailView: View {
    let plan: ReadingPlan
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var bibleService = BibleService.shared
    @State private var selectedReading: DailyReading?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Progress Header
                VStack(alignment: .leading, spacing: 12) {
                    Text(plan.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if !plan.isCompleted {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Day \(plan.currentDay) of \(plan.duration)")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(plan.progress * 100))% Complete")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView(value: plan.progress)
                                .tint(.purple)
                        }
                    } else {
                        Text("Completed!")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
                
                Divider()
                
                // Today's Reading - Prominently Displayed
                if let todayReading = plan.getTodayReading(), !plan.isCompleted {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(.purple)
                                .font(.title2)
                            Text("Today's Reading")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Day indicator
                            HStack {
                                Text("Day \(todayReading.day) of \(plan.duration)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.15))
                                    .cornerRadius(8)
                                
                                Spacer()
                                
                                if todayReading.isCompleted {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Completed")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.green)
                                }
                            }
                            
                            // Verse reference - Large and prominent
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Read:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                Text(todayReading.reference)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            
                            // Description
                            if !todayReading.readingDescription.isEmpty {
                                Text(todayReading.readingDescription)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                            
                            Divider()
                            
                            // Fetch and display verse text
                            if let verse = bibleService.getAllLocalVerses().first(where: { verse in
                                verse.reference.lowercased().contains(todayReading.reference.lowercased()) ||
                                todayReading.reference.lowercased().contains(verse.reference.lowercased())
                            }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "book.closed.fill")
                                            .foregroundColor(.purple)
                                        Text("Scripture")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                    }
                                    
                                    Text(verse.text)
                                        .font(.body)
                                        .lineSpacing(6)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.purple.opacity(0.08))
                                        .cornerRadius(12)
                                    
                                    Text("Translation: \(verse.translation)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                                .padding(.top, 8)
                            } else {
                                // Show reference even if verse not found locally
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "book.closed.fill")
                                            .foregroundColor(.purple)
                                        Text("Scripture Reference")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                    }
                                    
                                    Text("Please read: \(todayReading.reference)")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.purple.opacity(0.08))
                                        .cornerRadius(12)
                                }
                                .padding(.top, 8)
                            }
                            
                            // Mark complete button
                            Button(action: {
                                plan.markReadingComplete(todayReading.day)
                                do {
                                    try modelContext.save()
                                } catch {
                                    print("❌ Error marking reading complete: \(error.localizedDescription)")
                                    ErrorHandler.shared.handle(.saveFailed)
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: todayReading.isCompleted ? "checkmark.circle.fill" : "circle")
                                    Text(todayReading.isCompleted ? "Reading Completed" : "Mark as Complete")
                                    Spacer()
                                }
                                .font(.headline)
                                .foregroundColor(todayReading.isCompleted ? .green : .white)
                                .padding()
                                .background(todayReading.isCompleted ? Color.green.opacity(0.2) : Color.purple)
                                .cornerRadius(12)
                            }
                            .disabled(todayReading.isCompleted)
                            .padding(.top, 8)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                    }
                } else if plan.isCompleted {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("Reading Plan Completed!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                // Reading Schedule
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.purple)
                        Text("Reading Schedule")
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(plan.readings.indices, id: \.self) { index in
                            let reading = plan.readings[index]
                            let isToday = reading.day == plan.currentDay && !plan.isCompleted
                            
                            HStack(spacing: 12) {
                                Image(systemName: reading.isCompleted ? "checkmark.circle.fill" : (isToday ? "circle.fill" : "circle"))
                                    .foregroundColor(reading.isCompleted ? .green : (isToday ? .purple : .secondary))
                                    .font(isToday ? .title3 : .body)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Day \(reading.day)")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(isToday ? .purple : .primary)
                                        
                                        if isToday {
                                            Text("TODAY")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.purple)
                                                .cornerRadius(4)
                                        }
                                    }
                                    
                                    Text(reading.reference)
                                        .font(.subheadline)
                                        .fontWeight(isToday ? .semibold : .regular)
                                        .foregroundColor(isToday ? .primary : .secondary)
                                    
                                    if !reading.readingDescription.isEmpty {
                                        Text(reading.readingDescription)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    if reading.isCompleted, let completedDate = reading.completedDate {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark")
                                                .font(.caption2)
                                            Text(completedDate, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                        .padding(.top, 2)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(isToday ? Color.purple.opacity(0.1) : Color(.systemGray6))
                            .cornerRadius(10)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedReading = reading
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Reading Plan")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedReading) { reading in
            ReadingDetailView(reading: reading, plan: plan)
        }
    }
}

struct ReadingDetailView: View {
    let reading: DailyReading
    let plan: ReadingPlan
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var bibleService = BibleService.shared
    @State private var verse: BibleVerse?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Day \(reading.day)")
                            .font(.caption)
                            .foregroundColor(.purple)
                        
                        Text(reading.reference)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(reading.readingDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    if let verse = verse {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(verse.reference)
                                .font(.headline)
                                .foregroundColor(.purple)
                            
                            Text(verse.text)
                                .font(.body)
                                .lineSpacing(4)
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(8)
                            
                            Text("Translation: \(verse.translation)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Looking up verse...")
                            .foregroundColor(.secondary)
                            .onAppear {
                                loadVerse()
                            }
                    }
                    
                    if !reading.isCompleted {
                        Button(action: {
                            plan.markReadingComplete(reading.day)
                            do {
                                try modelContext.save()
                                dismiss()
                            } catch {
                                print("❌ Error marking reading complete: \(error.localizedDescription)")
                                ErrorHandler.shared.handle(.saveFailed)
                            }
                        }) {
                            Text("Mark as Complete")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Daily Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func loadVerse() {
        verse = bibleService.getAllLocalVerses().first { verse in
            verse.reference.lowercased().contains(reading.reference.lowercased())
        }
    }
}

struct CreateReadingPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var duration = 30
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Plan Details")) {
                    TextField("Plan Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    Stepper("Duration: \(duration) days", value: $duration, in: 7...365)
                }
            }
            .navigationTitle("Create Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        // Implementation here
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// Reading Plan Service
struct ReadingPlanTemplate: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let duration: Int
    let readings: [DailyReading]
}

class ReadingPlanService: ObservableObject {
    static let shared = ReadingPlanService()
    
    let availablePlans: [ReadingPlanTemplate]
    
    private init() {
        availablePlans = [
            ReadingPlanTemplate(
                title: "30-Day New Testament Overview",
                description: "Read through key passages from the New Testament in 30 days",
                duration: 30,
                readings: Self.create30DayNewTestamentPlan()
            ),
            ReadingPlanTemplate(
                title: "Bible in 90 Days",
                description: "Read through the entire Bible in 90 days",
                duration: 90,
                readings: Self.create90DayBiblePlan()
            ),
            ReadingPlanTemplate(
                title: "7-Day Psalms",
                description: "Explore the book of Psalms over 7 days",
                duration: 7,
                readings: Self.create7DayPsalmsPlan()
            ),
            ReadingPlanTemplate(
                title: "Gospel of John - 21 Days",
                description: "Read through the Gospel of John chapter by chapter",
                duration: 21,
                readings: Self.createJohnGospelPlan()
            ),
            ReadingPlanTemplate(
                title: "Proverbs - 31 Days",
                description: "Read one chapter of Proverbs each day for 31 days",
                duration: 31,
                readings: Self.createProverbsPlan()
            )
        ]
    }
    
    private static func create30DayNewTestamentPlan() -> [DailyReading] {
        let readings = [
            DailyReading(day: 1, reference: "Matthew 1-3", description: "The Birth of Jesus"),
            DailyReading(day: 2, reference: "Matthew 5-7", description: "The Sermon on the Mount"),
            DailyReading(day: 3, reference: "Matthew 28", description: "The Great Commission"),
            DailyReading(day: 4, reference: "Mark 1-2", description: "Jesus Begins His Ministry"),
            DailyReading(day: 5, reference: "Mark 16", description: "The Resurrection"),
            DailyReading(day: 6, reference: "Luke 1-2", description: "The Birth Narratives"),
            DailyReading(day: 7, reference: "Luke 15", description: "Parables of Lost Things"),
            DailyReading(day: 8, reference: "Luke 23-24", description: "The Crucifixion and Resurrection"),
            DailyReading(day: 9, reference: "John 1", description: "In the Beginning"),
            DailyReading(day: 10, reference: "John 3", description: "Born Again"),
            DailyReading(day: 11, reference: "John 14-15", description: "The Farewell Discourse"),
            DailyReading(day: 12, reference: "John 20-21", description: "The Resurrection Appearances"),
            DailyReading(day: 13, reference: "Acts 1-2", description: "The Ascension and Pentecost"),
            DailyReading(day: 14, reference: "Acts 9", description: "The Conversion of Saul"),
            DailyReading(day: 15, reference: "Acts 16-17", description: "Paul's Missionary Journeys"),
            DailyReading(day: 16, reference: "Romans 1-2", description: "The Gospel of God"),
            DailyReading(day: 17, reference: "Romans 8", description: "Life in the Spirit"),
            DailyReading(day: 18, reference: "Romans 12", description: "Living Sacrifices"),
            DailyReading(day: 19, reference: "1 Corinthians 13", description: "The Love Chapter"),
            DailyReading(day: 20, reference: "1 Corinthians 15", description: "The Resurrection Chapter"),
            DailyReading(day: 21, reference: "Galatians 5", description: "Freedom in Christ"),
            DailyReading(day: 22, reference: "Ephesians 2", description: "Saved by Grace"),
            DailyReading(day: 23, reference: "Ephesians 6", description: "The Armor of God"),
            DailyReading(day: 24, reference: "Philippians 4", description: "Rejoice in the Lord"),
            DailyReading(day: 25, reference: "Colossians 3", description: "Set Your Hearts Above"),
            DailyReading(day: 26, reference: "1 Thessalonians 4-5", description: "The Second Coming"),
            DailyReading(day: 27, reference: "1 Timothy 4", description: "A Good Servant"),
            DailyReading(day: 28, reference: "Hebrews 11", description: "Faith Hall of Fame"),
            DailyReading(day: 29, reference: "James 1", description: "Trials and Temptations"),
            DailyReading(day: 30, reference: "Revelation 21-22", description: "The New Jerusalem")
        ]
        return readings
    }
    
    private static func create90DayBiblePlan() -> [DailyReading] {
        // 90-day Bible reading plan covering all 66 books
        let readings: [DailyReading] = [
            // Days 1-12: Genesis
            DailyReading(day: 1, reference: "Genesis 1-8", description: "Creation, the Fall, and the Flood"),
            DailyReading(day: 2, reference: "Genesis 9-16", description: "Noah's Covenant, Tower of Babel, Abraham's Call"),
            DailyReading(day: 3, reference: "Genesis 17-24", description: "Covenant with Abraham, Sodom and Gomorrah, Isaac's Birth"),
            DailyReading(day: 4, reference: "Genesis 25-33", description: "Jacob and Esau, Jacob's Journey"),
            DailyReading(day: 5, reference: "Genesis 34-41", description: "Dinah, Jacob Returns, Joseph in Egypt"),
            DailyReading(day: 6, reference: "Genesis 42-50", description: "Joseph Reunited with Family"),
            
            // Days 7-9: Exodus
            DailyReading(day: 7, reference: "Exodus 1-13", description: "Moses' Birth, The Exodus from Egypt"),
            DailyReading(day: 8, reference: "Exodus 14-24", description: "Crossing the Red Sea, The Ten Commandments"),
            DailyReading(day: 9, reference: "Exodus 25-40", description: "The Tabernacle and God's Presence"),
            
            // Days 10-11: Leviticus
            DailyReading(day: 10, reference: "Leviticus 1-15", description: "Laws for Offerings and Purity"),
            DailyReading(day: 11, reference: "Leviticus 16-27", description: "Day of Atonement, Holy Living"),
            
            // Days 12-13: Numbers
            DailyReading(day: 12, reference: "Numbers 1-14", description: "Census, Spies, Rebellion"),
            DailyReading(day: 13, reference: "Numbers 15-36", description: "Wandering in the Wilderness"),
            
            // Days 14-16: Deuteronomy
            DailyReading(day: 14, reference: "Deuteronomy 1-11", description: "Moses Recounts Israel's History"),
            DailyReading(day: 15, reference: "Deuteronomy 12-26", description: "Laws and Instructions"),
            DailyReading(day: 16, reference: "Deuteronomy 27-34", description: "Blessings, Curses, Moses' Death"),
            
            // Days 17-20: Joshua through Judges
            DailyReading(day: 17, reference: "Joshua 1-12", description: "Conquest of the Promised Land"),
            DailyReading(day: 18, reference: "Joshua 13-24", description: "Division of the Land"),
            DailyReading(day: 19, reference: "Judges 1-12", description: "Judges Lead Israel"),
            DailyReading(day: 20, reference: "Judges 13-21", description: "Samson and Civil War"),
            
            // Days 21-23: Ruth and 1 Samuel
            DailyReading(day: 21, reference: "Ruth 1-4", description: "Ruth's Faithfulness and Redemption"),
            DailyReading(day: 22, reference: "1 Samuel 1-15", description: "Samuel, Saul Anointed as King"),
            DailyReading(day: 23, reference: "1 Samuel 16-31", description: "David Anointed, Saul's Downfall"),
            
            // Days 24-26: 2 Samuel and 1 Kings
            DailyReading(day: 24, reference: "2 Samuel 1-12", description: "David's Reign, David and Bathsheba"),
            DailyReading(day: 25, reference: "2 Samuel 13-24", description: "David's Family Troubles"),
            DailyReading(day: 26, reference: "1 Kings 1-11", description: "Solomon's Wisdom and Temple"),
            
            // Days 27-28: 1 Kings and 2 Kings
            DailyReading(day: 27, reference: "1 Kings 12-22", description: "Kingdom Divides, Prophets"),
            DailyReading(day: 28, reference: "2 Kings 1-17", description: "Elisha, Israel Falls to Assyria"),
            
            // Days 29-30: 2 Kings and 1 Chronicles
            DailyReading(day: 29, reference: "2 Kings 18-25", description: "Judah Falls to Babylon"),
            DailyReading(day: 30, reference: "1 Chronicles 1-17", description: "Genealogies, David's Reign"),
            
            // Days 31-32: 1 & 2 Chronicles
            DailyReading(day: 31, reference: "1 Chronicles 18-29", description: "David Prepares for Temple"),
            DailyReading(day: 32, reference: "2 Chronicles 1-18", description: "Solomon's Temple, Divided Kingdom"),
            
            // Days 33-34: 2 Chronicles, Ezra, Nehemiah
            DailyReading(day: 33, reference: "2 Chronicles 19-36", description: "Kings of Judah, Exile"),
            DailyReading(day: 34, reference: "Ezra 1-10", description: "Return from Exile, Rebuilding Temple"),
            
            // Days 35-36: Nehemiah and Esther
            DailyReading(day: 35, reference: "Nehemiah 1-13", description: "Rebuilding the Wall of Jerusalem"),
            DailyReading(day: 36, reference: "Esther 1-10", description: "Esther Saves Her People"),
            
            // Days 37-39: Job
            DailyReading(day: 37, reference: "Job 1-14", description: "Job's Suffering and Questions"),
            DailyReading(day: 38, reference: "Job 15-31", description: "Job's Friends Speak"),
            DailyReading(day: 39, reference: "Job 32-42", description: "God Answers Job"),
            
            // Days 40-44: Psalms
            DailyReading(day: 40, reference: "Psalms 1-18", description: "Psalms of Worship and Trust"),
            DailyReading(day: 41, reference: "Psalms 19-35", description: "Psalms of Praise and Lament"),
            DailyReading(day: 42, reference: "Psalms 36-52", description: "Psalms of Confidence in God"),
            DailyReading(day: 43, reference: "Psalms 53-72", description: "Psalms of Deliverance"),
            DailyReading(day: 44, reference: "Psalms 73-89", description: "Psalms of God's Faithfulness"),
            
            // Days 45-47: Psalms, Proverbs
            DailyReading(day: 45, reference: "Psalms 90-106", description: "Psalms of God's Sovereignty"),
            DailyReading(day: 46, reference: "Psalms 107-119", description: "Psalms of Thanksgiving and Law"),
            DailyReading(day: 47, reference: "Psalms 120-150", description: "Songs of Ascent, Final Praise"),
            
            // Days 48-51: Proverbs
            DailyReading(day: 48, reference: "Proverbs 1-8", description: "Wisdom and Understanding"),
            DailyReading(day: 49, reference: "Proverbs 9-16", description: "Wise Living and Folly"),
            DailyReading(day: 50, reference: "Proverbs 17-24", description: "Sayings of the Wise"),
            DailyReading(day: 51, reference: "Proverbs 25-31", description: "More Proverbs, The Excellent Wife"),
            
            // Days 52-53: Ecclesiastes and Song of Songs
            DailyReading(day: 52, reference: "Ecclesiastes 1-12", description: "The Meaning of Life Under the Sun"),
            DailyReading(day: 53, reference: "Song of Songs 1-8", description: "Love Song of Solomon"),
            
            // Days 54-58: Isaiah
            DailyReading(day: 54, reference: "Isaiah 1-12", description: "Judgment and Hope for Israel"),
            DailyReading(day: 55, reference: "Isaiah 13-27", description: "Prophecies Against Nations"),
            DailyReading(day: 56, reference: "Isaiah 28-39", description: "Warnings to Judah"),
            DailyReading(day: 57, reference: "Isaiah 40-52", description: "Comfort and the Coming Messiah"),
            DailyReading(day: 58, reference: "Isaiah 53-66", description: "Suffering Servant, New Heavens and Earth"),
            
            // Days 59-62: Jeremiah
            DailyReading(day: 59, reference: "Jeremiah 1-15", description: "Jeremiah's Call and Early Prophecies"),
            DailyReading(day: 60, reference: "Jeremiah 16-29", description: "Judgment and Restoration Promised"),
            DailyReading(day: 61, reference: "Jeremiah 30-45", description: "New Covenant, Fall of Jerusalem"),
            DailyReading(day: 62, reference: "Jeremiah 46-52", description: "Prophecies Against Nations"),
            
            // Days 63-64: Lamentations and Ezekiel
            DailyReading(day: 63, reference: "Lamentations 1-5", description: "Mourning Over Jerusalem's Destruction"),
            DailyReading(day: 64, reference: "Ezekiel 1-16", description: "Ezekiel's Vision, Judgment on Israel"),
            
            // Days 65-67: Ezekiel
            DailyReading(day: 65, reference: "Ezekiel 17-32", description: "Prophecies of Judgment"),
            DailyReading(day: 66, reference: "Ezekiel 33-39", description: "Watchman, Dry Bones, Restoration"),
            DailyReading(day: 67, reference: "Ezekiel 40-48", description: "Vision of New Temple"),
            
            // Days 68-70: Daniel and Minor Prophets
            DailyReading(day: 68, reference: "Daniel 1-6", description: "Daniel in Babylon, Fiery Furnace"),
            DailyReading(day: 69, reference: "Daniel 7-12", description: "Daniel's Visions and Prophecies"),
            DailyReading(day: 70, reference: "Hosea 1-14, Joel 1-3", description: "Hosea's Marriage, Joel's Prophecy"),
            
            // Days 71-73: Minor Prophets
            DailyReading(day: 71, reference: "Amos 1-9, Obadiah 1", description: "Amos and Obadiah's Prophecies"),
            DailyReading(day: 72, reference: "Jonah 1-4, Micah 1-7", description: "Jonah and the Great Fish, Micah"),
            DailyReading(day: 73, reference: "Nahum 1-3, Habakkuk 1-3, Zephaniah 1-3", description: "Prophecies of Judgment and Hope"),
            
            // Days 74-75: Haggai, Zechariah, Malachi
            DailyReading(day: 74, reference: "Haggai 1-2, Zechariah 1-8", description: "Rebuilding the Temple"),
            DailyReading(day: 75, reference: "Zechariah 9-14, Malachi 1-4", description: "Messianic Prophecies, Final Message"),
            
            // Days 76-78: Matthew
            DailyReading(day: 76, reference: "Matthew 1-9", description: "Birth of Jesus, Early Ministry"),
            DailyReading(day: 77, reference: "Matthew 10-18", description: "Sermon on the Mount, Miracles"),
            DailyReading(day: 78, reference: "Matthew 19-28", description: "Teaching, Crucifixion, Resurrection"),
            
            // Days 79-80: Mark
            DailyReading(day: 79, reference: "Mark 1-9", description: "Jesus' Ministry Begins"),
            DailyReading(day: 80, reference: "Mark 10-16", description: "Teaching, Death, and Resurrection"),
            
            // Days 81-82: Luke
            DailyReading(day: 81, reference: "Luke 1-12", description: "Birth Narratives, Early Ministry"),
            DailyReading(day: 82, reference: "Luke 13-24", description: "Teaching, Parables, Resurrection"),
            
            // Days 83-84: John
            DailyReading(day: 83, reference: "John 1-12", description: "In the Beginning, Jesus' Signs"),
            DailyReading(day: 84, reference: "John 13-21", description: "Last Supper, Crucifixion, Resurrection"),
            
            // Days 85-86: Acts
            DailyReading(day: 85, reference: "Acts 1-14", description: "Early Church, Peter's Ministry"),
            DailyReading(day: 86, reference: "Acts 15-28", description: "Paul's Missionary Journeys"),
            
            // Days 87-88: Romans and 1 Corinthians
            DailyReading(day: 87, reference: "Romans 1-16", description: "The Gospel and Righteousness by Faith"),
            DailyReading(day: 88, reference: "1 Corinthians 1-16", description: "Church Issues and Love Chapter"),
            
            // Days 89-90: Remaining Epistles and Revelation
            DailyReading(day: 89, reference: "2 Corinthians 1-13, Galatians 1-6, Ephesians 1-6", description: "Paul's Letters to Churches"),
            DailyReading(day: 90, reference: "Philippians 1-4, Colossians 1-4, 1 Thessalonians 1-5, 2 Thessalonians 1-3, 1 Timothy 1-6, 2 Timothy 1-4, Titus 1-3, Philemon 1, Hebrews 1-13, James 1-5, 1 Peter 1-5, 2 Peter 1-3, 1 John 1-5, 2 John 1, 3 John 1, Jude 1, Revelation 1-22", description: "Remaining Epistles and Revelation - The Final Victory!")
        ]
        return readings
    }
    
    private static func create7DayPsalmsPlan() -> [DailyReading] {
        return [
            DailyReading(day: 1, reference: "Psalm 1-10", description: "Blessings of the Righteous"),
            DailyReading(day: 2, reference: "Psalm 23-25", description: "The Lord is My Shepherd"),
            DailyReading(day: 3, reference: "Psalm 27-30", description: "Trust in the Lord"),
            DailyReading(day: 4, reference: "Psalm 37-40", description: "Wait on the Lord"),
            DailyReading(day: 5, reference: "Psalm 46-50", description: "God is Our Refuge"),
            DailyReading(day: 6, reference: "Psalm 91-100", description: "God's Protection and Praise"),
            DailyReading(day: 7, reference: "Psalm 103-107", description: "Praise the Lord")
        ]
    }
    
    private static func createJohnGospelPlan() -> [DailyReading] {
        var readings: [DailyReading] = []
        for chapter in 1...21 {
            readings.append(DailyReading(day: chapter, reference: "John \(chapter)", description: "Gospel of John Chapter \(chapter)"))
        }
        return readings
    }
    
    private static func createProverbsPlan() -> [DailyReading] {
        var readings: [DailyReading] = []
        for chapter in 1...31 {
            readings.append(DailyReading(day: chapter, reference: "Proverbs \(chapter)", description: "Wisdom from Proverbs Chapter \(chapter)"))
        }
        return readings
    }
}

#Preview {
    ReadingPlansView()
}
