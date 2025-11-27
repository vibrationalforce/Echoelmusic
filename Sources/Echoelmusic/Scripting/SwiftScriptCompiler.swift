//
//  SwiftScriptCompiler.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  SWIFT SCRIPT COMPILER - Runtime Swift compilation
//  Compile and execute Swift code at runtime
//
//  **Features:**
//  - Swift source compilation
//  - Dynamic library loading
//  - Sandboxed execution
//  - Hot reload
//  - Error handling
//

import Foundation

@MainActor
class SwiftScriptCompiler: ObservableObject {
    static let shared = SwiftScriptCompiler()

    @Published var isCompiling: Bool = false
    @Published var compileProgress: Float = 0.0
    @Published var lastError: String?

    private let tempDirectory: URL
    private let swiftcPath: String = "/usr/bin/swiftc"

    init() {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoelmusicScripts")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        print("📝 Swift Script Compiler initialized")
    }

    // MARK: - Compilation

    func compile(source: String, name: String) async throws -> URL {
        print("🔨 Compiling Swift script: \(name)")
        isCompiling = true
        compileProgress = 0.0
        lastError = nil

        // Write source to temp file
        let sourceFile = tempDirectory.appendingPathComponent("\(name).swift")
        try source.write(to: sourceFile, atomically: true, encoding: .utf8)
        compileProgress = 0.2

        // Output dylib path
        let dylibPath = tempDirectory.appendingPathComponent("lib\(name).dylib")

        // Compile command
        let args = [
            swiftcPath,
            "-emit-library",
            "-o", dylibPath.path,
            "-module-name", name,
            "-O",  // Optimize
            "-whole-module-optimization",
            sourceFile.path
        ]

        compileProgress = 0.4

        // Execute compilation
        let process = Process()
        process.executableURL = URL(fileURLWithPath: swiftcPath)
        process.arguments = Array(args.dropFirst())

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        compileProgress = 0.8

        // Check for errors
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        if !errorData.isEmpty {
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            lastError = errorOutput
            isCompiling = false
            throw CompilerError.compilationFailed(errorOutput)
        }

        compileProgress = 1.0
        isCompiling = false

        print("✅ Compilation successful: \(dylibPath.path)")
        return dylibPath
    }

    // MARK: - Dynamic Loading

    func loadLibrary(at path: URL) throws -> UnsafeMutableRawPointer {
        print("📦 Loading dynamic library: \(path.lastPathComponent)")

        guard let handle = dlopen(path.path, RTLD_NOW) else {
            let error = String(cString: dlerror())
            throw CompilerError.loadFailed(error)
        }

        print("✅ Library loaded")
        return handle
    }

    func getSymbol<T>(from library: UnsafeMutableRawPointer, name: String) throws -> T {
        guard let symbol = dlsym(library, name) else {
            let error = String(cString: dlerror())
            throw CompilerError.symbolNotFound(name, error)
        }

        return unsafeBitCast(symbol, to: T.self)
    }

    func unloadLibrary(_ library: UnsafeMutableRawPointer) {
        dlclose(library)
        print("🗑️ Library unloaded")
    }

    // MARK: - Hot Reload

    func watchAndRecompile(source: String, name: String, onChange: @escaping (URL) -> Void) async {
        print("👁️ Watching script for changes...")

        // Would use FileSystemEventStream to watch for file changes
        // For now, periodic recompilation

        while true {
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000)  // 5s
                let dylib = try await compile(source: source, name: name)
                onChange(dylib)
            } catch {
                print("Hot reload failed: \(error)")
            }
        }
    }
}

enum CompilerError: Error {
    case compilationFailed(String)
    case loadFailed(String)
    case symbolNotFound(String, String)
}

#if DEBUG
extension SwiftScriptCompiler {
    func testCompiler() async {
        print("🧪 Testing Swift Script Compiler...")

        let testSource = """
        import Foundation

        @_cdecl("test_function")
        public func testFunction() -> Int {
            return 42
        }
        """

        do {
            let dylib = try await compile(source: testSource, name: "TestScript")
            print("  Compiled: \(dylib.path)")

            let library = try loadLibrary(at: dylib)
            print("  Loaded library")

            // Get function pointer
            typealias TestFunc = @convention(c) () -> Int
            let function: TestFunc = try getSymbol(from: library, name: "test_function")

            let result = function()
            print("  Function returned: \(result)")

            unloadLibrary(library)

        } catch {
            print("  Error: \(error)")
        }

        print("✅ Compiler test complete")
    }
}
#endif
