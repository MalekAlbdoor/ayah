import Foundation

// Unified logging from the sandboxed extension is not reliably queryable, so
// Debug diagnostics append to a file in the running process's container:
//   ~/Library/Containers/com.malek.ayah.widget/Data/Library/Application Support/trace.log
func trace(_ message: String) {
    #if DEBUG
    guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("trace.log")
    let line = "\(Date()) \(message)\n"
    if let handle = try? FileHandle(forWritingTo: file) {
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        try? handle.close()
    } else {
        try? line.write(to: file, atomically: true, encoding: .utf8)
    }
    #endif
}
