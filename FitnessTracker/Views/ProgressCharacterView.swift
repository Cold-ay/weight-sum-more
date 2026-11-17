import SwiftUI

struct CharacterProgressCard: View {
    let sex: BiologicalSex
    let progress: CharacterProgress
    var activity: ExerciseType? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var isAnimated = false

    var body: some View {
        VitalityCard(padding: 0) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("YOUR TRAINING BUDDY")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VitalityTheme.primary)
                        Text(progress.build.title)
                            .font(.system(size: 25, weight: .heavy, design: .rounded))
                            .foregroundStyle(VitalityTheme.text)
                        Text(progress.build.encouragement)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(VitalityTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    scoreBadge
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)

                ZStack(alignment: .bottom) {
                    characterBackdrop
                    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !isAnimated || scenePhase != .active)) { timeline in
                        FitnessCharacter(
                            sex: sex, build: progress.build, activity: activity,
                            time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                        )
                    }
                        .scaleEffect(isAnimated ? 1 : 0.88, anchor: .bottom)
                        .offset(y: isAnimated ? 0 : 12)
                        .animation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.68), value: isAnimated)
                }
                .frame(height: 246)
                .clipped()

                Text(activity.map { L10n.format("%@ today · Moving with you", $0.displayName) } ?? "Ready when you are".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VitalityTheme.primary)
                    .padding(.vertical, 12)

                evolutionRail
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x16262C), VitalityTheme.surface, Color(hex: 0x181823)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .onAppear { isAnimated = true }
        .onDisappear { isAnimated = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.format("Training buddy: %@, score %ld percent. %@", progress.build.title, progress.percentage, activity?.displayName ?? "Resting".localized))
    }

    private var scoreBadge: some View {
        ZStack {
            Circle()
                .stroke(VitalityTheme.primary.opacity(0.18), lineWidth: 7)
            Circle()
                .trim(from: 0, to: min(max(progress.score, 0), 1))
                .stroke(
                    AngularGradient(
                        colors: [VitalityTheme.primary, Color(hex: 0x8B5CF6), VitalityTheme.primary],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text("\(progress.percentage)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(VitalityTheme.text)
                Text("SCORE")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(VitalityTheme.textMuted)
            }
        }
        .frame(width: 68, height: 68)
    }

    private var characterBackdrop: some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(VitalityTheme.primary.opacity(0.10))
                .frame(width: 224, height: 224)
                .blur(radius: 2)
                .offset(y: 26)
            Circle()
                .stroke(VitalityTheme.primary.opacity(0.16), lineWidth: 1)
                .frame(width: 190, height: 190)
                .offset(y: 20)
            Capsule()
                .fill(Color.black.opacity(0.34))
                .frame(width: 142, height: 18)
                .blur(radius: 7)
                .offset(y: 6)

            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                    .font(.system(size: index.isMultiple(of: 2) ? 12 : 7, weight: .bold))
                    .foregroundStyle(index.isMultiple(of: 2) ? VitalityTheme.primary : Color(hex: 0x8B5CF6))
                    .offset(
                        x: CGFloat([-98, -72, 82, 103, 68][index]),
                        y: CGFloat([-122, -58, -115, -48, -158][index])
                    )
                    .opacity(isAnimated ? 0.9 : 0)
                    .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.08), value: isAnimated)
            }
        }
    }

    private var evolutionRail: some View {
        VStack(spacing: 9) {
            HStack {
                Text("EVOLUTION")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VitalityTheme.textMuted)
                Spacer()
                Text("Powered by your consistency")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VitalityTheme.textMuted)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(VitalityTheme.secondaryContainer)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [VitalityTheme.primary, Color(hex: 0x8B5CF6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * min(max(progress.score, 0), 1))
                    HStack {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(progress.score >= Double(index) / 3 ? VitalityTheme.text : VitalityTheme.outline)
                                .frame(width: 7, height: 7)
                            if index < 3 { Spacer() }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .frame(height: 8)
        }
    }
}

private struct FitnessCharacter: View {
    let sex: BiologicalSex
    let build: CharacterBuild
    let activity: ExerciseType?
    let time: Double

