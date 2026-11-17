import SwiftUI

struct LogInsightStrip: View {
    let items: [(String, String)]
    var tint: Color = VitalityTheme.primary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.1)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                    Text(L10n.text(item.0))
                        .font(.caption)
                        .foregroundStyle(VitalityTheme.textMuted)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 6)
    }
}

struct LogCategoryFilter<Option: Identifiable & Hashable>: View {
    let options: [Option]
    @Binding var selection: Option?
    let title: (Option) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton("All categories".localized, value: nil)
                ForEach(options) { option in
                    filterButton(title(option), value: option)
                }
            }
        }
    }

    private func filterButton(_ title: String, value: Option?) -> some View {
        Button { selection = value } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(selection == value ? VitalityTheme.primary.opacity(0.15) : VitalityTheme.surface)
                .foregroundStyle(selection == value ? VitalityTheme.primary : VitalityTheme.textMuted)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == value ? .isSelected : [])
    }
}

struct ActivityWeek: View {
    let dates: [Date]
    let endingAt: Date

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DateHelpers.lastSevenDays(endingAt: endingAt), id: \.self) { day in
                let active = dates.contains { DateHelpers.isSameDay($0, day) }
                VStack(spacing: 8) {
                    Text(day.formatted(.dateTime.weekday(.narrow).locale(L10n.locale)))
                        .font(.caption)
                        .foregroundStyle(VitalityTheme.textMuted)
                    Image(systemName: active ? "checkmark" : "minus")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(active ? VitalityTheme.primary : VitalityTheme.secondaryContainer)
                        .foregroundStyle(active ? VitalityTheme.onPrimary : VitalityTheme.textMuted)
                        .clipShape(Circle())
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.format("%@: %@", L10n.date(day), L10n.text(active ? "Recorded" : "Not recorded")))
            }
        }
    }
}
