import AppKit
import Foundation
import IOKit.pwr_mgt

/// Where the core (the `phoneuse` Python package, UxPlay) lives: inside the app bundle once it's packaged
/// (Contents/Resources/core), or the repository checkout during development.
struct CoreLocation {
    var root: URL        // holds phoneuse/ and bin/
    var python: URL
    var uxplay: URL?
    var bundled = false

    static func find() -> CoreLocation? {
        let fm = FileManager.default
        if let res = Bundle.main.resourceURL?.appendingPathComponent("core"),
           fm.fileExists(atPath: res.appendingPathComponent("phoneuse").path) {
            let ux = res.appendingPathComponent("bin/uxplay")
            return CoreLocation(root: res, python: res.appendingPathComponent("python/bin/python3"),
                                uxplay: fm.fileExists(atPath: ux.path) ? ux : nil, bundled: true)
        }
        // Development: the checkout this app was built from, with its .venv (see mac/README.md).
        let repoPath = ProcessInfo.processInfo.environment["PHONEUSE_REPO"]
            ?? (Bundle.main.object(forInfoDictionaryKey: "PhoneUseRepo") as? String)
        guard let repoPath else { return nil }
        let repo = URL(fileURLWithPath: repoPath).standardizedFileURL
        let py = repo.appendingPathComponent(".venv/bin/python")
        guard fm.fileExists(atPath: py.path) else { return nil }
        let candidates = [ProcessInfo.processInfo.environment["PHONEUSE_UXPLAY"],
                          NSHomeDirectory() + "/code/UxPlay/build/uxplay", "/opt/homebrew/bin/uxplay",
                          "/usr/local/bin/uxplay"].compactMap { $0 }
        let ux = candidates.first { fm.isExecutableFile(atPath: $0) }.map { URL(fileURLWithPath: $0) }
        return CoreLocation(root: repo, python: py, uxplay: ux)
    }
}

/// The core's local API (the browser mirror's, on 127.0.0.1:8777) and the `phoneuse serve` this app starts.
/// Like the Linux window, the app keeps no phone state of its own: it reads GET /api/app and changes settings
/// through the same routes the browser page uses.
@MainActor
final class Core: ObservableObject {
    static let shared = Core()
    static let port = 8777
    let base = URL(string: "http://127.0.0.1:\(Core.port)")!
    /// The API takes changes only from its own origin.
    let origin = "http://localhost:\(Core.port)"

    @Published private(set) var state: AppState?
    @Published private(set) var reachable = false
    @Published private(set) var starting = false
    @Published var message: String?           // a short note shown at the bottom of the window
    @Published var tab = "phone"              // the window's tab

    let location = CoreLocation.find()
    private var process: Process?             // the `phoneuse serve` this app started, if any
    private var poll: Task<Void, Never>?
    private var sleepAssertion: IOPMAssertionID = 0

    var hero: Hero {
        if reachable, let h = state?.hero { return h }
        return starting || (reachable && state?.hero == nil) ? .starting : .stopped
    }
    var running: Bool { reachable }
    var weStarted: Bool { process?.isRunning == true }

    func startPolling() {
        guard poll == nil else { return }
        poll = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func refresh() async {
        do {
            let (data, _) = try await URLSession.shared.data(for: request("/api/app", timeout: 6))
            state = try JSONDecoder().decode(AppState.self, from: data)
            reachable = true
            if state?.hero != nil { starting = false }
            Notifier.shared.show(state?.requests)
        } catch {
            reachable = false
            if !weStarted { starting = false }
        }
        holdMacAwake(state?.picture?.live == true && reachable)
    }

    // MARK: API

    private func request(_ path: String, method: String = "GET", body: [String: Any]? = nil,
                         timeout: TimeInterval = 8) -> URLRequest {
        var r = URLRequest(url: base.appendingPathComponent(path), timeoutInterval: timeout)
        r.httpMethod = method
        r.setValue(origin, forHTTPHeaderField: "Origin")
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return r
    }

    /// POST (or DELETE) to the API; returns its JSON object. Throws on a network error or an {"error": …}.
    @discardableResult
    func send(_ path: String, _ body: [String: Any]? = [:], method: String = "POST",
              timeout: TimeInterval = 10) async throws -> [String: Any] {
        let (data, resp) = try await URLSession.shared.data(for: request(path, method: method,
                                                                         body: method == "DELETE" ? nil : body,
                                                                         timeout: timeout))
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            throw CoreError("Phone Use answered \(http.statusCode)")
        }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if let err = json["error"] as? String { throw CoreError(err) }
        return json
    }

    /// Runs a setting change, then refreshes; a failure shows as the window's message.
    func change(_ path: String, _ body: [String: Any]? = [:], method: String = "POST", done: String? = nil) {
        Task {
            do {
                try await send(path, body, method: method)
                if let done { message = done }
            } catch {
                message = "Couldn't change it: \(error.localizedDescription)"
            }
            await refresh()
        }
    }

