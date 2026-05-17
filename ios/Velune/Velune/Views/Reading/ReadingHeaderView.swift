import SwiftUI

struct ReadingHeaderView: View {
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding
    @Binding var selectedTab: ReadingTab
    let hasActiveSearch: Bool
    let tabNamespace: Namespace.ID
    let onClearSearch: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ReadingSearchField(
                text: $searchText,
                isFocused: isSearchFocused,
                onClear: onClearSearch
            )
            .padding(.horizontal, 20)

            if !hasActiveSearch {
                HStack(spacing: 32) {
                    ForEach(ReadingTab.allCases) { tab in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text(tab.titleKey)
                                    .font(.title3)
                                    .fontWeight(selectedTab == tab ? .semibold : .medium)
                                    .fontDesign(.serif)
                                    .foregroundStyle(selectedTab == tab ? UITheme.primaryText : UITheme.secondaryText)

                                if selectedTab == tab {
                                    Capsule()
                                        .fill(UITheme.primaryText)
                                        .frame(width: 24, height: 2)
                                        .matchedGeometryEffect(id: "TabIndicator", in: tabNamespace)
                                } else {
                                    Color.clear
                                        .frame(width: 24, height: 2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
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
        .glassEffect(in: .capsule)
    }
}
