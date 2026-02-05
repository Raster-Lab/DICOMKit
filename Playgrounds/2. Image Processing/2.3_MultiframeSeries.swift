// DICOMKit Sample Code: Multi-frame Series and Cine Playback
//
// This example demonstrates how to:
// - Work with multi-frame DICOM images
// - Implement cine playback
// - Calculate frame timing and FPS
// - Cache frames for smooth playback
// - Extract specific frames
// - Handle memory efficiently

import DICOMKit
import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(QuartzCore)
import QuartzCore
#endif

// MARK: - Example 1: Basic Multi-frame Access

func example1_accessMultipleFrames() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/multiframe/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("❌ No pixel data")
        return
    }
    
    print("Multi-frame Image Information:")
    print("  Total frames: \(pixelData.numberOfFrames)")
    print("  Frame size: \(pixelData.rows) × \(pixelData.columns)")
    print("  Bits allocated: \(pixelData.bitsAllocated)")
    
    // Access individual frames
    for frameIndex in 0..<min(5, pixelData.numberOfFrames) {
        if let frame = try? pixelData.frameData(at: frameIndex) {
            print("  Frame \(frameIndex): \(frame.count) bytes")
        }
    }
}

// MARK: - Example 2: Frame Timing Information

func example2_frameTimingInfo() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/multiframe/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    guard let pixelData = file.pixelData else {
        print("❌ No pixel data")
        return
    }
    
    // Get frame time from DICOM tags
    let frameTime = dataSet.float64(for: .frameTime) // milliseconds between frames
    let recommendedDisplayFrameRate = dataSet.uint16(for: .recommendedDisplayFrameRate)
    let cineRate = dataSet.uint16(for: .cineRate)
    
    print("Frame Timing Information:")
    print("  Frame Time: \(frameTime.map { "\($0) ms" } ?? "Not specified")")
    print("  Recommended FPS: \(recommendedDisplayFrameRate.map { "\($0)" } ?? "Not specified")")
    print("  Cine Rate: \(cineRate.map { "\($0)" } ?? "Not specified")")
    
    // Calculate duration
    if let frameTime = frameTime {
        let totalDuration = frameTime * Double(pixelData.numberOfFrames) / 1000.0
        print("  Total duration: \(String(format: "%.2f", totalDuration)) seconds")
        
        // Calculate playback FPS
        let fps = 1000.0 / frameTime
        print("  Calculated FPS: \(String(format: "%.1f", fps))")
    }
}

// MARK: - Example 3: Simple Cine Playback Loop

#if canImport(CoreGraphics)
class SimpleCinePlayer {
    let pixelData: PixelData
    var currentFrame: Int = 0
    var isPlaying: Bool = false
    var fps: Double = 30.0
    
    init(pixelData: PixelData) {
        self.pixelData = pixelData
    }
    
    func play() {
        isPlaying = true
        print("▶️  Playing cine loop at \(fps) FPS")
    }
    
    func pause() {
        isPlaying = false
        print("⏸️  Paused at frame \(currentFrame)")
    }
    
    func nextFrame() {
        currentFrame = (currentFrame + 1) % pixelData.numberOfFrames
    }
    
    func previousFrame() {
        currentFrame = (currentFrame - 1 + pixelData.numberOfFrames) % pixelData.numberOfFrames
    }
    
    func seekToFrame(_ frameIndex: Int) {
        currentFrame = max(0, min(frameIndex, pixelData.numberOfFrames - 1))
    }
    
    func getCurrentImage() throws -> CGImage? {
        return try pixelData.createCGImage(frame: currentFrame)
    }
}

func example3_simpleCinePlayer() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/multiframe/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("❌ No pixel data")
        return
    }
    
    let player = SimpleCinePlayer(pixelData: pixelData)
    
    // Simulate playback
    player.play()
    
    for _ in 0..<10 {
        if let image = try player.getCurrentImage() {
            print("  Frame \(player.currentFrame): \(image.width)×\(image.height)")
        }
        player.nextFrame()
    }
    
    player.pause()
}
#endif

// MARK: - Example 4: Frame Caching for Smooth Playback

#if canImport(CoreGraphics)
class CachedCinePlayer {
    let pixelData: PixelData
    private var frameCache: [Int: CGImage] = [:]
    private let cacheQueue = DispatchQueue(label: "com.dicomkit.framecache")
    let maxCachedFrames: Int
    
    init(pixelData: PixelData, maxCachedFrames: Int = 30) {
        self.pixelData = pixelData
        self.maxCachedFrames = maxCachedFrames
    }
    
    func preloadFrames(range: Range<Int>) async {
        let framesToLoad = Array(range).filter { $0 < pixelData.numberOfFrames }
        
        await withTaskGroup(of: (Int, CGImage?).self) { group in
            for frameIndex in framesToLoad {
                group.addTask {
                    let image = try? self.pixelData.createCGImage(frame: frameIndex)
                    return (frameIndex, image)
                }
            }
            
            for await (index, image) in group {
                if let image = image {
                    cacheQueue.sync {
                        self.frameCache[index] = image
                        
                        // Evict old frames if cache is too large
                        if self.frameCache.count > self.maxCachedFrames {
                            let oldestFrame = self.frameCache.keys.min() ?? 0
                            self.frameCache.removeValue(forKey: oldestFrame)
                        }
                    }
                }
            }
        }
    }
    
