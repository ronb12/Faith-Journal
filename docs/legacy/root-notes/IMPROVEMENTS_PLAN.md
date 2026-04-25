# Faith Journal - Improvements Plan

## Status: In Progress

This document tracks the comprehensive improvements being made to the Faith Journal app.

### ✅ Completed

### 🚧 In Progress

1. **Clean up duplicate files and consolidate projects**
   - [ ] Remove backup files
   - [ ] Consolidate duplicate projects (Faith Journal 2, Faith Journal New)
   - [ ] Clean up old Xcode project files

2. **Add unit tests for core functionality**
   - [ ] JournalEntry tests
   - [ ] PrayerRequest tests
   - [ ] BibleService tests
   - [ ] FirebaseSyncService tests

3. **Complete remaining TODOs**
   - [x] Share functionality in LiveSessionsView
   - [ ] Sync expiration to Firebase

4. **Add onboarding/tutorials**
   - [x] Onboarding view exists - needs enhancement
   - [ ] Add interactive tutorials
   - [ ] Add tooltips for first-time features

5. **Improve offline support/error messages**
   - [x] ErrorHandler utility exists
   - [ ] Enhanced error messages
   - [ ] Offline data handling
   - [ ] Sync queue for offline actions

6. **Performance optimization for large datasets**
   - [ ] Lazy loading for journal entries
   - [ ] Pagination for large lists
   - [ ] Image optimization
   - [ ] Database query optimization

7. **Accessibility improvements**
   - [x] Some accessibility in BroadcastStreamView
   - [ ] VoiceOver labels for all views
   - [ ] Dynamic Type support
   - [ ] Color contrast improvements
   - [ ] Accessibility traits

## Priority Order

1. Complete TODOs (Quick wins)
2. Clean up files (Maintenance)
3. Add unit tests (Quality)
4. Enhance onboarding (UX)
5. Improve error handling (Reliability)
6. Performance optimization (Scalability)
7. Accessibility (Inclusion)

## Notes

- Focus on main project directory: `Faith Journal/Faith Journal/`
- Keep backward compatibility
- Test all changes thoroughly
- Document breaking changes
