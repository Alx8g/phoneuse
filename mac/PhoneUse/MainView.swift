import ServiceManagement
import SwiftUI

/// The window: three tabs in the Linux app's order and words.
struct MainView: View {
    @EnvironmentObject var core: Core

    var body: some View {
        TabView(selection: $core.tab) {
            PhoneTab().tabItem { Label("Phone", systemImage: "iphone") }.tag("phone")
            AgentsTab().tabItem { Label("Agents", systemImage: "sparkles") }.tag("agents")
            BridgeTab().tabItem { Label("Bridge", systemImage: "dot.radiowaves.left.and.right") }.tag("bridge")
                .badge(bridgeNeedsAttention ? "!" : nil)
        }
        .frame(minWidth: 480, minHeight: 520)
        .safeAreaInset(edge: .bottom) {
            if let m = core.message {
                HStack(alignment: .firstTextBaseline) {
                    Text(m).font(.callout).textSelection(.enabled)
                    Spacer()
                    Button("Dismiss") { core.message = nil }.buttonStyle(.link)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.bar)
                .task(id: m) {
                    try? await Task.sleep(for: .seconds(6))
                    if core.message == m { core.message = nil }
                }
            }
        }
    }

    private var bridgeNeedsAttention: Bool {
        guard core.running, let b = core.state?.bridge else { return false }
        return b.saved == nil || b.status?.error != nil || b.status?.connected != true
    }
}

// MARK: Phone

struct PhoneTab: View {
    @EnvironmentObject var core: Core
    @State private var pairing = false
    @State private var confirmUnpair = false
    @State private var login = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section { HeroView() }
            Section {
                Toggle(isOn: Binding(get: { core.state?.awake?.on ?? false },
                                     set: { core.change("/api/awake", ["on": $0]) })) {
                    Text("Keep Awake")
                    Text("The screen stays on while the iPhone mirrors")
                }
                .disabled(!core.running)
                Toggle(isOn: Binding(get: { login }, set: setLogin)) {
                    Text("Start at Login")
                    Text("Phone Use runs in the background, so agents can use the phone")
                }
            }
            Section("iPhone App") {
                let paired = core.state?.paired ?? 0
                if paired > 0 {
                    LabeledContent("Paired") {
                        HStack {
                            Text("\(paired) iPhone" + (paired == 1 ? "" : "s"))
                            Button("Unpair") { confirmUnpair = true }
                        }
                    }
                }
                Button { pairing = true } label: {
                    NavRow(title: paired > 0 ? "Pair Another iPhone" : "Pair iPhone App",
                           subtitle: "Allow and stop agents from the iPhone, and see what they do")
                }
                .buttonStyle(.plain)
                .disabled(!core.running)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $pairing) { PairSheet(before: core.state?.paired ?? 0) }
        .alert(unpairTitle, isPresented: $confirmUnpair) {
            Button("Unpair", role: .destructive) { core.unpairApps() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Agents can't use the iPhone until you pair the app again.")
        }
    }

    private var unpairTitle: String {
        let n = core.state?.paired ?? 0
        return n <= 1 ? "Unpair the iPhone app?" : "Unpair \(n) iPhone apps?"
    }

    private func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            login = on
        } catch {
            core.message = "Couldn't change Start at Login: \(error.localizedDescription)"
            login = SMAppService.mainApp.status == .enabled
        }
    }
}

/// The next thing to do, with the button that does it; or the iPhone (phoneuse/overview.py).
struct HeroView: View {
    @EnvironmentObject var core: Core
    @State private var settingUp = false
    @State private var firewallHelp = false
    @State private var pairing = false