    func getFrame(_ index: Int) -> CGImage? {
        return cacheQueue.sync {
            if let cached = frameCache[index] {
                return cached
            }
            
            // Cache miss - load synchronously
            let image = try? pixelData.createCGImage(frame: index)
            if let image = image {
                frameCache[index] = image
            }
            return image
        }
    }
    
    func clearCache() {
        cacheQueue.sync {
            frameCache.removeAll()
        }
        print("🗑️  Cache cleared")
    }
}

func example4_cachedCinePlayer() async throws {
    let fileURL = URL(fileURLWithPath: "/path/to/multiframe/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("❌ No pixel data")
        return
    }
    
    let player = CachedCinePlayer(pixelData: pixelData, maxCachedFrames: 30)
    
    // Preload first 30 frames
    print("Preloading frames 0-29...")
    await player.preloadFrames(range: 0..<30)
    print("✅ Frames preloaded")
    
    // Access cached frames
    for frameIndex in 0..<10 {
        if let image = player.getFrame(frameIndex) {
            print("  Frame \(frameIndex) (cached): \(image.width)×\(image.height)")
        }
    }
}
#endif

// MARK: - Example 5: Timer-based Cine Playback

#if canImport(CoreGraphics) && canImport(QuartzCore)
class TimerCinePlayer {
    let pixelData: PixelData
    var currentFrame: Int = 0
    var fps: Double = 30.0
    var isPlaying: Bool = false
    
    private var displayLink: CADisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    
    init(pixelData: PixelData) {
        self.pixelData = pixelData
    }
    
    func start() {
        guard !isPlaying else { return }
        isPlaying = true
        lastFrameTime = CACurrentMediaTime()
        
        #if os(iOS) || os(tvOS)
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        displayLink?.add(to: .main, forMode: .common)
        print("▶️  Started playback at \(fps) FPS")
        #else
        // macOS alternative using Timer
        print("⚠️  CADisplayLink not available on macOS - use CVDisplayLink instead")
        #endif
    }
    
    func stop() {
        isPlaying = false
        displayLink?.invalidate()
        displayLink = nil
        print("⏹️  Stopped playback")
    }
    
    @objc private func updateFrame() {
        let currentTime = CACurrentMediaTime()
        let frameInterval = 1.0 / fps
        
        if currentTime - lastFrameTime >= frameInterval {
            currentFrame = (currentFrame + 1) % pixelData.numberOfFrames
            lastFrameTime = currentTime
            
            // In real app, update UI here
            // delegate?.cinePlayer(self, didUpdateToFrame: currentFrame)
        }
    }
}

func example5_timerBasedPlayback() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/multiframe/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("❌ No pixel data")
        return
    }
    
    let player = TimerCinePlayer(pixelData: pixelData)
    player.fps = 24.0
    
    print("Timer-based Cine Player:")
    print("  Total frames: \(pixelData.numberOfFrames)")
    print("  Target FPS: \(player.fps)")
    
    // Note: Actual playback requires RunLoop
    // player.start()
}
#endif

// MARK: - Example 6: Frame Extraction by Time

func example6_extractFramesByTime() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/multiframe/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("❌ No pixel data")
        return
    }
    
    let dataSet = file.dataSet
    let frameTime = dataSet.float64(for: .frameTime) ?? 33.3 // Default ~30 FPS
    
    // Extract frames at specific time points
    let timePoints: [Double] = [0.0, 1.0, 2.0, 3.0] // seconds
    
    print("Extracting frames at time points:")
    for time in timePoints {
        let frameIndex = Int((time * 1000.0) / frameTime)
        
        if frameIndex < pixelData.numberOfFrames {
            print("  Time \(time)s = Frame \(frameIndex)")
        } else {
            print("  Time \(time)s = Out of range")
        }
    }
}

// MARK: - Example 7: Memory-Efficient Frame Iteration

#if canImport(CoreGraphics)
func example7_memoryEfficientIteration() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/multiframe/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("❌ No pixel data")
        return
    }
    
    print("Processing \(pixelData.numberOfFrames) frames (memory-efficient)...")
    
    // Process frames in chunks to avoid loading all at once
    let chunkSize = 10
    
    for chunkStart in stride(from: 0, to: pixelData.numberOfFrames, by: chunkSize) {
        let chunkEnd = min(chunkStart + chunkSize, pixelData.numberOfFrames)
        
        autoreleasepool {
            for frameIndex in chunkStart..<chunkEnd {
                if let image = try? pixelData.createCGImage(frame: frameIndex) {
                    // Process frame
                    let pixelCount = image.width * image.height
                    
                    if frameIndex % 50 == 0 {
                        print("  Processed frame \(frameIndex): \(pixelCount) pixels")
                    }
                }
            }
        }
    }
    
    print("✅ All frames processed")
}
#endif