    private var wave: Double { sin(time * (activity == .running ? 9 : activity == nil ? 2 : 4)) }
    private var stride: Double {
        switch activity {
        case .running: 28 * wave
        case .walking: 15 * wave
        case .cycling: 22 * wave
        case .swimming: 10 * wave
        case .yoga: 7
        default: 0
        }
    }
    private var armSwing: Double {
        switch activity {
        case .gym: 65 + 35 * wave
        case .swimming: 100 + 65 * wave
        case .yoga: 125 + 8 * wave
        case .other: 80 + 45 * wave
        case .cycling: 45
        default: stride
        }
    }

    private var proportions: CharacterProportions { CharacterProportions(build: build, sex: sex) }
    private let skin = Color(hex: 0xD99572)
    private let skinLight = Color(hex: 0xF2B58F)
    private let hair = Color(hex: 0x271C25)
    private let outfit = Color(hex: 0x00CFE8)

    var body: some View {
        ZStack {
            legs
            arms
            torso
            head
        }
        .frame(width: 190, height: 230)
        .scaleEffect(x: 1, y: activity == nil ? 1 + wave * 0.012 : 1, anchor: .bottom)
        .offset(y: activity == .running ? -abs(wave) * 7 : activity == .gym ? -wave * 2 : 0)
    }

    private var legs: some View {
        HStack(spacing: proportions.legGap) {
            limb(width: proportions.legWidth, height: 78)
                .rotationEffect(.degrees(stride), anchor: .top)
                .offset(y: activity == .cycling ? wave * 9 : 0)
            limb(width: proportions.legWidth, height: 78)
                .rotationEffect(.degrees(-stride), anchor: .top)
                .offset(y: activity == .cycling ? -wave * 9 : 0)
        }
        .offset(y: 72)
    }

    private var arms: some View {
        HStack(spacing: proportions.shoulderWidth - 7) {
            arm(rotation: 8 + armSwing)
            arm(rotation: -8 + ((activity == .running || activity == .walking || activity == .cycling) ? armSwing : -armSwing))
        }
        .offset(y: 12)
    }

    private func arm(rotation: Double) -> some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(LinearGradient(colors: [skinLight, skin], startPoint: .top, endPoint: .bottom))
                .frame(width: proportions.armWidth, height: 92)
            if proportions.muscle > 0.4 {
                Circle()
                    .fill(skinLight)
                    .frame(width: proportions.armWidth + 8, height: proportions.armWidth + 8)
                    .offset(y: 12)
                    .overlay(
                        ArcSmile()
                            .stroke(skin.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .frame(width: proportions.armWidth, height: 12)
                            .offset(y: 16)
                    )
            }
        }
        .overlay(alignment: .bottom) {
            if activity == .gym {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 3).frame(width: 9, height: 25)
                    Rectangle().frame(width: 22, height: 6)
                    RoundedRectangle(cornerRadius: 3).frame(width: 9, height: 25)
                }
                .foregroundStyle(Color(hex: 0xB9C8DC))
                .offset(y: 5)
            }
        }
        .rotationEffect(.degrees(rotation), anchor: .top)
    }

    private var torso: some View {
        ZStack {
            CharacterTorsoShape(proportions: proportions)
                .fill(
                    LinearGradient(
                        colors: [outfit.opacity(0.98), Color(hex: 0x087E9E)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: proportions.shoulderWidth, height: 104)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: proportions.shoulderWidth * 0.46, height: 4)
                        .offset(y: 17)
                }
            Image(systemName: build == .powerful ? "bolt.fill" : "heart.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.white.opacity(0.92))
                .offset(y: -8)
        }
        .offset(y: 24)
    }

    private var head: some View {
        ZStack {
            if sex == .female {
                Circle()
                    .fill(hair)
                    .frame(width: 35, height: 35)
                    .offset(x: 33, y: -9)
            }
            Circle()
                .fill(LinearGradient(colors: [skinLight, skin], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 64, height: 64)
            hairStyle
            HStack(spacing: 18) {
                Circle().fill(Color(hex: 0x241B21)).frame(width: 5, height: 7)
                Circle().fill(Color(hex: 0x241B21)).frame(width: 5, height: 7)
            }
            .offset(y: 4)
            .scaleEffect(x: 1, y: time.truncatingRemainder(dividingBy: 4.7) > 4.5 ? 0.15 : 1)
            HStack(spacing: 34) {
                Circle().fill(Color(hex: 0xE8757D).opacity(0.55)).frame(width: 9, height: 5)
                Circle().fill(Color(hex: 0xE8757D).opacity(0.55)).frame(width: 9, height: 5)
            }
            .offset(y: 14)
            ArcSmile()
                .stroke(Color(hex: 0x512F35), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 16, height: 9)
                .offset(y: 15)
        }
        .offset(y: -49)
    }

    @ViewBuilder private var hairStyle: some View {
        if sex == .female {
            UnevenRoundedRectangle(
                topLeadingRadius: 30,
                bottomLeadingRadius: 7,
                bottomTrailingRadius: 7,
                topTrailingRadius: 30
            )
            .fill(hair)
            .frame(width: 64, height: 27)
            .offset(y: -19)
        } else {
            ZStack {
                Ellipse().fill(hair).frame(width: 61, height: 27).offset(y: -20)
                Circle().fill(hair).frame(width: 19, height: 19).offset(x: -21, y: -23)
                Circle().fill(hair).frame(width: 20, height: 20).offset(x: 1, y: -27)
                Circle().fill(hair).frame(width: 18, height: 18).offset(x: 22, y: -22)
            }
        }
    }

    private func limb(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color(hex: 0x203743), Color(hex: 0x111B24)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: height)
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(Color(hex: 0xF4F7FA))
                    .frame(width: width + 5, height: 18)
                    .offset(y: 4)
            }
    }
}

