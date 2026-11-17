import SwiftUI

private struct TrackingDateKey: EnvironmentKey {
    static var defaultValue: Date { Date() }
}

extension EnvironmentValues {
    var trackingDate: Date {
        get { self[TrackingDateKey.self] }
        set { self[TrackingDateKey.self] = newValue }
    }
}

enum VitalityTheme {
    static let background = Color(hex: 0x0F0F12)
    static let surface = Color(hex: 0x1A1A1E)
    static let surfaceRaised = Color(hex: 0x222229)
    static let secondaryContainer = Color(hex: 0x2A2A30)
    static let outline = Color(hex: 0x33333C)
    static let primary = Color(hex: 0x00E5FF)
    static let onPrimary = Color.black
    static let text = Color.white
    static let textMuted = Color(hex: 0xA0A0B0)
    static let success = Color(hex: 0x34C759)
    static let warning = Color(hex: 0xFF9F0A)
    static let deficit = Color(hex: 0x00AEEF)

    static let cardRadius: CGFloat = 14
    static let controlRadius: CGFloat = 10
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

struct VitalityScreen<Content: View>: View {
    let title: String
    var subtitle: String?
    var trailingSystemImage: String?
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            VitalityTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let subtitle {
                        Text(L10n.text(subtitle))
                            .font(.subheadline)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(VitalityTheme.textMuted)
                            .padding(.horizontal, 16)
                    }

                    content
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                }
                .padding(.top, 18)
            }
        }
        .navigationTitle(L10n.text(title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(VitalityTheme.background.opacity(0.92), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(VitalityTheme.primary)
        .toolbar {
            if let trailingSystemImage {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: trailingSystemImage)
                        .foregroundStyle(VitalityTheme.primary)
                }
            }
        }
    }
}

struct VitalityCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VitalityTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: VitalityTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VitalityTheme.cardRadius, style: .continuous)
                    .stroke(VitalityTheme.outline)
            )
            .shadow(color: VitalityTheme.primary.opacity(0.04), radius: 20, y: 4)
    }
}

struct VitalitySectionLabel: View {
    let text: String

    var body: some View {
        Text(L10n.text(text))
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(VitalityTheme.textMuted)
    }
}

struct VitalityPrimaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(L10n.text(title))
                Image(systemName: systemImage)
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(VitalityTheme.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(VitalityTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: VitalityTheme.primary.opacity(0.36), radius: 18)
        }
        .buttonStyle(.plain)
    }
}

struct VitalityTextField: View {
    let title: String
    let unit: String?
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VitalityCard {
            VStack(alignment: .leading, spacing: 10) {
                VitalitySectionLabel(text: title)
                HStack(spacing: 8) {
                    TextField("", text: $text)
                        .accessibilityLabel(L10n.text(title))
                        .keyboardType(keyboardType)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(VitalityTheme.primary)
                        .textFieldStyle(.plain)
                    if let unit {
                        Text(L10n.text(unit))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VitalityTheme.textMuted)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background(VitalityTheme.secondaryContainer)
                .clipShape(RoundedRectangle(cornerRadius: VitalityTheme.controlRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VitalityTheme.controlRadius, style: .continuous)
                        .stroke(VitalityTheme.outline)
                )
            }
        }
    }
}

struct AnalyticsPeriodPicker: View {
    @Binding var selection: AnalyticsPeriod

    var body: some View {
        VitalityCard(padding: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AnalyticsPeriod.allCases) { period in
                        Button {
                            selection = period
                        } label: {
                            Text(period.shortLabel)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(selection == period ? VitalityTheme.onPrimary : VitalityTheme.textMuted)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(selection == period ? VitalityTheme.primary : VitalityTheme.secondaryContainer)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(period.displayName)
                        .accessibilityAddTraits(selection == period ? .isSelected : [])
                    }
                }
            }
        }
    }
}

struct ChartLegendItem: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(L10n.text(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(VitalityTheme.textMuted)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    var tint: Color = VitalityTheme.primary
    var systemImage: String?

    var body: some View {
        VitalityCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VitalitySectionLabel(text: title)
                    Spacer()
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(tint)
                    }
                }
                Text(value)
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                Text(L10n.text(detail))
                    .font(.footnote)
                    .lineSpacing(3)
                    .foregroundStyle(VitalityTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct VitalityProgressCard: View {
    let title: String
    let value: String
    let caption: String
    let progress: Double
    var tint: Color = VitalityTheme.primary

    var body: some View {
        VitalityCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(tint.opacity(0.15), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: min(max(progress, 0), 1))
                        .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(min(max(progress, 0), 1) * 100))%")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(VitalityTheme.text)
                }
                .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 8) {
                    VitalitySectionLabel(text: title)
                    Text(value)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                    Text(L10n.text(caption))
                        .font(.footnote)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(VitalityTheme.textMuted)
                }
            }
        }
    }
}

struct DisclaimerBanner: View {
    var isCaution: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.text(isCaution ? "A note about your estimates" : "Estimates, not medical advice"),
                  systemImage: isCaution ? "exclamationmark.circle" : "info.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isCaution ? VitalityTheme.warning : VitalityTheme.text)

            Text(L10n.text(isCaution ? Self.cautionText : Self.generalText))
                .font(.footnote)
                .lineSpacing(4)
                .foregroundStyle(VitalityTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isCaution ? VitalityTheme.warning.opacity(0.12) : VitalityTheme.secondaryContainer)
            .clipShape(RoundedRectangle(cornerRadius: VitalityTheme.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VitalityTheme.controlRadius, style: .continuous)
                    .stroke(isCaution ? VitalityTheme.warning.opacity(0.45) : VitalityTheme.outline)
            )
    }

    static let generalText = "BMR, calorie burn, and weight trends are estimates for general wellness. Your actual needs and results may vary."

    static let cautionText = "These estimates may be inaccurate during pregnancy, breastfeeding, thyroid/metabolic conditions, illness, or medication changes. Please consult a healthcare professional for medical guidance."
}

struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text(L10n.text(title))
                .font(.headline)
                .foregroundStyle(VitalityTheme.text)
            Text(L10n.text(message))
                .font(.subheadline)
                .foregroundStyle(VitalityTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

extension Double {
    var caloriesText: String {
        L10n.format("%@ kcal", Self.roundedIntFormatter.string(from: NSNumber(value: self)) ?? "0")
    }

    var kgText: String {
        L10n.format("%@ kg", Self.oneDecimalFormatter.string(from: NSNumber(value: self)) ?? "0")
    }

    func weightText(unit: String) -> String {
        L10n.format("%@ %@", Self.oneDecimalFormatter.string(from: NSNumber(value: self)) ?? "0", L10n.text(unit))
    }

    private static let roundedIntFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let oneDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()
}
