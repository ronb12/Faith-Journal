//
//  PerformanceOptimizer.swift
//  Faith Journal
//
//  Performance optimization utilities for large datasets
//

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
class PerformanceOptimizer {
    
    /// Batch size for pagination
    static let defaultBatchSize = 50
    
    /// Maximum items to load initially
    static let initialLoadLimit = 20
    
    /// Cache size for images
    static let imageCacheSize = 100 // MB
    
    /// Optimized query descriptor with pagination
    static func paginatedQuery<T: PersistentModel>(
        sortBy: [SortDescriptor<T>],
        limit: Int = defaultBatchSize,
        offset: Int = 0
    ) -> FetchDescriptor<T> {
        var descriptor = FetchDescriptor<T>(sortBy: sortBy)
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        return descriptor
    }
    
    /// Check if we should load more based on current index
    static func shouldLoadMore(currentIndex: Int, totalCount: Int, threshold: Int = 10) -> Bool {
        return currentIndex >= (totalCount - threshold)
    }
    
    /// Debounce function for search and filtering
    static func debounce(delay: TimeInterval = 0.5, action: @escaping () -> Void) -> () -> Void {
        var workItem: DispatchWorkItem?
        
        return {
            workItem?.cancel()
            workItem = DispatchWorkItem(execute: action)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
        }
    }
    
    /// Throttle function for scroll events
    static func throttle(delay: TimeInterval = 0.1, action: @escaping () -> Void) -> () -> Void {
        var lastRun = Date.distantPast
        var workItem: DispatchWorkItem?
        
        return {
            workItem?.cancel()
            let now = Date()
            let timeSinceLastRun = now.timeIntervalSince(lastRun)
            
            if timeSinceLastRun > delay {
                lastRun = now
                action()
            } else {
                workItem = DispatchWorkItem {
                    lastRun = Date()
                    action()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + (delay - timeSinceLastRun), execute: workItem!)
            }
        }
    }
}

/// Lazy loading view modifier for large lists
struct LazyLoadModifier: ViewModifier {
    @Binding var isLoading: Bool
    let onLoadMore: () -> Void
    let threshold: Int
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                onLoadMore()
            }
    }
}

extension View {
    /// Enable lazy loading for lists
    func lazyLoad(isLoading: Binding<Bool>, onLoadMore: @escaping () -> Void, threshold: Int = 10) -> some View {
        modifier(LazyLoadModifier(isLoading: isLoading, onLoadMore: onLoadMore, threshold: threshold))
    }
}

/// Optimized list view with pagination
struct PaginatedListView<T: PersistentModel, Content: View>: View {
    let items: [T]
    let content: (T) -> Content
    @Binding var isLoading: Bool
    let onLoadMore: () -> Void
    
    var body: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(item)
                    .onAppear {
                        if index == items.count - 5 { // Load more when 5 items from end
                            onLoadMore()
                        }
                    }
            }
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
    }
}
