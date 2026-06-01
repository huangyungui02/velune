import SwiftUI

struct GlimmerDaySection<Content: View>: View {
    let section: GlimmerDayGroup
    @ViewBuilder var content: (Glimmer, Bool) -> Content

    private var dateString: String {
        section.day.formatted(.dateTime.year().month(.wide).day())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlimmerDayHeader(dateString: dateString)

            LazyVStack(spacing: 12) {
                ForEach(Array(section.glimmers.enumerated()), id: \.element.id) { index, glimmer in
                    content(glimmer, index == 0)
                }
            }
            .background(alignment: .leading) {
                Rectangle()
                    .fill(UITheme.primaryText.opacity(0.08))
                    .frame(width: 0.5)
                    .padding(.leading, 21)
            }
        }
    }
}

struct GlimmerTimelineRow: View {
    let glimmer: Glimmer
    let isFeatured: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            TimelineStamp(date: glimmer.createdAt, isFeatured: isFeatured)
            GlimmerTimelineCard(glimmer: glimmer, isFeatured: isFeatured)
        }
    }
}

private struct GlimmerDayHeader: View {
    let dateString: String

    var body: some View {
        Text(dateString)
            .font(.system(size: 15, weight: .light, design: .serif))
            .tracking(1.0)
            .foregroundStyle(UITheme.primaryText.opacity(0.85))
            .padding(.leading, 58)
    }
}

private struct GlimmerTimelineCard: View {
    let glimmer: Glimmer
    let isFeatured: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(glimmer.content)
                .font(.system(size: 14.5, weight: .light, design: .serif))
                .lineSpacing(7.0)
                .tracking(0.8)
                .foregroundStyle(UITheme.primaryText.opacity(0.88))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            GlimmerKeywordChips(keywords: Array(glimmer.keywords.prefix(3)))
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 16)
        .background(
            .ultraThinMaterial.opacity(0.2),
            in: .rect(cornerRadius: 16, style: .continuous)
        )
        .background {
            RadialGradient(
                colors: [
                    UITheme.glimmerGlow.opacity(0.03),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 150
            )
            .clipShape(.rect(cornerRadius: 16, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.03),
                            .white.opacity(0.005)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

struct GlimmerKeywordChips: View {
    let keywords: [String]

    var body: some View {
        if !keywords.isEmpty {
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(keywords, id: \.self) { keyword in
                    Text(keyword)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(UITheme.glimmerGlow.opacity(0.82))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(UITheme.glimmerGlow.opacity(0.08), in: .capsule)
                        .overlay {
                            Capsule()
                                .stroke(UITheme.glimmerGlow.opacity(0.15), lineWidth: 0.5)
                        }
                }
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let rows = rows(for: subviews, proposal: proposal)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.last.map { $0.y + $0.height } ?? 0
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        for row in rows(for: subviews, proposal: ProposedViewSize(width: bounds.width, height: proposal.height)) {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private func rows(for subviews: Subviews, proposal: ProposedViewSize) -> [FlowRow] {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var rows: [FlowRow] = []
        var currentItems: [FlowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        var y: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if nextWidth > maxWidth, !currentItems.isEmpty {
                rows.append(FlowRow(y: y, width: currentWidth, height: currentHeight, items: currentItems))
                y += currentHeight + lineSpacing
                currentItems = [FlowItem(index: index, x: 0, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(FlowItem(index: index, x: currentItems.isEmpty ? 0 : currentWidth + spacing, size: size))
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(FlowRow(y: y, width: currentWidth, height: currentHeight, items: currentItems))
        }

        return rows
    }
}

private struct FlowRow {
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var items: [FlowItem]
}

private struct FlowItem {
    var index: Int
    var x: CGFloat
    var size: CGSize
}

private struct TimelineStamp: View {
    let date: Date
    let isFeatured: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                .font(.system(size: 10, weight: isFeatured ? .medium : .light, design: .serif))
                .monospacedDigit()
                .foregroundStyle(UITheme.secondaryText.opacity(isFeatured ? 0.9 : 0.6))
                .frame(width: 38, alignment: .trailing)

            ZStack {
                if isFeatured {
                    Circle()
                        .stroke(UITheme.glimmerGlow.opacity(0.3), lineWidth: 1)
                        .frame(width: 10, height: 10)
                    
                    Circle()
                        .fill(UITheme.glimmerGlow)
                        .frame(width: 5, height: 5)
                } else {
                    Circle()
                        .fill(UITheme.primaryText.opacity(0.35))
                        .frame(width: 3.5, height: 3.5)
                }
            }
            .frame(width: 14, height: 14)
            .padding(.vertical, 2)
        }
        .frame(width: 42)
        .padding(.top, 9)
    }
}
