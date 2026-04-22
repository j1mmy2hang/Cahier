import SwiftUI

enum CahierPlusTab: String, CaseIterable, Identifiable {
    case note = "Note"
    case review = "Review"
    var id: String { rawValue }
}

struct CahierPlusView: View {
    @Environment(AppState.self) private var appState
    @State private var tab: CahierPlusTab = .note

    var body: some View {
        ZStack(alignment: .top) {
            // Content fills the whole window (including under the floating
            // titlebar area) so background material is continuous.
            Group {
                switch tab {
                case .note:
                    VocabTableView()
                case .review:
                    ReviewView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Leaves room for the floating tab bar at the top.
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: titlebarHeight)
            }

            // Floating liquid-glass tab bar, centered; leaves room on the left
            // for the traffic lights so they never sit under the capsule.
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                PlusTabSwitcher(selection: $tab)
                Spacer(minLength: 0)
            }
            .frame(height: titlebarHeight)
            .padding(.top, 2)
        }
    }

    /// Matches the native macOS titlebar height so the tab bar sits where
    /// a titlebar would be (and clears the traffic lights).
    private var titlebarHeight: CGFloat { 52 }
}

// MARK: - Tab Switcher (Liquid Glass, sliding indicator)

private struct PlusTabSwitcher: View {
    @Binding var selection: CahierPlusTab
    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CahierPlusTab.allCases) { tab in
                PlusTabLabel(
                    title: tab.rawValue,
                    isSelected: selection == tab,
                    namespace: pillNamespace
                ) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78, blendDuration: 0.1)) {
                        selection = tab
                    }
                }
            }
        }
        .padding(4)
        .background(
            CapsuleGlassBackground()
        )
        .fixedSize()
    }
}

private struct PlusTabLabel: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Sliding pill — only the selected tab renders it, and the
                // matchedGeometryEffect animates its position/size between
                // tabs every time `isSelected` flips.
                if isSelected {
                    SelectionPill()
                        .matchedGeometryEffect(id: "plus-tab-pill", in: namespace)
                }

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 7)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SelectionPill: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            Capsule()
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            Capsule()
                .fill(Color.primary.opacity(0.10))
                .overlay(
                    Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        }
    }
}

private struct CapsuleGlassBackground: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            Capsule()
                .fill(.clear)
                .glassEffect(.regular, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
                )
        } else {
            Capsule()
                .fill(.regularMaterial)
                .overlay(
                    Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        }
    }
}
