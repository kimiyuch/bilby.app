#if os(iOS)
import SwiftUI

/// The clock alone, edge to edge, for an iPad on a stand or an iPhone at the table.
/// Tap to show the controls for a few seconds.
struct FullScreenClock: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showsControls = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        // The clock's background runs edge to edge; its text stays clear of the Dynamic Island.
        LiveClockView()
            .contentShape(.rect)
            .onTapGesture { reveal() }
            .overlay(alignment: .bottom) {
                if showsControls {
                    VStack(spacing: 12) {
                        ClockControls()
                        Button("Done", systemImage: "arrow.down.right.and.arrow.up.left") { dismiss() }
                            .buttonStyle(.glass)
                    }
                    .padding(.bottom, 24)
                    .transition(.opacity)
                    .onTapGesture { reveal() }
                }
            }
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            .preferredColorScheme(.dark)
            .animation(.easeInOut(duration: 0.25), value: showsControls)
    }

    private func reveal() {
        showsControls = true
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            showsControls = false
        }
    }
}
#endif