// MARK: - Example 8: Frame Sequence Information

func example8_frameSequenceInfo() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/multiframe/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    guard let pixelData = file.pixelData else {
        print("❌ No pixel data")
        return
    }
    
    // Check for Shared Functional Groups Sequence (for Enhanced multi-frame)
    if let sharedFGSeq = dataSet.sequence(for: .sharedFunctionalGroupsSequence) {
        print("Enhanced Multi-frame Image:")
        print("  Shared Functional Groups: \(sharedFGSeq.items.count)")
    }
    
    // Check for Per-frame Functional Groups Sequence
    if let perFrameFGSeq = dataSet.sequence(for: .perFrameFunctionalGroupsSequence) {
        print("  Per-frame Functional Groups: \(perFrameFGSeq.items.count)")
        
        // Show first few frame-specific parameters
        for (index, item) in perFrameFGSeq.items.prefix(3).enumerated() {
            print("\n  Frame \(index):")
            
            // Frame Content Sequence
            if let frameContentSeq = item.sequence(for: .frameContentSequence),
               let frameContentItem = frameContentSeq.items.first {
                if let instanceNumber = frameContentItem.uint32(for: .instanceNumber) {
                    print("    Instance Number: \(instanceNumber)")
                }
                if let temporalPositionIndex = frameContentItem.uint32(for: .temporalPositionIndex) {
                    print("    Temporal Position: \(temporalPositionIndex)")
                }
            }
        }
    }
    
    print("\n  Total frames: \(pixelData.numberOfFrames)")
}

// MARK: - Example 9: Adaptive FPS Calculation

func example9_adaptiveFPS() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/multiframe/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    guard let pixelData = file.pixelData else {
        print("❌ No pixel data")
        return
    }
    
    // Try multiple sources for FPS
    var fps: Double?
    
    // 1. Recommended Display Frame Rate
    if let recommendedFPS = dataSet.uint16(for: .recommendedDisplayFrameRate) {
        fps = Double(recommendedFPS)
        print("Using Recommended Display Frame Rate: \(fps!) FPS")
    }
    // 2. Cine Rate
    else if let cineRate = dataSet.uint16(for: .cineRate) {
        fps = Double(cineRate)
        print("Using Cine Rate: \(fps!) FPS")
    }
    // 3. Calculate from Frame Time
    else if let frameTime = dataSet.float64(for: .frameTime) {
        fps = 1000.0 / frameTime
        print("Calculated from Frame Time: \(fps!) FPS")
    }
    // 4. Use default based on modality
    else {
        let modality = dataSet.string(for: .modality) ?? ""
        
        switch modality {
        case "US": // Ultrasound typically 30 FPS
            fps = 30.0
        case "XA": // X-ray Angiography typically 15-30 FPS
            fps = 15.0
        default: // Default fallback
            fps = 24.0
        }
        
        print("Using default FPS for \(modality): \(fps!) FPS")
    }
    
    print("\nPlayback Configuration:")
    print("  Target FPS: \(fps!)")
    print("  Frame interval: \(String(format: "%.2f", 1000.0 / fps!)) ms")
    print("  Total frames: \(pixelData.numberOfFrames)")
    print("  Total duration: \(String(format: "%.2f", Double(pixelData.numberOfFrames) / fps!)) seconds")
}

// MARK: - Usage Notes

/*
 Multi-frame Series Best Practices:
 
 1. Frame Access:
    - Use frameData(at:) for raw pixel data
    - Use createCGImage(frame:) for display
    - Frame indices start at 0
 
 2. Cine Playback:
    - Check recommendedDisplayFrameRate first
    - Fall back to frameTime or cineRate
    - Use CADisplayLink (iOS) or CVDisplayLink (macOS)
    - Consider device capabilities (60 FPS max)
 
 3. Frame Caching:
    - Cache decoded frames for smooth playback
    - Limit cache size based on available memory
    - Preload frames ahead of current position
    - Use LRU eviction strategy
 
 4. Memory Management:
    - Process large series in chunks
    - Use autoreleasepool for batch operations
    - Release frames when not visible
    - Monitor memory warnings
 
 5. Performance Optimization:
    - Decode frames on background thread
    - Use async/await for preloading
    - Consider hardware acceleration
    - Profile with Instruments
 
 6. Enhanced Multi-frame:
    - Check for Functional Groups Sequences
    - Handle per-frame parameters
    - Support temporal ordering
    - Handle stack/volume organization
 
 7. Frame Timing:
    - Frame Time is in milliseconds
    - Recommended Display Frame Rate is in FPS
    - Temporal Position Index for ordering
    - Handle irregular frame intervals
 
 8. UI Considerations:
    - Show current frame number
    - Display playback controls
    - Indicate loop mode
    - Allow speed adjustment
    - Support reverse playback
 
 9. Common Modalities:
    - US: 15-60 FPS, loop playback
    - XA/RF: 7.5-30 FPS, cine review
    - CT/MR: Stack navigation, not cine
    - NM: Time series, slow frame rate
 */
