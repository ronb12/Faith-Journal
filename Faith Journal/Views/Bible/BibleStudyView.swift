import SwiftUI

struct BibleStudyView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("View", selection: $selectedTab) {
                    Text("Reading Plan").tag(0)
                    Text("Verses").tag(1)
                    Text("Study Notes").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                TabView(selection: $selectedTab) {
                    ReadingPlanView()
                        .tag(0)
                    
                    VersesView()
                        .tag(1)
                    
                    StudyNotesView()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Bible Study")
        }
    }
}

struct ReadingPlanView: View {
    var body: some View {
        List {
            Section("Current Plan") {
                Text("Your reading plan will appear here")
                    .foregroundStyle(.secondary)
            }
            
            Section("Progress") {
                Text("Reading streak: 0 days")
                Text("Completed: 0%")
            }
        }
    }
}

struct VersesView: View {
    var body: some View {
        List {
            Section("Memorization") {
                Text("Your verse memorization progress will appear here")
                    .foregroundStyle(.secondary)
            }
            
            Section("Highlights") {
                Text("Your highlighted verses will appear here")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StudyNotesView: View {
    var body: some View {
        List {
            Text("Your study notes will appear here")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    BibleStudyView()
} 