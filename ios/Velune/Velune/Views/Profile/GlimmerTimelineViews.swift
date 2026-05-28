import SwiftUI

struct GlimmerDaySection<Content: View>: View {
    let section: GlimmerDayGroup
    @ViewBuilder var content: (Glimmer, Bool) -> Content

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: section.day)
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM / yyyy"
        return formatter.string(from: section.day)
    }

    private var isTodayOrYesterday: String? {
        let calendar = Calendar.current
        if calendar.isDateInToday(section.day) {
            return String(localized: "glimmerHistory.section.today")
        } else if calendar.isDateInYesterday(section.day) {
            return String(localized: "glimmerHistory.section.yesterday")
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlimmerDayHeader(
                dayString: dayString,
                monthYearString: monthYearString,
                relativeTag: isTodayOrYesterday
            )

            LazyVStack(spacing: 12) {
                ForEach(Array(section.glimmers.enumerated()), id: \.element.id) { index, glimmer in
                    content(glimmer, index == 0)
                }
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
    let dayString: String
    let monthYearString: String
    let relativeTag: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(dayString)
                .font(.system(size: 34, weight: .light, design: .serif))
                .foregroundStyle(UITheme.primaryText)

            Text(monthYearString)
                .font(.system(size: 11, weight: .medium, design: .serif))
                .tracking(2.0)
                .foregroundStyle(UITheme.tertiaryText)

            if let relativeTag {
                Text(relativeTag)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(UITheme.glimmerGlow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(UITheme.glimmerGlow.opacity(0.12), in: .capsule)
                    .overlay {
                        Capsule()
                            .stroke(UITheme.glimmerGlow.opacity(0.24), lineWidth: 0.5)
                    }
                    .padding(.leading, 6)
            }
        }
        .padding(.leading, 46)
    }
}

private struct GlimmerTimelineCard: View {
    let glimmer: Glimmer
    let isFeatured: Bool

    private var cornerRadius: CGFloat {
        isFeatured ? 18 : 14
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(glimmer.content)
                .font(.system(size: isFeatured ? 15.5 : 14, weight: .light, design: .serif))
                .lineSpacing(isFeatured ? 8 : 6.5)
                .tracking(0.8)
                .foregroundStyle(UITheme.primaryText.opacity(isFeatured ? 0.95 : 0.82))
                .lineLimit(isFeatured ? 3 : 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, isFeatured ? 18 : 14)
        .padding(.horizontal, 16)
        .background(
            .ultraThinMaterial.opacity(isFeatured ? 0.32 : 0.18),
            in: .rect(cornerRadius: cornerRadius, style: .continuous)
        )
        .background {
            RadialGradient(
                colors: [
                    UITheme.glimmerGlow.opacity(isFeatured ? 0.06 : 0.025),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 150
            )
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(isFeatured ? 0.05 : 0.025),
                            .white.opacity(0.005)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(isFeatured ? 0.10 : 0.05), radius: isFeatured ? 12 : 6, x: 0, y: isFeatured ? 6 : 3)
    }
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
                Circle()
                    .fill(UITheme.glimmerGlow.opacity(isFeatured ? 0.35 : 0.12))
                    .frame(width: isFeatured ? 14 : 10, height: isFeatured ? 14 : 10)
                    .blur(radius: isFeatured ? 2.5 : 1.5)

                Circle()
                    .fill(isFeatured ? UITheme.glimmerGlow : UITheme.primaryText.opacity(0.6))
                    .frame(width: isFeatured ? 5 : 3.5, height: isFeatured ? 5 : 3.5)
            }
            .frame(height: 14)
            .padding(.vertical, 2)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            UITheme.primaryText.opacity(isFeatured ? 0.15 : 0.08),
                            UITheme.primaryText.opacity(0.01)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 0.5, height: isFeatured ? 64 : 48)
        }
        .frame(width: 42)
        .padding(.top, isFeatured ? 12 : 8)
    }
}
