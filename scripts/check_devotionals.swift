#!/usr/bin/env swift

import Foundation

struct SeedFile: Decodable {
    let scriptures: [String]
    let themes: [String]
    let prayers: [String]
    let authors: [String]
    let categories: [String]
}

struct ReflectionsFile: Decodable {
    let reflections: [String]
}

func classicDevotionalBody(reflection: String, prayer: String) -> String {
    let r = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
    let p = prayer.trimmingCharacters(in: .whitespacesAndNewlines)
    return "\(r)\n\nPrayer: \(p)"
}

func norm(_ s: String) -> String {
    s
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .lowercased()
}

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let seedsURL: URL = {
    if CommandLine.arguments.count >= 2 {
        return URL(fileURLWithPath: CommandLine.arguments[1])
    }
    return repoRoot.appendingPathComponent("Faith Journal/Faith Journal/Resources/devotional_seeds.json")
}()

let reflectionsURL: URL = {
    if CommandLine.arguments.count >= 3 {
        return URL(fileURLWithPath: CommandLine.arguments[2])
    }
    return repoRoot.appendingPathComponent("Faith Journal/Faith Journal/Resources/reflections_1000.json")
}()

let seeds = try JSONDecoder().decode(SeedFile.self, from: Data(contentsOf: seedsURL))
let refl = try JSONDecoder().decode(ReflectionsFile.self, from: Data(contentsOf: reflectionsURL))

guard refl.reflections.count >= 1000 else {
    fputs("reflections_1000.json must contain at least 1000 entries (got \(refl.reflections.count)).\n", stderr)
    exit(2)
}

let bodies = Array(refl.reflections.prefix(1000))

guard !seeds.scriptures.isEmpty,
      !seeds.themes.isEmpty,
      !seeds.prayers.isEmpty,
      !seeds.authors.isEmpty,
      !seeds.categories.isEmpty
else {
    fputs("Seed file has an empty list.\n", stderr)
    exit(2)
}

var seenBodies = Set<String>()
for (i, b) in bodies.enumerated() {
    let k = norm(b)
    if !seenBodies.insert(k).inserted {
        fputs("Duplicate reflection body at index \(i).\n", stderr)
        exit(1)
    }
}

let scriptureStep = 37
let themeStep = 53
let prayerStep = 89
let authorStep = 13
let categoryStep = 19

var seen = Set<String>()
var dupCount = 0

for dayOffset in 0..<1000 {
    let s = seeds.scriptures[(dayOffset * scriptureStep) % seeds.scriptures.count]
    let theme = seeds.themes[(dayOffset * themeStep) % seeds.themes.count]
    let reflection = bodies[dayOffset]
    let prayer = seeds.prayers[(dayOffset * prayerStep) % seeds.prayers.count]
    let author = seeds.authors[(dayOffset * authorStep) % seeds.authors.count]
    _ = seeds.categories[(dayOffset * categoryStep) % seeds.categories.count]

    let title = "Day \(dayOffset + 1) — \(theme)"
    let content = classicDevotionalBody(reflection: reflection, prayer: prayer)
    let key = "\(norm(title))|\(norm(s))|\(norm(content))|\(norm(author))"
    if !seen.insert(key).inserted {
        dupCount += 1
        if dupCount <= 10 {
            print("DUPLICATE: \(title) / \(s)")
        }
    }
}

if dupCount > 0 {
    fputs("Found \(dupCount) duplicate devotionals.\n", stderr)
    exit(1)
}

print("OK: 1000 unique reflection bodies; 1000 unique full devotionals.")
