import SwiftUI

/// HitFluence Media & Technology Group brand anchors, extended with HitCode's Aurora surfaces.
enum HFBrand {
    static let ink = Color(red: 4/255, green: 5/255, blue: 12/255)
    static let navy = Color(red: 11/255, green: 18/255, blue: 54/255)
    static let blue = Color(red: 47/255, green: 107/255, blue: 255/255)
    static let periwinkle = Color(red: 143/255, green: 168/255, blue: 255/255)
    static let lavender = Color(red: 201/255, green: 184/255, blue: 255/255)
    static let violet = Color(red: 156/255, green: 123/255, blue: 255/255)
    static let mint = Color(red: 63/255, green: 224/255, blue: 181/255)
    static let coral = Color(red: 255/255, green: 122/255, blue: 89/255)
    static let gold = Color(red: 242/255, green: 179/255, blue: 61/255)
    static let windowTop = Color(red: 20/255, green: 27/255, blue: 50/255)
    static let windowMiddle = Color(red: 30/255, green: 32/255, blue: 59/255)
    static let windowBottom = Color(red: 42/255, green: 32/255, blue: 61/255)
    static let panel = Color(red: 27/255, green: 35/255, blue: 59/255)
    static let panelRaised = Color(red: 37/255, green: 45/255, blue: 73/255)
    static let editor = Color(red: 21/255, green: 29/255, blue: 48/255)
    static let muted = Color(red: 181/255, green: 187/255, blue: 210/255)
    static let separator = Color(red: 101/255, green: 114/255, blue: 154/255).opacity(0.22)
    static let gradient = LinearGradient(colors: [violet, blue], startPoint: .leading, endPoint: .trailing)
    static let warmGradient = LinearGradient(colors: [gold, coral], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct HFAuroraBackground: View {
    var hero = false
    var body: some View {
        GeometryReader { bounds in
            ZStack {
                LinearGradient(colors: [HFBrand.windowTop, HFBrand.windowMiddle, HFBrand.windowBottom],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(HFBrand.blue.opacity(hero ? 0.19 : 0.10))
                    .frame(width: bounds.size.width * 0.67)
                    .blur(radius: 120)
                    .position(x: 0, y: 0)
                Circle()
                    .fill(HFBrand.violet.opacity(hero ? 0.18 : 0.10))
                    .frame(width: bounds.size.width * 0.65)
                    .blur(radius: 120)
                    .position(x: bounds.size.width * 0.65, y: bounds.size.height)
                if hero {
                    Circle()
                        .fill(HFBrand.coral.opacity(0.085))
                        .frame(width: 370)
                        .blur(radius: 90)
                        .position(x: bounds.size.width, y: 0)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Crisp vector expression of the approved HitFluence bracketed-hashtag brand language.
/// The user's approved mascot artwork can be substituted later without changing callers.
struct HFHashtag: View {
    var size: CGFloat = 42
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(LinearGradient(colors: [HFBrand.panelRaised, HFBrand.ink],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .stroke(HFBrand.lavender.opacity(0.35), lineWidth: 1)
            Circle()
                .fill(HFBrand.gold.opacity(0.34))
                .frame(width: size * 0.63)
                .blur(radius: size * 0.18)
                .offset(y: size * 0.08)
            Text("[#]")
                .font(.system(size: size * 0.42, weight: .black, design: .rounded))
                .foregroundStyle(HFBrand.warmGradient)
                .shadow(color: HFBrand.coral.opacity(0.35), radius: size * 0.09)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("HitFluence bracketed hashtag emblem")
    }
}

struct HFMascotHero: View {
    var body: some View {
        HStack(spacing: 18) {
            HFHashtag(size: 92)
                .shadow(color: HFBrand.violet.opacity(0.45), radius: 32)
            VStack(alignment: .leading, spacing: 8) {
                Text("HITFLUENCE INTELLIGENCE")
                    .font(.caption.weight(.bold))
                    .tracking(2.5)
                    .foregroundStyle(HFBrand.periwinkle)
                Text("Your ideas. Elevated.")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text("A creative workspace for clearer prompts, stronger agents and the ideas powering your next build.")
                    .font(.subheadline)
                    .foregroundStyle(HFBrand.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .background(
            LinearGradient(colors: [HFBrand.navy.opacity(0.92), HFBrand.violet.opacity(0.15), HFBrand.panel],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(HFBrand.periwinkle.opacity(0.22), lineWidth: 1)
        }
    }
}

struct HFGlassPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .background(HFBrand.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HFBrand.separator, lineWidth: 1)
            }
    }
}

struct HFEyebrow: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(HFBrand.muted)
    }
}
