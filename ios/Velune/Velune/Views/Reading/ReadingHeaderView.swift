import SwiftUI

struct ReadingHeaderView: View {
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding
    @Binding var selectedTab: ReadingTab
    let tabNamespace: Namespace.ID
    let onClearSearch: () -> Void

    private var isSearchingMode: Bool {
        isSearchFocused.wrappedValue || !searchText.isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            if !isSearchingMode {
                ForEach(ReadingTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.titleKey)
                            .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundStyle(selectedTab == tab ? UITheme.primaryText : UITheme.secondaryText)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background {
                                if selectedTab == tab {
                                    Capsule()
                                        .fill(Color.white.opacity(0.16))
                                        .matchedGeometryEffect(id: "ActiveTabGlass", in: tabNamespace)
                                }
                            }
                            .glassEffect(.clear, in: .capsule)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.85)),
                        removal: .opacity.combined(with: .scale(scale: 0.85))
                    ))
                }
            }

            ReadingSearchField(
                text: $searchText,
                isFocused: isSearchFocused,
                onClear: onClearSearch
            )

            if isSearchingMode {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        onClearSearch()
                    }
                } label: {
                    Text("common.cancel")
                }
                .buttonStyle(.plain)
                .foregroundStyle(UITheme.primaryText)
                .font(.system(size: 15, weight: .medium))
                .padding(.leading, 4)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSearchingMode)
    }
}

private struct ReadingSearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(UITheme.secondaryText)

            TextField("reading.search.placeholder", text: $text)
                .focused(isFocused)
                .submitLabel(.search)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(UITheme.primaryText)
                .tint(UITheme.primaryText)

            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(UITheme.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .glassEffect(.clear, in: .capsule)
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }
}