private struct CharacterProportions {
    let shoulderWidth: CGFloat
    let waistWidth: CGFloat
    let bellyWidth: CGFloat
    let armWidth: CGFloat
    let legWidth: CGFloat
    let legGap: CGFloat
    let muscle: CGFloat

    init(build: CharacterBuild, sex: BiologicalSex) {
        let sexOffset: CGFloat = sex == .male ? 7 : 0
        switch build {
        case .lean:
            (shoulderWidth, waistWidth, bellyWidth, armWidth, legWidth, legGap, muscle) = (72 + sexOffset, 50, 54, 15, 21, 10, 0)
        case .balanced:
            (shoulderWidth, waistWidth, bellyWidth, armWidth, legWidth, legGap, muscle) = (82 + sexOffset, 57, 61, 18, 24, 9, 0.25)
        case .soft:
            (shoulderWidth, waistWidth, bellyWidth, armWidth, legWidth, legGap, muscle) = (87 + sexOffset, 77, 91, 23, 29, 7, 0.15)
        case .athletic:
            (shoulderWidth, waistWidth, bellyWidth, armWidth, legWidth, legGap, muscle) = (99 + sexOffset, 61, 65, 25, 29, 8, 0.65)
        case .powerful:
            (shoulderWidth, waistWidth, bellyWidth, armWidth, legWidth, legGap, muscle) = (115 + sexOffset, 64, 70, 31, 33, 8, 1)
        }
    }
}

private struct CharacterTorsoShape: Shape {
    let proportions: CharacterProportions

    func path(in rect: CGRect) -> Path {
        let center = rect.midX
        let shoulder = rect.width / 2
        let waist = proportions.waistWidth / 2
        let belly = proportions.bellyWidth / 2
        var path = Path()
        path.move(to: CGPoint(x: center - shoulder * 0.72, y: 0))
        path.addCurve(
            to: CGPoint(x: center - belly, y: rect.height * 0.58),
            control1: CGPoint(x: center - shoulder, y: rect.height * 0.08),
            control2: CGPoint(x: center - belly, y: rect.height * 0.32)
        )
        path.addCurve(
            to: CGPoint(x: center - waist, y: rect.height),
            control1: CGPoint(x: center - belly, y: rect.height * 0.77),
            control2: CGPoint(x: center - waist, y: rect.height * 0.88)
        )
        path.addLine(to: CGPoint(x: center + waist, y: rect.height))
        path.addCurve(
            to: CGPoint(x: center + belly, y: rect.height * 0.58),
            control1: CGPoint(x: center + waist, y: rect.height * 0.88),
            control2: CGPoint(x: center + belly, y: rect.height * 0.77)
        )
        path.addCurve(
            to: CGPoint(x: center + shoulder * 0.72, y: 0),
            control1: CGPoint(x: center + belly, y: rect.height * 0.32),
            control2: CGPoint(x: center + shoulder, y: rect.height * 0.08)
        )
        path.addQuadCurve(
            to: CGPoint(x: center - shoulder * 0.72, y: 0),
            control: CGPoint(x: center, y: 24)
        )
        path.closeSubpath()
        return path
    }
}

private struct ArcSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}
