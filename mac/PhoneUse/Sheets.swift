import CoreImage.CIFilterBuiltins
import SwiftUI

// MARK: Menu bar

/// The menu bar item's panel: the hero's state at a glance and the few things people do from there.
struct MenuView: View {
    @EnvironmentObject var core: Core
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let h = core.hero
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle().fill(h.good == true ? Color.green : core.running ? Color.orange : Color.secondary)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(h.title).font(.headline)
                    if let d = h.detail, !d.isEmpty {
                        Text(d).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                    }
                }
            }
            Divider()
            if core.running {
                Button("Open iPhone") { core.openPhone() }
            } else {
                Button("Start Phone Use") { core.start() }
            }
            Button("Settings…") { showWindow() }
            Divider()
            Button("Quit Phone Use") { NSApp.terminate(nil) }
        }
        .buttonStyle(MenuRowStyle())
        .padding(12)
        .frame(width: 280)
    }

    private func showWindow() {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "main")
        NSApp.activate()
    }
}

struct MenuRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 3).padding(.horizontal, 6)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.25) : .clear,
                        in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
    }
}

// MARK: Pair iPhone

/// A one-time pairing link as a QR code for the iPhone's camera; closes once the iPhone has paired, and makes a
/// new code when this one runs out (it lasts 10 minutes).
struct PairSheet: View {
    var before: Int
    @EnvironmentObject var core: Core
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Pair iPhone").font(.headline)
            PairingCode(size: 264)
            Text("Point the iPhone's camera at the code and open the link in Phone Use.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 280)
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(24)
        .frame(width: 360)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                await core.refresh()
                if (core.state?.paired ?? 0) > before {
                    core.message = "iPhone paired"
                    dismiss()
                    return
                }
            }
        }
    }
}

/// The pairing QR code (POST /api/companion/pair), drawn here. A link works once, for 10 minutes, so a new one
/// replaces it every 8 minutes for as long as the code is on screen.
struct PairingCode: View {
    var size: CGFloat
    @EnvironmentObject var core: Core
    @State private var image: NSImage?
    @State private var error: String?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).interpolation(.none).resizable().scaledToFit()
                    .padding(size * 0.05)
                    .frame(width: size, height: size)
                    .background(.white, in: RoundedRectangle(cornerRadius: size * 0.08, style: .continuous))
            } else if let error {
                VStack(spacing: 8) {
                    Text("Couldn't make a pairing code: \(error)").multilineTextAlignment(.center)
                    Button("Try Again") { Task { await newCode() } }
                }
                .frame(width: size, height: size)
            } else {
                ProgressView().frame(width: size, height: size)
            }
        }
        .task {
            while !Task.isCancelled {
                await newCode()
                try? await Task.sleep(for: .seconds(8 * 60))
            }
        }
    }

    private func newCode() async {
        error = nil
        do {
            let j = try await core.send("/api/companion/pair", [:], timeout: 10)
            guard let link = j["link"] as? String else { throw CoreError("no link") }
            image = qr(link)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func qr(_ text: String) -> NSImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = "M"
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)) else { return nil }
        let rep = NSCIImageRep(ciImage: out)
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        return img
    }
}

// MARK: Bridge setup

/// Set up a bridge (find it over Bluetooth, compare the code on its screen, pick a Wi-Fi network, type its
/// password, then wait for the iPhone to connect to it), or move a set-up bridge to another network. The same
/// steps and words as the Linux app's BridgeSetup, over the same /api/bridge routes.
struct BridgeSetupSheet: View {
    var change: Bool
    @EnvironmentObject var core: Core
    @Environment(\.dismiss) private var dismiss

    enum Step {
        case waiting(String, String)
        case error(String, String, retry: Retry)
        case bridges([[String: Any]])
        case code(String)
        case networks([[String: Any]])
        case other
        case password(String)
        case ready(String)
    }
    enum Retry { case find, networks }

