import Foundation
import ArgumentParser
import DICOMCore
import DICOMKit
import DICOMDictionary

@available(macOS 10.15, *)
struct DICOMStudy: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-study",
        abstract: "Organize and analyze DICOM studies and series",
        discussion: """
            Manage DICOM studies with organization, summarization, validation, and statistics.
            Supports study/series organization, completeness checking, and comparison.
            
            Examples:
              dicom-study organize files/ --output organized/
              dicom-study summary study/ --format table
              dicom-study check study/ --expected-series 5 --report missing.txt
              dicom-study stats study/ --detailed
              dicom-study compare study1/ study2/ --format json
            """,
        version: "1.3.4",
        subcommands: [Organize.self, Summary.self, Check.self, Stats.self, Compare.self]
    )
}

// MARK: - Organize Command

@available(macOS 10.15, *)
extension DICOMStudy {
    struct Organize: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Organize DICOM files by study and series hierarchy"
        )
        
        @Argument(help: "Input directory containing DICOM files")
        var input: String
        
        @Option(name: .shortAndLong, help: "Output directory for organized files")
        var output: String
        
        @Option(name: .long, help: "Naming pattern: 'descriptive' or 'uid' (default: descriptive)")
        var pattern: String = "descriptive"
        
        @Flag(name: .long, help: "Copy files instead of moving them")
        var copy: Bool = false
        
        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false
        
        mutating func run() throws {
            let organizer = StudyOrganizer()
            try organizer.organize(
                inputPath: input,
                outputPath: output,
                pattern: pattern,
                copy: copy,
                verbose: verbose
            )
        }
    }
}

// MARK: - Summary Command

@available(macOS 10.15, *)
extension DICOMStudy {
    struct Summary: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Display study and series metadata summary"
        )
        
        @Argument(help: "Study directory or DICOM file")
        var path: String
        
        @Option(name: .shortAndLong, help: "Output format: 'table', 'json', or 'csv' (default: table)")
        var format: String = "table"
        
        @Flag(name: .shortAndLong, help: "Show verbose output with all metadata")
        var verbose: Bool = false
        
        mutating func run() throws {
            let analyzer = StudyAnalyzer()
            try analyzer.summarize(
                path: path,
                format: format,
                verbose: verbose
            )
        }
    }
}

// MARK: - Check Command

@available(macOS 10.15, *)
extension DICOMStudy {
    struct Check: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Check study completeness and detect missing slices"
        )
        
        @Argument(help: "Study directory")
        var path: String
        
        @Option(name: .long, help: "Expected number of series")
        var expectedSeries: Int?
        
        @Option(name: .long, help: "Expected number of instances per series")
        var expectedInstances: Int?
        
        @Option(name: .long, help: "Output report file path")
        var report: String?
        
        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false
        
        mutating func run() throws {
            let checker = CompletenessChecker()
            try checker.check(
                studyPath: path,
                expectedSeries: expectedSeries,
                expectedInstances: expectedInstances,
                reportPath: report,
                verbose: verbose
            )
        }
    }
}

// MARK: - Stats Command

@available(macOS 10.15, *)
extension DICOMStudy {
    struct Stats: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Calculate study statistics and metrics"
        )
        
        @Argument(help: "Study directory")
        var path: String
        
        @Flag(name: .long, help: "Show detailed statistics")
        var detailed: Bool = false
        
        @Option(name: .shortAndLong, help: "Output format: 'text' or 'json' (default: text)")
        var format: String = "text"
        
        mutating func run() throws {
            let calculator = StatsCalculator()
            try calculator.calculateStats(
                studyPath: path,
                detailed: detailed,
                format: format
            )
        }
    }
}

// MARK: - Compare Command

@available(macOS 10.15, *)
extension DICOMStudy {
    struct Compare: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Compare two studies for differences"
        )
        
        @Argument(help: "First study directory")
        var path1: String
        
        @Argument(help: "Second study directory")
        var path2: String
        
        @Option(name: .shortAndLong, help: "Output format: 'text' or 'json' (default: text)")
        var format: String = "text"
        
        @Flag(name: .shortAndLong, help: "Show verbose comparison")
        var verbose: Bool = false
        
        mutating func run() throws {
            let comparator = StudyComparator()
            try comparator.compare(
                study1Path: path1,
                study2Path: path2,
                format: format,
                verbose: verbose
            )
        }
    }
}

DICOMStudy.main()
