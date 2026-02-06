import Foundation

#if canImport(Network)

/// Reports progress for file transfer operations
struct ProgressReporter {
    let totalFiles: Int
    let verbose: Bool
    private let startTime: Date
    
    init(totalFiles: Int, verbose: Bool) {
        self.totalFiles = totalFiles
        self.verbose = verbose
        self.startTime = Date()
    }
    
    /// Reports the start of sending a file
    func startFile(_ fileNumber: Int, path: String, size: Int) {
        if verbose {
            let fileName = (path as NSString).lastPathComponent
            let sizeStr = formatBytes(size)
            print("[\(fileNumber)/\(totalFiles)] Sending: \(fileName) (\(sizeStr))...", terminator: "")
            fflush(stdout)
        }
    }
    
    /// Reports completion of sending a file
    func completeFile(_ fileNumber: Int, success: Bool, sopInstanceUID: String? = nil, roundTripTime: TimeInterval = 0, error: Error? = nil, totalBytes: Int) {
        if verbose {
            if success {
                let rttStr = String(format: "%.3f", roundTripTime)
                print(" ✓ (\(rttStr)s)")
                if let uid = sopInstanceUID {
                    print("    SOP Instance UID: \(uid)")
                }
            } else {
                print(" ✗ FAILED")
                if let error = error {
                    print("    Error: \(error.localizedDescription)")
                }
            }
        } else {
            // Simple progress indicator
            let percentage = (fileNumber * 100) / totalFiles
            print("\rProgress: \(fileNumber)/\(totalFiles) (\(percentage)%)", terminator: "")
            fflush(stdout)
        }
    }
    
    /// Prints final summary
    func printSummary(succeeded: Int, failed: Int, totalBytes: Int) {
        let elapsed = Date().timeIntervalSince(startTime)
        let elapsedStr = formatDuration(elapsed)
        let bytesStr = formatBytes(totalBytes)
        
        if !verbose {
            print("") // New line after progress
        }
        
        print("")
        print("Transfer Summary")
        print("================")
        print("Total files:     \(totalFiles)")
        print("Succeeded:       \(succeeded)")
        print("Failed:          \(failed)")
        print("Bytes sent:      \(bytesStr)")
        print("Duration:        \(elapsedStr)")
        
        if elapsed > 0 {
            let throughput = Double(totalBytes) / elapsed
            print("Throughput:      \(formatBytes(Int(throughput)))/s")
        }
        
        if failed == 0 {
            print("\n✓ All files sent successfully")
        } else if succeeded == 0 {
            print("\n✗ All files failed to send")
        } else {
            print("\n⚠ Partial success: \(succeeded) succeeded, \(failed) failed")
        }
    }
    
    // MARK: - Formatting Helpers
    
    private func formatBytes(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = 0
        
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        
        if unitIndex == 0 {
            return "\(bytes) \(units[0])"
        } else {
            return String(format: "%.2f %@", value, units[unitIndex])
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 1 {
            return String(format: "%.0f ms", seconds * 1000)
        } else if seconds < 60 {
            return String(format: "%.1f s", seconds)
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(secs)s"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
}

#endif
