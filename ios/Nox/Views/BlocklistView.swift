import SwiftUI
import FamilyControls
import UIKit

/// The whole app — one screen. No nav bar, no pushes, no sheets.
struct BlocklistView: View {
    @EnvironmentObject var controller: BlockController
    @State private var showPicker = false

    private let presets = [1, 5, 15, 30, 60]
    private var locked: Bool { controller.isBlocking }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("nox")
                    .font(Theme.mono(.title2))
                    .foregroundColor(Theme.text)

                appsSection
                DomainsSection(locked: locked)   // isolated: typing never re-renders this parent
                delaySection
            }
            .padding(24)
            .contentShape(Rectangle())
            .onTapGesture { dismissKeyboard() }
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { actionBar }
        .familyActivityPicker(
            isPresented: $showPicker,
            selection: Binding(
                get: { controller.selection },
                set: { controller.saveSelection($0) }
            )
        )
    }

    // MARK: Apps

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("blocked apps")
            Text(controller.appCount == 0 ? "none" : "\(controller.appCount) selected")
                .font(Theme.mono(.body))
                .foregroundColor(Theme.text)
                .opacity(controller.appCount == 0 ? 0.4 : 1)
            if !locked {
                Button(action: { showPicker = true }) {
                    Text("+ choose apps")
                        .font(Theme.mono(.body))
                        .foregroundColor(Theme.text)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Delay

    private var delaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("turn-off delay")
            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { minutes in
                    Button(action: { controller.setDelay(minutes) }) {
                        Text("\(minutes)m")
                            .font(Theme.mono(.body))
                            .foregroundColor(controller.unlockDelayMinutes == minutes ? Theme.background : Theme.text)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(controller.unlockDelayMinutes == minutes ? Theme.text : Theme.background)
                            .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .disabled(locked)
            .opacity(locked ? 0.3 : 1)
            if locked {
                Text("locked while on")
                    .font(Theme.mono(.caption2))
                    .foregroundColor(Theme.text)
                    .opacity(0.6)
            }
        }
    }

    // MARK: Action bar

    private var actionBar: some View {
        VStack(spacing: 0) {
            Rectangle().frame(height: 1).foregroundColor(Theme.border)
            VStack(alignment: .leading, spacing: 12) {
                if !controller.isBlocking {
                    Text("while on: you cant delete apps and the clock is locked. turning off takes the full wait.")
                        .font(Theme.mono(.caption2))
                        .foregroundColor(Theme.text)
                        .opacity(0.5)
                }
                Group {
                    if !controller.isBlocking {
                        actionButton("[ turn on ]") { controller.startBlocking() }
                            .disabled(!controller.hasSomethingToBlock)
                            .opacity(controller.hasSomethingToBlock ? 1 : 0.3)
                    } else if !controller.isUnlockPending {
                        actionButton("[ turn off ]") { controller.beginUnlock() }
                    } else {
                        countdown
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background)
    }

    private var countdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, controller.unlockReadyAt?.timeIntervalSince(context.date) ?? 0)
            VStack(spacing: 12) {
                if remaining <= 0 {
                    actionButton("[ confirm — turn off ]") { controller.completeUnlock() }
                } else {
                    Text("turning off in \(format(remaining))")
                        .font(Theme.mono(.body))
                        .foregroundColor(Theme.text)
                        .frame(maxWidth: .infinity)
                }
                Button(action: { controller.cancelUnlock() }) {
                    Text("cancel")
                        .font(Theme.mono(.caption))
                        .foregroundColor(Theme.text)
                        .opacity(0.6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .terminalButton()
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Domain list + inline typer. Kept as its own view with LOCAL draft state so
/// keystrokes only re-render this — never the parent's FamilyControls picker /
/// token reads, which do slow Screen Time XPC. That re-render was the lag.
private struct DomainsSection: View {
    @EnvironmentObject var controller: BlockController
    let locked: Bool
    @State private var addingDomain = false
    @State private var draftDomain = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("blocked domains")

            if controller.blockedDomains.isEmpty && !addingDomain {
                Text("none")
                    .font(Theme.mono(.body))
                    .foregroundColor(Theme.text)
                    .opacity(0.4)
            }

            ForEach(controller.blockedDomains, id: \.self) { domain in
                HStack {
                    Text(domain)
                        .font(Theme.mono(.body))
                        .foregroundColor(Theme.text)
                    Spacer()
                    if !locked {
                        Button(action: { controller.removeDomain(domain) }) {
                            Text("[x]")
                                .font(Theme.mono(.body))
                                .foregroundColor(Theme.text)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !locked {
                if addingDomain {
                    HStack(spacing: 8) {
                        Text(">")
                            .font(Theme.mono(.body))
                            .foregroundColor(Theme.text)
                            .opacity(0.5)
                        TextField("reddit.com", text: $draftDomain)
                            .font(Theme.mono(.body))
                            .foregroundColor(Theme.text)
                            .tint(Theme.text)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($fieldFocused)
                            .submitLabel(.done)
                            .onSubmit(commitDomain)
                            .onAppear { fieldFocused = true }
                            .onChange(of: fieldFocused) { focused in
                                if !focused { finishAdding() }   // tap-out / scroll commits + closes
                            }
                    }
                } else {
                    Button(action: { addingDomain = true; draftDomain = "" }) {
                        Text("+ add domain")
                            .font(Theme.mono(.body))
                            .foregroundColor(Theme.text)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func commitDomain() {
        let trimmed = draftDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { addingDomain = false; return }
        controller.addDomain(trimmed)
        draftDomain = ""
        fieldFocused = true       // stay open for rapid multi-add
    }

    private func finishAdding() {
        let trimmed = draftDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { controller.addDomain(trimmed) }
        draftDomain = ""
        addingDomain = false
    }
}

// shared by both views (file-private)
private func sectionHeader(_ title: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(Theme.mono(.caption))
            .foregroundColor(Theme.text)
        Rectangle().frame(height: 1).foregroundColor(Theme.border)
    }
}