    @State private var step: Step = .waiting("", "")
    @State private var otherName = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button("Cancel") { close() }.keyboardShortcut(.cancelAction)
            }
            .padding(16)
            Divider()
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 440, height: 500)
        .task { change ? await networks() : await find() }
    }

    private var title: String {
        switch step {
        case .waiting(let t, _), .error(let t, _, _): t
        case .bridges: "Find the Bridge"
        case .code: "Check the Code"
        case .networks: "Choose a Network"
        case .other: "Other Network"
        case .password: "Wi-Fi Password"
        case .ready: "Bridge Ready"
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .waiting(_, let text):
            VStack(spacing: 14) {
                ProgressView()
                Text(text).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(24)
        case .error(_, let text, let retry):
            VStack(spacing: 16) {
                Text(text).multilineTextAlignment(.center)
                Button("Try Again") { Task { retry == .find ? await find() : await networks() } }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
            }
            .padding(24)
        case .bridges(let list):
            Form {
                Section {
                    ForEach(Array(list.enumerated()), id: \.offset) { _, b in
                        let address = b["address"] as? String ?? ""
                        Button { Task { await pair(address) } } label: {
                            NavRow(title: b["name"] as? String ?? "PhoneUse Bridge", subtitle: address)
                        }
                        .buttonStyle(.plain)
                    }
                } footer: { Text("Choose your bridge.").foregroundStyle(.secondary) }
            }
            .formStyle(.grouped)
        case .code(let code):
            VStack(spacing: 18) {
                Text(code).font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                Text("Does the bridge show the same code?").foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button { Task { await networks() } } label: { Text("Codes Match").frame(maxWidth: .infinity) }
                        .tint(.accentColor)
                    Button { Task { await find() } } label: { Text("Don't Match").frame(maxWidth: .infinity) }
                        .tint(.red)
                }
                .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(24)
        case .networks(let list):
            Form {
                Section {
                    ForEach(Array(list.enumerated()), id: \.offset) { _, n in
                        let ssid = n["s"] as? String ?? ""
                        let locked = (n["l"] as? Bool) ?? ((n["l"] as? Int).map { $0 != 0 } ?? false)
                        Button { locked ? (step = .password(ssid)) : Task { await join(ssid, "") }.ignore() } label: {
                            HStack {
                                Image(systemName: "lock.fill").foregroundStyle(.secondary).opacity(locked ? 1 : 0)
                                NavRow(title: ssid)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button { step = .other } label: { NavRow(title: "Other Network…") }.buttonStyle(.plain)
                } footer: {
                    Text("Choose the same 2.4 GHz network as this Mac.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        case .other:
            Form {
                TextField("Network Name", text: $otherName)
                SecureField("Password", text: $password)
                Button("Join") { Task { await join(otherName, password) } }.disabled(otherName.isEmpty)
            }
            .formStyle(.grouped)
        case .password(let ssid):
            Form {
                SecureField("Password for \(ssid)", text: $password).onSubmit { Task { await join(ssid, password) } }
                Button("Join") { Task { await join(ssid, password) } }.disabled(password.isEmpty)
            }
            .formStyle(.grouped)
        case .ready(let phone):
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(.green)
                Text("The bridge is connected to \(phone).")
                Button("Done") { close() }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
            }
            .padding(24)
        }
    }

    private func close() {
        if !change { Task { try? await core.send("/api/bridge/cancel") } }
        Task { await core.refresh() }
        dismiss()
    }

    private func find() async {
        step = .waiting("Find the Bridge", "Looking for the bridge…")
        do {
            let j = try await core.send("/api/bridge/find", timeout: 30)
            let list = j["bridges"] as? [[String: Any]] ?? []
            step = list.isEmpty
                ? .error("Find the Bridge", "No bridge found. Hold the bridge's lower button for 3 seconds, then try again.", retry: .find)
                : .bridges(list)
        } catch {
            step = .error("Find the Bridge", error.localizedDescription, retry: .find)
        }
    }

    private func pair(_ address: String) async {
        step = .waiting("Check the Code", "Connecting to the bridge…")
        do {
            let j = try await core.send("/api/bridge/pair", ["address": address], timeout: 40)
            step = .code("\(j["code"] ?? "")")
        } catch {
            step = .error("Check the Code", error.localizedDescription, retry: .find)
        }
    }

    private func networks() async {
        step = .waiting("Choose a Network", "Looking for Wi-Fi…")
        do {
            let j = try await core.send("/api/bridge/networks", timeout: 30)
            let list = (j["networks"] as? [[String: Any]] ?? []).filter { !(($0["s"] as? String) ?? "").isEmpty }
            step = .networks(list)
        } catch {
            step = .error("Choose a Network", error.localizedDescription, retry: .networks)
        }
    }

    private func join(_ ssid: String, _ pw: String) async {
        step = .waiting("Joining", "Joining \(ssid)…")
        password = ""
        do {
            try await core.send("/api/bridge/join", ["ssid": ssid, "password": pw], timeout: 60)
        } catch {
            step = .error("Joining", error.localizedDescription, retry: .networks)
            return
        }
        if change {
            core.message = "The bridge is on \(ssid)"
            await core.refresh()
            dismiss()
            return
        }
        step = .waiting("Connect the iPhone", "On the iPhone, open Settings › Bluetooth and tap PhoneUse Bridge. "
                         + "If it won't connect, forget it there and tap it again.")
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            await core.refresh()
            if let st = core.state?.bridge?.status, st.connected == true {
                step = .ready(st.phone ?? "the iPhone")
                return
            }
        }
    }
}

extension Task {
    func ignore() {}
}
