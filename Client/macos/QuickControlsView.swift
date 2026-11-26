//
//  QuickControlsView.swift
//  The menu-bar panel: the everyday controls as Control Center-style modules.
//

import SwiftUI

struct QuickControlsView: View {
    let openWindow: () -> Void
    let quit: () -> Void

    @ObservedObject private var model = HeadphonesModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.connected {
                connectedContent
            } else {
                disconnectedContent
            }
            HStack {
                Button("Open SonyBridge…", action: openWindow)
                Spacer()
                Button("Quit", action: quit)
            }
            .glassButtonStyle()
            .padding(.top, 4)
        }
        .padding(14)
        .frame(width: 320)
    }

    private var disconnectedContent: some View {
        VStack(spacing: 10) {
            Image(systemName: "headphones")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: 64, height: 64)
                .glassSurface(in: Circle())
            Text("No Headphones Connected")
                .font(.headline)
            errorText
            ConnectButton(model: model)
        }
        .frame(maxWidth: .infinity)
        .module(padding: 16)
    }

    @ViewBuilder
    private var connectedContent: some View {
        HStack(spacing: 10) {
            ProductImage(deviceName: model.deviceName, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.deviceName)
                    .font(.headline)
                    .lineLimit(1)
                BatterySummary(model: model)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .module(padding: 10)

        NoiseModeTiles(model: model, diameter: 46)
            .module(padding: 12)

        if model.mode == .ambientSound {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ambient Sound")
                    .font(.subheadline.weight(.semibold))
                AmbientLevelSlider(model: model)
                if model.focusOnVoiceAvailable {
                    HStack {
                        Text("Focus on voice")
                        Spacer()
                        FocusOnVoiceToggle(model: model)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                    }
                }
            }
            .module()
        }

        if model.supportsEqualizer {
            HStack {
                Label("Equalizer", systemImage: "slider.vertical.3")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                EqualizerPicker(model: model, title: "Equalizer")
                    .labelsHidden()
                    .fixedSize()
            }
            .module(padding: 10)
        }

        if model.hasPlaybackPinState {
            playbackModule
        }

        errorText
    }

    private var playbackModule: some View {
        let canPin = model.thisMac != nil && !model.playbackPinnedToThisMac
        return VStack(alignment: .leading, spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.playbackPinned ? "Playback fixed to" : "Playing on")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(playbackName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
            } icon: {
                Image(systemName: model.playbackPinned ? "lock.fill" : "speaker.wave.2.fill")
                    .foregroundStyle(.secondary)
            }
            if canPin || model.playbackPinned {
                HStack {
                    if canPin {
                        Button("Pin to This Mac", action: model.pinPlaybackToThisMac)
                    }
                    if model.playbackPinned {
                        Button("Unfix") { model.setPlaybackPinned(false) }
                    }
                }
                .glassButtonStyle()
                .controlSize(.small)
                .disabled(model.multipointBusy)
            }
        }
        .module()
    }

    private var playbackName: String {
        guard let device = model.playbackDevice else { return "No playback device" }
        return device.name.isEmpty ? device.address : device.name
    }

    @ViewBuilder
    private var errorText: some View {
        if let error = model.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
