import Foundation
import Combine
import AppKit
import Darwin

enum BackendStatus: Equatable {
    case stopped
    case starting
    case running
    case failed(String)
}

class BackendManager: ObservableObject {
    static let shared = BackendManager()

    @Published var status: BackendStatus = .stopped

    private var backendProcess: Process?
    private var healthCheckTimer: Timer?
    private let backendPort = 58724
    private let backendURL = URL(string: "http://127.0.0.1:58724")!
    private let backendPath = "/Users/ptz/Projects/Wisprrd/backend"

    private var failureCount = 0
    private let maxFailures = 6      // 30 seconds tolerance (health check every 5s)
    private var restartAttempts = 0
    private let maxRestartAttempts = 5  // More restart attempts before giving up

    init() {
        // Register for app termination to clean up backend
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    func startBackend() {
        print("🔧 [BackendManager] Starting backend...")

        DispatchQueue.main.async {
            self.status = .starting
        }

        // Check if backend is already running
        if isBackendHealthy() {
            print("✅ [BackendManager] Backend already running on port \(self.backendPort)")
            DispatchQueue.main.async {
                self.status = .running
            }
            startHealthCheck()
            return
        }

        // Check if port is in use by another process
        if isPortInUse() && !isBackendHealthy() {
            print("❌ [BackendManager] Port \(self.backendPort) is in use by another process")
            DispatchQueue.main.async {
                self.status = .failed("Port \(self.backendPort) is in use by another application")
            }
            return
        }

        // Check if venv exists
        let pythonPath = "\(backendPath)/venv/bin/python"
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: pythonPath) {
            print("❌ [BackendManager] Python environment not found at \(pythonPath)")
            DispatchQueue.main.async {
                self.status = .failed("Backend environment not found. Please run backend/setup_backend.sh")
            }
            return
        }

        // Start the backend process
        backendProcess = Process()
        backendProcess?.executableURL = URL(fileURLWithPath: pythonPath)
        backendProcess?.arguments = ["\(backendPath)/main.py"]
        backendProcess?.currentDirectoryURL = URL(fileURLWithPath: backendPath)

        // Set environment variables to include Homebrew paths for ffmpeg
        var environment = ProcessInfo.processInfo.environment
        let homebrewPath = "/opt/homebrew/bin:/opt/homebrew/sbin"
        let standardPath = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        if let existingPath = environment["PATH"] {
            environment["PATH"] = "\(homebrewPath):\(existingPath)"
        } else {
            environment["PATH"] = "\(homebrewPath):\(standardPath)"
        }
        backendProcess?.environment = environment

        // Capture stdout/stderr
        let pipe = Pipe()
        backendProcess?.standardOutput = pipe
        backendProcess?.standardError = pipe

        // Handle process termination
        backendProcess?.terminationHandler = { [weak self] _ in
            self?.handleBackendTermination()
        }

        do {
            try backendProcess?.run()
            print("✅ [BackendManager] Backend process started (PID: \(backendProcess?.processIdentifier ?? -1))")

            // Start health checks after a delay to allow backend to initialize
            // (Server starts immediately now, but models load in background)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.startHealthCheck()
            }
        } catch {
            print("❌ [BackendManager] Failed to start backend process: \(error)")
            DispatchQueue.main.async {
                self.status = .failed("Failed to start backend: \(error.localizedDescription)")
            }
        }
    }

    func stopBackend() {
        print("🛑 [BackendManager] Stopping backend...")

        // Stop health check timer
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

        // Kill any process on the port (SIGKILL to ensure it dies)
        killProcessOnPort(backendPort)

        backendProcess = nil
        failureCount = 0
        restartAttempts = 0

        DispatchQueue.main.async {
            self.status = .stopped
        }
    }

    func restartBackend() {
        print("🔄 [BackendManager] Manual restart requested...")

        // Reset counters to allow fresh restart attempts
        failureCount = 0
        restartAttempts = 0

        // Stop health checks
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

        // Kill ANY process on backend port with SIGKILL (not just our tracked process)
        killProcessOnPort(backendPort)

        backendProcess = nil

        DispatchQueue.main.async {
            self.status = .starting
        }

        // Wait for port to release, then start fresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.startBackend()
        }
    }

    private func killProcessOnPort(_ port: Int) {
        print("🔪 [BackendManager] Killing any process on port \(port)...")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "lsof -ti :\(port) | xargs kill -9 2>/dev/null || true"]
        try? task.run()
        task.waitUntilExit()
        print("   ✅ Port \(port) cleared")
    }

    // MARK: - Private Methods

    private func startHealthCheck() {
        // Stop existing timer
        healthCheckTimer?.invalidate()

        // Initial health check
        checkHealth()

        // Start recurring health checks every 5 seconds
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkHealth()
        }
    }

    private func checkHealth() {
        var request = URLRequest(url: backendURL.appendingPathComponent("health"))
        request.timeoutInterval = 5.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Backend is healthy
                if self.failureCount > 0 {
                    print("✅ [BackendManager] Backend recovered after \(self.failureCount) failed checks")
                }
                self.failureCount = 0
                self.restartAttempts = 0

                DispatchQueue.main.async {
                    if self.status != .running {
                        print("🟢 [BackendManager] Backend is now running")
                        self.status = .running
                    }
                }
            } else {
                // Backend health check failed
                self.failureCount += 1
                print("⚠️  [BackendManager] Health check failed (\(self.failureCount)/\(self.maxFailures))")

                if self.failureCount >= self.maxFailures {
                    print("❌ [BackendManager] Backend appears to be down")
                    DispatchQueue.main.async {
                        self.status = .failed("Backend health check failed")
                    }
                    self.attemptRestart()
                }
            }
        }.resume()
    }

    private func attemptRestart() {
        guard restartAttempts < maxRestartAttempts else {
            print("❌ [BackendManager] Max restart attempts reached")
            DispatchQueue.main.async {
                self.status = .failed("Backend failed to recover after \(self.maxRestartAttempts) restart attempts")
            }
            return
        }

        restartAttempts += 1
        print("🔄 [BackendManager] Attempting restart (\(restartAttempts)/\(maxRestartAttempts))...")

        // Kill any process on the port (SIGKILL)
        killProcessOnPort(backendPort)
        backendProcess = nil

        // Wait a bit then restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.failureCount = 0
            self.startBackend()
        }
    }

    private func handleBackendTermination() {
        print("⚠️  [BackendManager] Backend process terminated")

        DispatchQueue.main.async {
            self.status = .failed("Backend process terminated unexpectedly")
        }

        // Only attempt restart if this wasn't a deliberate stop
        if backendProcess != nil {
            attemptRestart()
        }
    }

    private func isBackendHealthy() -> Bool {
        var request = URLRequest(url: backendURL.appendingPathComponent("health"))
        request.timeoutInterval = 2.0

        var isHealthy = false
        let semaphore = DispatchSemaphore(value: 0)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                isHealthy = true
            }
            semaphore.signal()
        }.resume()

        // Wait up to 3 seconds for response
        _ = semaphore.wait(timeout: .now() + 3.0)
        return isHealthy
    }

    private func isPortInUse() -> Bool {
        // Try to bind to the port - if we can't, it's in use
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_flags = AI_PASSIVE

        var res: UnsafeMutablePointer<addrinfo>?
        let portString = String(backendPort)
        let result = getaddrinfo(nil, portString, &hints, &res)

        guard result == 0, let resPtr = res else {
            if let resPtr = res {
                freeaddrinfo(resPtr)
            }
            return false
        }

        var rp = resPtr
        while rp != nil {
            let sockfd = socket(rp.pointee.ai_family, rp.pointee.ai_socktype, rp.pointee.ai_protocol)
            if sockfd != -1 {
                var reuse: Int32 = 1
                if setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size)) == 0 {
                    if bind(sockfd, rp.pointee.ai_addr, rp.pointee.ai_addrlen) == 0 {
                        close(sockfd)
                        freeaddrinfo(resPtr)
                        return false
                    }
                }
                close(sockfd)
            }
            rp = rp.pointee.ai_next
        }

        freeaddrinfo(resPtr)
        return true
    }

    @objc private func applicationWillTerminate() {
        print("🛑 [BackendManager] Application terminating - cleaning up backend")
        stopBackend()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopBackend()
    }
}