    // MARK: the core's process

    func start() {
        guard !reachable, !weStarted else { return }
        guard let loc = location else {
            message = "Phone Use can't find its services. Reinstall Phone Use."
            return
        }
        let p = Process()
        p.executableURL = loc.python
        p.arguments = [loc.root.appendingPathComponent("bin/phoneuse").path, "serve"]
        p.currentDirectoryURL = loc.root
        var env = ProcessInfo.processInfo.environment
        if let ux = loc.uxplay { env["PHONEUSE_UXPLAY"] = ux.path }
        if loc.bundled {  // the bundle's own GStreamer and typelibs, never the system's or Homebrew's
            let lib = loc.root.appendingPathComponent("lib").path
            env["GST_PLUGIN_SYSTEM_PATH_1_0"] = lib + "/gstreamer-1.0"
            env["GST_PLUGIN_PATH_1_0"] = ""
            env["GST_PLUGIN_SCANNER_1_0"] = loc.root.appendingPathComponent("libexec/gst-plugin-scanner").path
            env["GI_TYPELIB_PATH"] = lib + "/girepository-1.0"
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Phone Use")
            try? FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
            env["GST_REGISTRY_1_0"] = caches.appendingPathComponent("gst-registry.bin").path
            env["PATH"] = loc.root.appendingPathComponent("bin").path + ":/usr/bin:/bin:/usr/sbin:/sbin"
        }
        env["PYTHONUNBUFFERED"] = "1"
        p.environment = env
        let log = Core.logURL
        try? FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: log.path, contents: nil)
        if let h = try? FileHandle(forWritingTo: log) {
            p.standardOutput = h
            p.standardError = h
        }
        p.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self, self.process === proc else { return }
                self.process = nil
                self.starting = false
                if proc.terminationReason == .exit, proc.terminationStatus != 0 {
                    self.message = "Phone Use stopped unexpectedly. Details are in \(Core.logURL.path)."
                }
                await self.refresh()
            }
        }
        do {
            try p.run()
            process = p
            starting = true
            message = nil
        } catch {
            message = "Couldn't start Phone Use: \(error.localizedDescription)"
        }
    }

    /// Stops the services this app started (a terminal's `phoneuse serve` is left alone).
    func stop() {
        guard let p = process, p.isRunning else { return }
        p.terminate()  // SIGTERM: `phoneuse serve` stops everything it runs
        let deadline = Date().addingTimeInterval(5)
        while p.isRunning, Date() < deadline { usleep(50_000) }
        if p.isRunning { kill(p.processIdentifier, SIGKILL) }
        process = nil
        reachable = false
    }

    static var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Phone Use/core.log")
    }

    // MARK: Python helpers run with the core's Python (phoneuse/claude_setup.py, phoneuse/companion.py)

    func claude(connect: Bool) {
        runCore("from phoneuse import claude_setup as c; " + (connect ? "c.connect()" : "c.disconnect()"),
                done: connect ? "Connected. New Claude Code sessions can use the phone." : "Disconnected from Claude Code",
                failed: connect ? "Couldn't connect" : "Couldn't disconnect")
    }

    /// Forgets every paired iPhone app, as Unpair in the Linux window does. Agents stop until one pairs again.
    func unpairApps() {
        runCore("from phoneuse import companion; companion.forget()", done: "iPhone app unpaired",
                failed: "Couldn't unpair")
    }

    private func runCore(_ statement: String, done: String, failed: String) {
        guard let loc = location else { return }
        let code = "import sys; sys.path.insert(0, sys.argv[1]); " + statement
        Task.detached {
            let p = Process()
            p.executableURL = loc.python
            p.arguments = ["-c", code, loc.root.path]
            let err = Pipe()
            p.standardError = err
            p.standardOutput = FileHandle.nullDevice
            var failure: String?
            do {
                try p.run()
                p.waitUntilExit()
                if p.terminationStatus != 0 {
                    let text = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                    failure = text.split(separator: "\n").last.map(String.init) ?? "exit \(p.terminationStatus)"
                }
            } catch { failure = error.localizedDescription }
            let result = failure
            await MainActor.run { Core.shared.message = result.map { "\(failed): \($0)" } ?? done }
            await Core.shared.refresh()
        }
    }

    // MARK: the Mac stays awake while the iPhone mirrors

    private func holdMacAwake(_ on: Bool) {
        if on, sleepAssertion == 0 {
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                        "The iPhone is mirroring to Phone Use" as CFString, &sleepAssertion)
        } else if !on, sleepAssertion != 0 {
            IOPMAssertionRelease(sleepAssertion)
            sleepAssertion = 0
        }
    }

    func openPhone() {
        NSWorkspace.shared.open(URL(string: "http://localhost:\(Core.port)")!)
    }
}

struct CoreError: LocalizedError {
    var text: String
    init(_ text: String) { self.text = text }
    var errorDescription: String? { text }
}
