//
//  ContentView.swift
//  The main window: glass cards floating over a translucent, desktop-tinted window.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var model = HeadphonesModel.shared

    var body: some View {
        Group {
            if model.connected {
                connectedView
            } else {
                DisconnectedView(model: model)
            }
        }
        .frame(minWidth: 420, idealWidth: 460, maxWidth: 720, minHeight: 480)
        .background(WindowBackdrop().ignoresSafeArea())
        .toolbarBackground(.hidden, for: .windowToolbar)
        .navigationTitle("SonyBridge")
        .toolbar {
            if model.connected {
                ToolbarItem {
                    Button(action: model.disconnect) {
                        Label("Disconnect", systemImage: "power")
                    }
                    .help("Disconnect the headphones")
                }
            }
        }
    }

    // MARK: - Connected

    private var connectedView: some View {
        ScrollView {
            GlassGroup(spacing: 20) {
                VStack(spacing: 18) {
                    hero
                    if let error = model.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .glassSurface(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    if model.mode == .ambientSound {
                        ambientCard
                    }
                    if model.supportsEqualizer {
                        equalizerCard
                    }
                    if model.supportsDsee {
                        GlassCard("Sound Quality") {
                            SettingToggle("DSEE", subtitle: "Upscale compressed audio",
                                          isOn: Binding(get: { model.dsee }, set: { model.setDsee($0) }))
                        }
                    }
                    if model.multipointLoading || model.hasPairedDevices || model.hasPlaybackPinState {
                        devicesCard
                    }
                    if model.hasAdaptiveVolume || model.hasSpeakToChat || model.hasAutoPowerOff || model.hasMultipointSetting {
                        settingsCard
                    }
                    aboutCard
                    Text("SonyBridge is not affiliated with Sony.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .scrollIndicators(.automatic)
    }

    // The device floating on the window glass: image, name, battery pills and the three mode tiles.
    private var hero: some View {
        VStack(spacing: 14) {
            ProductImage(deviceName: model.deviceName, size: 150)
            Text(model.deviceName)
                .font(.title.weight(.semibold))
            BatteryChips(model: model)
            NoiseModeTiles(model: model, diameter: 56)
                .frame(maxWidth: 340)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private var ambientCard: some View {
        GlassCard("Ambient Sound") {
            SettingRow("Level") {
                AmbientLevelSlider(model: model)
                    .frame(maxWidth: 240)
            }
            if model.focusOnVoiceAvailable {
                SettingToggle("Focus on voice", isOn: Binding(
                    get: { model.focusOnVoice },
                    set: { model.setFocusOnVoice($0) }
                ))
            }
        }
    }

    // MARK: - Equalizer

    private static let fiveBandLabels = ["400 Hz", "1 kHz", "2.5 kHz", "6.3 kHz", "16 kHz"]
    private static let tenBandLabels = ["31 Hz", "63 Hz", "125 Hz", "250 Hz", "500 Hz",
                                        "1 kHz", "2 kHz", "4 kHz", "8 kHz", "16 kHz"]

    private var equalizerCard: some View {
        GlassCard("Equalizer") {
            SettingRow("Preset") {
                EqualizerPicker(model: model)
                    .labelsHidden()
                    .fixedSize()
            }
            if model.eqPreset == 0xA0 {
                let labels = model.tenBandEqualizer ? Self.tenBandLabels : Self.fiveBandLabels
                ForEach(0..<min(model.eqBands.count, labels.count), id: \.self) { i in
                    eqBandRow(labels[i], value: Binding(
                        get: { Double(model.eqBands[i]) },
                        set: { model.eqBands[i] = Int($0.rounded()); model.applyCustomEq() }
                    ), display: model.eqBands[i], raw: model.tenBandEqualizer)
                }
                if !model.tenBandEqualizer {
                    eqBandRow("Clear Bass", value: Binding(
                        get: { Double(model.clearBass) },
                        set: { model.clearBass = Int($0.rounded()); model.applyCustomEq() }
                    ), display: model.clearBass)
                }
            }
        }
    }

    // raw: the ten-band layout's 0...12 device steps (no dB mapping is known yet), shown unsigned.
    private func eqBandRow(_ label: String, value: Binding<Double>, display: Int, raw: Bool = false) -> some View {
        SettingRow(label) {
            HStack {
                Slider(value: value, in: raw ? 0...12 : -10...10, step: 1)
                Text(raw ? "\(display)" : "\(display > 0 ? "+" : "")\(display)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)
            }
            .frame(maxWidth: 240)
        }
    }

    // MARK: - Devices (multipoint)

    private var devicesCard: some View {
        GlassCard("Devices", accessory: {
            if model.refreshingMultipoint || model.multipointBusy {
                ProgressView().controlSize(.small)
            } else {
                Button(action: model.refreshMultipoint) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh the device list")
                .disabled(model.multipointLoading)
            }
        }) {
            if model.multipointLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Reading devices from the headset…")
                        .foregroundStyle(.secondary)
                }
            }
            if model.hasPlaybackPinState {
                SettingToggle("Fix playback device", subtitle: playbackCaption,
                              isOn: Binding(get: { model.playbackPinned }, set: { model.setPlaybackPinned($0) }))
                    .disabled(model.multipointBusy)
            }
            if model.hasPairedDevices {
                ForEach(model.pairedDevices.sorted(by: deviceOrder)) { device in
                    deviceRow(device)
                }
            } else if !model.multipointLoading {
                Text("This headset didn't return a device list.")
                    .foregroundStyle(.secondary)
            }
            if !model.multipointLoading {
                HStack {
                    Text(model.multipointBusy ? "Sending…" : "Switching and fixing playback are experimental.")
                    Spacer()
                    Button("Copy Diagnostics", action: copyMultipointDiagnostics)
                        .buttonStyle(.link)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var playbackCaption: String {
        guard let device = model.playbackDevice else { return "Switches automatically" }
        let name = device.name.isEmpty ? device.address : device.name
        return model.playbackPinned ? "Fixed to \(name)" : "Playing on \(name)"
    }

    // Connected devices first, by slot; then paired-only ones.
    private func deviceOrder(_ a: PairedDeviceInfo, _ b: PairedDeviceInfo) -> Bool {
        if a.connected != b.connected { return a.connected }
        return a.slot < b.slot
    }

    private func deviceRow(_ device: PairedDeviceInfo) -> some View {
        HStack(spacing: 10) {
            Image(systemName: deviceSymbol(device.classOfDevice))
                .foregroundStyle(device.connected ? .primary : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name.isEmpty ? device.address : device.name)
                    .lineLimit(1)
                    .foregroundStyle(device.connected ? .primary : .secondary)
                Text(deviceCaption(device))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if device.playback {
                Image(systemName: model.playbackPinned ? "lock.fill" : "speaker.wave.2.fill")
                    .foregroundStyle(.secondary)
                    .help(model.playbackPinned ? "Playback is fixed to this device" : "Playing on this device")
            }
            if device.connected && model.hasPlaybackPinState {
                Menu {
                    Button("Switch Playback and Fix") { model.switchPlayback(to: device, fix: true) }
                    if !device.playback {
                        Button("Switch Playback") { model.switchPlayback(to: device, fix: false) }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .disabled(model.multipointBusy)
            }
        }
    }

    private func deviceCaption(_ device: PairedDeviceInfo) -> String {
        let state = device.connected ? "Connected" : "Paired"
        return device.isThisMac ? "This Mac · \(state)" : state
    }

    // Major device class lives in bits 8-12 of the class of device (1 = computer, 2 = phone).
    private func deviceSymbol(_ classOfDevice: Int) -> String {
        guard classOfDevice >= 0, classOfDevice != 0xFFFFFF else { return "dot.radiowaves.left.and.right" }
        switch (classOfDevice >> 8) & 0x1F {
        case 1: return "laptopcomputer"
        case 2: return "iphone"
        default: return "dot.radiowaves.left.and.right"
        }
    }

    private func copyMultipointDiagnostics() {
        let header = "\(model.deviceName) · fw \(model.firmware) · \(model.protocolVersion)\n"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(header + model.multipointDiagnostics, forType: .string)
    }

    // MARK: - Settings

    private static let autoPowerOffOptions = ["Off", "After 5 minutes", "After 30 minutes", "After 1 hour",
                                              "After 3 hours", "When taken off"]

    private var settingsCard: some View {
        GlassCard("Settings") {
            if model.hasAdaptiveVolume {
                SettingToggle("Adaptive volume", subtitle: "Adjust the volume to your surroundings",
                              isOn: Binding(get: { model.adaptiveVolume }, set: { model.setAdaptiveVolume($0) }))
            }
            if model.hasSpeakToChat {
                SettingToggle("Speak-to-Chat", subtitle: "Pause music when you talk",
                              isOn: Binding(get: { model.speakToChat }, set: { model.setSpeakToChat($0) }))
                SettingToggle("Keep Speak-to-Chat off when connecting", isOn: $model.keepSpeakToChatOff)
            }
            if model.hasMultipointSetting {
                SettingToggle("Connect to 2 devices", subtitle: "Stay connected to two devices at once",
                              isOn: Binding(get: { model.multipointEnabled }, set: { model.setMultipoint($0) }))
            }
            if model.hasAutoPowerOff {
                SettingRow("Automatic power off") {
                    Picker("Automatic power off", selection: Binding(
                        get: { model.autoPowerOff },
                        set: { model.setAutoPowerOff($0) }
                    )) {
                        ForEach(Self.autoPowerOffOptions.indices, id: \.self) { i in
                            Text(Self.autoPowerOffOptions[i]).tag(i)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        GlassCard("About") {
            if model.hasDualBattery {
                infoRow("Left", batteryText(model.batteryLeft, model.batteryLeftCharging))
                infoRow("Right", batteryText(model.batteryRight, model.batteryRightCharging))
                if model.batteryCase >= 0 {
                    infoRow("Case", batteryText(model.batteryCase, model.batteryCaseCharging))
                }
            } else if model.batteryLevel >= 0 {
                infoRow("Battery", batteryText(model.batteryLevel, model.batteryCharging))
            }
            if !model.codec.isEmpty { infoRow("Codec", model.codec) }
            if !model.firmware.isEmpty { infoRow("Firmware", model.firmware) }
            if !model.protocolVersion.isEmpty { infoRow("Protocol", model.protocolVersion) }
            if !model.deviceMac.isEmpty { infoRow("Bluetooth address", model.deviceMac) }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        SettingRow(label) {
            Text(value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private func batteryText(_ level: Int, _ charging: Bool) -> String {
        guard level >= 0 else { return "—" }
        return "\(level)%\(charging ? ", charging" : "")"
    }
}

// MARK: - Disconnected

private struct DisconnectedView: View {
    @ObservedObject var model: HeadphonesModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "headphones")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: 120, height: 120)
                .glassSurface(in: Circle())
                .padding(.bottom, 8)
            Text("No Headphones Connected")
                .font(.title2.weight(.semibold))
            Text("Pair your headphones in Bluetooth settings, then connect.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            HStack {
                ConnectButton(model: model)
                    .controlSize(.large)
                Button("Bluetooth Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .glassButtonStyle()
                .controlSize(.large)
            }
            .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared with the menu-bar panel

enum EQPresets {
    static let fiveBand: [(String, Int)] = [
        ("Off", 0x00), ("Bright", 0x10), ("Excited", 0x11),
        ("Mellow", 0x12), ("Relaxed", 0x13), ("Vocal", 0x14),
        ("Treble", 0x15), ("Bass", 0x16), ("Speech", 0x17),
        ("Manual", 0xA0)
    ]
    // WH-1000XM6: only Off and Custom have confirmed preset codes on the ten-band layout; its other preset
    // bytes (0x20, 0x30-0x33, 0xa1-0xa2) are unnamed, and the 5-band codes above don't apply to it.
    static let tenBand: [(String, Int)] = [("Off", 0x00), ("Custom", 0xA0)]

    static func list(tenBand: Bool) -> [(String, Int)] { tenBand ? Self.tenBand : fiveBand }
}

extension SHCAmbientMode {
    static let pickerOrder: [SHCAmbientMode] = [.noiseCanceling, .ambientSound, .off]

    var symbol: String {
        switch self {
        case .noiseCanceling: return "waveform.slash"
        case .ambientSound: return "ear.badge.waveform"
        default: return "circle.slash"
        }
    }

    var displayName: String {
        switch self {
        case .noiseCanceling: return "Noise Canceling"
        case .ambientSound: return "Ambient Sound"
        default: return "Off"
        }
    }
}

// The bundled product cutout matching the device name (e.g. "WH-CH720N" -> "wh-ch720n"), or a generic
// headphones symbol for models without one.
struct ProductImage: View {
    let deviceName: String
    let size: CGFloat

    var body: some View {
        if let image = NSImage(named: deviceName.lowercased().replacingOccurrences(of: " ", with: "-")) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "headphones")
                .font(.system(size: size * 0.5, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }
}

// One line of battery status: "82%" for headphones, "L 80% · R 75% · Case 50%" for earbuds.
struct BatterySummary: View {
    @ObservedObject var model: HeadphonesModel

    var body: some View {
        HStack(spacing: 8) {
            if model.hasDualBattery {
                // A docked / powered-down earbud reports -1: show it as "--" so it reads as "in the case".
                unit("L", model.batteryLeft, model.batteryLeftCharging)
                unit("R", model.batteryRight, model.batteryRightCharging)
                if model.batteryCase >= 0 {
                    unit("Case", model.batteryCase, model.batteryCaseCharging)
                }
            } else if model.batteryLevel >= 0 {
                unit(nil, model.batteryLevel, model.batteryCharging)
            } else {
                Text("Connected")
            }
            if !model.codec.isEmpty {
                Text(model.codec)
            }
        }
        .monospacedDigit()
    }

    private func unit(_ label: String?, _ level: Int, _ charging: Bool) -> some View {
        BatteryUnit(label: label, level: level, charging: charging)
    }
}

// One battery reading with a level-matched symbol; red when low, a bolt while charging.
struct BatteryUnit: View {
    let label: String?
    let level: Int
    let charging: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol(level, charging))
                .foregroundStyle(level >= 0 && level <= 20 && !charging ? Color.red : Color.secondary)
            Text([label, level < 0 ? "--" : "\(level)%"].compactMap { $0 }.joined(separator: " "))
        }
    }

    private func symbol(_ level: Int, _ charging: Bool) -> String {
        if charging { return "battery.100.bolt" }
        switch level {
        case ..<0: return "battery.0"
        case ...15: return "battery.0"
        case ...40: return "battery.25"
        case ...65: return "battery.50"
        case ...90: return "battery.75"
        default: return "battery.100"
        }
    }
}

// Battery and codec as small glass capsules under the device name.
struct BatteryChips: View {
    @ObservedObject var model: HeadphonesModel

    var body: some View {
        GlassGroup(spacing: 8) {
            HStack(spacing: 8) {
                if model.hasDualBattery {
                    chip { BatteryUnit(label: "L", level: model.batteryLeft, charging: model.batteryLeftCharging) }
                    chip { BatteryUnit(label: "R", level: model.batteryRight, charging: model.batteryRightCharging) }
                    if model.batteryCase >= 0 {
                        chip { BatteryUnit(label: "Case", level: model.batteryCase, charging: model.batteryCaseCharging) }
                    }
                } else if model.batteryLevel >= 0 {
                    chip { BatteryUnit(label: nil, level: model.batteryLevel, charging: model.batteryCharging) }
                }
                if !model.codec.isEmpty {
                    chip { Text(model.codec) }
                }
            }
        }
    }

    private func chip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.callout.weight(.medium))
            .monospacedDigit()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassSurface(in: Capsule())
    }
}

// Noise Canceling / Ambient Sound / Off as round glass buttons, like the modules in Control Center.
struct NoiseModeTiles: View {
    @ObservedObject var model: HeadphonesModel
    var diameter: CGFloat = 52

    var body: some View {
        GlassGroup(spacing: 16) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(SHCAmbientMode.pickerOrder, id: \.self) { tile($0) }
            }
        }
    }

    private func tile(_ mode: SHCAmbientMode) -> some View {
        let selected = model.mode == mode
        return Button { model.setMode(mode) } label: {
            VStack(spacing: 7) {
                Image(systemName: mode.symbol)
                    .font(.system(size: diameter * 0.36, weight: .medium))
                    .foregroundStyle(selected ? Color.white : Color.primary)
                    .frame(width: diameter, height: diameter)
                    .glassSurface(in: Circle(), tint: selected ? .accentColor : nil, interactive: true)
                Text(mode.displayName)
                    .font(.caption.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .primary : .secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.displayName)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(.smooth(duration: 0.25), value: selected)
    }
}

struct AmbientModePicker: View {
    @ObservedObject var model: HeadphonesModel

    var body: some View {
        Picker("Mode", selection: Binding(get: { model.mode }, set: { model.setMode($0) })) {
            ForEach(SHCAmbientMode.pickerOrder, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

struct AmbientLevelSlider: View {
    @ObservedObject var model: HeadphonesModel

    var body: some View {
        HStack {
            Slider(
                value: Binding(
                    get: { Double(model.ambientLevel) },
                    set: { model.setLevel(Int($0.rounded())) }
                ),
                in: 1...Double(max(2, model.maxAmbientLevel)),
                step: 1
            )
            Text("\(model.ambientLevel)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)
        }
    }
}

struct FocusOnVoiceToggle: View {
    @ObservedObject var model: HeadphonesModel

    var body: some View {
        Toggle("Focus on voice", isOn: Binding(
            get: { model.focusOnVoice },
            set: { model.setFocusOnVoice($0) }
        ))
    }
}

struct EqualizerPicker: View {
    @ObservedObject var model: HeadphonesModel
    var title = "Preset"

    var body: some View {
        Picker(title, selection: Binding(get: { model.eqPreset }, set: { model.setEqualizer($0) })) {
            ForEach(EQPresets.list(tenBand: model.tenBandEqualizer), id: \.1) { preset in
                Text(preset.0).tag(preset.1)
            }
        }
    }
}

struct ConnectButton: View {
    @ObservedObject var model: HeadphonesModel

    var body: some View {
        // Activate first: from the menu-bar panel the app isn't frontmost, and the device picker the
        // connect shows would open behind other apps.
        Button(model.connecting ? "Connecting…" : "Connect") {
            NSApp.activate(ignoringOtherApps: true)
            model.connect()
        }
        .glassButtonStyle(prominent: true)
        .keyboardShortcut(.defaultAction)
        .disabled(model.connecting)
    }
}