    var body: some View {
        let h = core.hero
        VStack(spacing: 8) {
            if h.qr != "pair" {
                Image(systemName: symbol(h.icon))
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(h.good == true ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                    .frame(height: 64)
                    .symbolEffect(.pulse, isActive: h.step == "starting")
            }
            Text(h.title).font(.title2.weight(.semibold)).multilineTextAlignment(.center)
            if h.qr == "pair" {
                PairingCode(size: 220).padding(.vertical, 6)  // stops renewing once the step changes
            }
            if let steps = h.steps, !steps.isEmpty {
                HeroSteps(steps: steps, bold: h.bold)
            }
            if let d = h.detail, !d.isEmpty {
                Text(detail(d, bold: h.bold))
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            if let action = h.action, let label = Self.buttons[action] {
                Button(label) { perform(action) }
                    .controlSize(.large)
                    .buttonBorderShape(.capsule)
                    .modifier(Prominent(on: h.quiet != true))
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .sheet(isPresented: $settingUp) { BridgeSetupSheet(change: false) }
        .sheet(isPresented: $pairing) { PairSheet(before: core.state?.paired ?? 0) }
        .alert("Let the iPhone reach Phone Use", isPresented: $firewallHelp) {
            Button("Open Firewall Settings") { openFirewallSettings() }
            Button("OK", role: .cancel) {}
        } message: {
            Text(firewallText)
        }
    }

    static let buttons = ["start": "Start Phone Use", "setup_bridge": "Set Up Bridge",
                          "pair_app": "Pair iPhone App", "open_ports": "Open Ports…",
                          "retry": "Try Again", "open_phone": "Open iPhone"]

    private func perform(_ action: String) {
        switch action {
        case "start": core.start()
        case "setup_bridge": settingUp = true
        case "pair_app": pairing = true
        case "open_ports": firewallHelp = true
        case "retry": Task { await core.refresh() }
        case "open_phone": core.openPhone()
        default: break
        }
    }

    static let mirroringGlyph: NSImage? = {
        guard let url = Bundle.main.url(forResource: "co.lxe.PhoneUse-mirroring-symbolic", withExtension: "svg"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.isTemplate = true
        img.size = NSSize(width: 16, height: 16)  // inline, at body text size
        return img
    }()

    private func symbol(_ icon: String?) -> String {
        switch icon {
        case "keyboard": "keyboard"
        case "offline": "wifi.exclamationmark"
        case "bluetooth": "iphone.radiowaves.left.and.right"
        default: core.running ? "iphone" : "iphone.slash"
        }
    }

    private func detail(_ text: String, bold: String?) -> AttributedString {
        var s = AttributedString(text)
        if let bold, let r = s.range(of: bold) { s[r].inlinePresentationIntent = .stronglyEmphasized }
        return s
    }

    private var firewallText: String {
        "The Mac's firewall asks whether Phone Use and UxPlay may accept incoming connections the first time "
            + "they listen. Choose Allow. If you chose Don't Allow, turn them on in System Settings › Network › "
            + "Firewall › Options."
    }
}

struct Prominent: ViewModifier {
    var on: Bool
    func body(content: Content) -> some View {
        if on { content.buttonStyle(.borderedProminent) } else { content.buttonStyle(.bordered) }
    }
}

func openFirewallSettings() {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension?Firewall")!)
}

/// A row that opens something: a title, a dim subtitle, and a chevron.
struct NavRow: View {
    var title: String
    var subtitle: String?
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle { Text(subtitle).font(.callout).foregroundStyle(.secondary) }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: Agents

struct AgentsTab: View {
    @EnvironmentObject var core: Core
    @State private var newPasscode = ""
    @State private var confirmForget = false

    var body: some View {
        let mode = AgentMode(rawValue: core.state?.session?.mode ?? "auto") ?? .auto
        let seconds = core.state?.session?.seconds ?? 10
        Form {
            Section {
                Picker(selection: Binding(get: { mode }, set: { setMode($0, seconds) })) {
                    ForEach(AgentMode.allCases) { Text($0.title).tag($0) }
                } label: {
                    Text("Agent control")
                    Text("What happens when an agent wants the phone")
                }
                if mode == .countdown {
                    Picker(selection: Binding(get: { nearestDelay(seconds) }, set: { setMode(.countdown, $0) })) {
                        ForEach(agentDelays, id: \.self) { Text("\($0) seconds").tag($0) }
                    } label: {
                        Text("Delay")
                        Text("You can stop the agent until then")
                    }
                }
                claudeRow
            }
            .disabled(!core.running)

            Section {
                LabeledContent("Passcode", value: saved ? "Saved" : "Not saved")
                HStack {
                    SecureField(saved ? "Replace Passcode" : "Save Passcode", text: $newPasscode)
                        .onSubmit(savePasscode)
                    Button("Save", action: savePasscode).disabled(newPasscode.isEmpty)
                }
            } header: {
                HStack {
                    Text("Unlock")
                    Spacer()
                    if saved {
                        Button("Forget…", role: .destructive) { confirmForget = true }
                            .buttonStyle(.link).foregroundStyle(.red).font(.callout)
                    }
                }
            } footer: {
                Text("Phone Use types the passcode only after you allow each Unlock.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .disabled(!core.running)
        }
        .formStyle(.grouped)
        .confirmationDialog("Forget the passcode?", isPresented: $confirmForget) {
            Button("Forget", role: .destructive) {
                core.change("/api/passcode", nil, method: "DELETE", done: "Passcode forgotten")
            }
        } message: {
            Text("Unlock stops working until you save it again.")
        }
    }

    private var saved: Bool { core.state?.passcode?.saved ?? false }

    @ViewBuilder private var claudeRow: some View {
        let c = core.state?.claude
        let ok = c?.connected ?? false
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude Code")
                Text(ok ? "Claude Code can see and use the phone"
                     : c?.claude == false ? "Claude Code isn't installed" : "Let Claude Code see and use the phone")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button(ok ? "Disconnect" : "Connect") { core.claude(connect: !ok) }
                .disabled(!(c?.claude ?? false) && !ok)
        }
    }

    private func setMode(_ m: AgentMode, _ secs: Int) {
        core.change("/api/session/ask", ["mode": m.rawValue, "seconds": secs])
    }

    private func nearestDelay(_ s: Int) -> Int { agentDelays.min { abs($0 - s) < abs($1 - s) } ?? 10 }

    private func savePasscode() {
        let code = newPasscode
        guard !code.isEmpty else { return }
        newPasscode = ""
        core.change("/api/passcode", ["code": code], done: "Passcode saved")
    }
}

// MARK: Bridge

struct BridgeTab: View {
    @EnvironmentObject var core: Core
    @State private var setup: Bool? = nil   // nil: no sheet; false: set up; true: change the Wi-Fi network
    @State private var confirmForget = false

    var body: some View {
        Form {
            let b = core.state?.bridge
            if let saved = b?.saved {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bridge \(String(saved.id.suffix(4)))")
                            let notConnected = b?.status?.error == nil && b?.status?.connected != true
                            Text(notConnected ? "On the iPhone: Settings › Bluetooth › PhoneUse Bridge" : saved.ip ?? "")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        bridgeState(b?.status)
                    }
                    Toggle(isOn: Binding(get: { saved.use ?? true },
                                         set: { core.change("/api/bridge/use", ["on": $0]) })) {
                        Text("Enable Input")
                    }
                    Button { setup = true } label: {
                        HStack {
                            Text("Wi-Fi Network")
                            Spacer()
                            Text(saved.ssid ?? "").foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .disabled(!core.running)
            } else {
                Section {
                    Button { setup = false } label: { NavRow(title: "Set Up Bridge") }
                        .buttonStyle(.plain)
                        .disabled(!core.running)
                }
            }
            if let fw = core.state?.firewall, core.state?.confirmed != true {
                Section("Network") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Firewall")
                            Text("If \(core.state?.name ?? "PhoneUse") is missing from Screen Mirroring on the iPhone, "
                                 + (fw == "macos" ? "the Mac's firewall" : fw) + " is blocking it.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Firewall Settings…", action: openFirewallSettings)
                    }
                }
            }
            if b?.saved != nil {  // at the bottom of the tab, as in the Linux window
                Section {
                    Button("Forget Bridge…", role: .destructive) { confirmForget = true }
                        .buttonStyle(.borderedProminent).tint(.red).buttonBorderShape(.capsule)
                        .frame(maxWidth: .infinity)
                        .disabled(!core.running)
                }
                .listRowBackground(Color.clear)
            }
        }
        .formStyle(.grouped)
        .sheet(item: Binding(get: { setup.map { SetupMode(change: $0) } }, set: { setup = $0?.change })) {
            BridgeSetupSheet(change: $0.change)
        }
        .confirmationDialog("Forget the bridge?", isPresented: $confirmForget) {
            Button("Forget", role: .destructive) { forget() }
        } message: {
            Text("The bridge resets and disconnects from your iPhone. To use it again, hold its lower button for "
                 + "3 seconds and set it up.")
        }
    }

    /// DELETE /api/bridge resets the bridge too when it answers ("reset"); otherwise only this Mac forgets it.
    private func forget() {
        Task {
            do {
                let j = try await core.send("/api/bridge", nil, method: "DELETE")
                core.message = j["reset"] as? Bool == true
                    ? "Bridge reset. Also forget PhoneUse Bridge in the iPhone's Bluetooth settings"
                    : "Bridge removed, but it didn't respond to the reset"
            } catch {
                core.message = "Couldn't forget the bridge: \(error.localizedDescription)"
            }
            await core.refresh()
        }
    }

    @ViewBuilder private func bridgeState(_ st: BridgeStatus?) -> some View {
        if st?.error != nil {
            Text("Offline").foregroundStyle(.red)
        } else if st?.connected == true {
            Text(st?.phone ?? "iPhone").foregroundStyle(.green)
        } else {
            Text("iPhone not connected").foregroundStyle(.orange)
        }
    }
}

struct SetupMode: Identifiable {
    var change: Bool
    var id: Bool { change }
}

/// The hero's numbered steps (overview's "steps"): dim numbers, left-aligned text, the block centered. The
/// receiver's name ("bold") is bold, and "{mirroring}" is Control Center's Screen Mirroring glyph.
struct HeroSteps: View {
    var steps: [String]
    var bold: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(i + 1).").foregroundStyle(.secondary).monospacedDigit()
                    line(step).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: 380)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.top, 4)
    }

    private func line(_ step: String) -> Text {
        let parts = step.components(separatedBy: "{mirroring}")
        var text = Text(styled(parts[0]))
        for part in parts.dropFirst() {
            if let glyph = HeroView.mirroringGlyph {
                text = text + Text(Image(nsImage: glyph).renderingMode(.template)).baselineOffset(-2)
            }
            text = text + Text(styled(part))
        }
        return text
    }

    private func styled(_ s: String) -> AttributedString {
        var a = AttributedString(s)
        if let bold, !bold.isEmpty {
            var from = a.startIndex
            while from < a.endIndex, let r = a[from...].range(of: bold) {
                a[r].inlinePresentationIntent = .stronglyEmphasized
                from = r.upperBound
            }
        }
        return a
    }
}
