import SwiftUI

let gold = Color(red: 1, green: 0.76, blue: 0.2)

struct ShieldShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.08))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: CGPoint(x: r.width * 0.25, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.08), control: CGPoint(x: r.width * 0.75, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.45))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.maxX, y: r.minY + r.height * 0.85))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.45), control: CGPoint(x: r.minX, y: r.minY + r.height * 0.85))
        p.closeSubpath()
        return p
    }
}

struct TeamBadge: View {
    let team: Team
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            ShieldShape()
                .fill(LinearGradient(colors: [team.primaryColor, team.primaryColor.opacity(0.75)],
                                     startPoint: .top, endPoint: .bottom))
            ShieldShape()
                .stroke(team.secondaryColor, lineWidth: max(1.5, size * 0.06))
            Text(team.short)
                .font(.system(size: size * 0.27, weight: .black, design: .rounded))
                .foregroundStyle(team.secondaryColor)
                .offset(y: -size * 0.04)
        }
        .frame(width: size, height: size * 1.12)
    }
}

struct RatingBadge: View {
    let rating: Int

    var color: Color {
        switch rating {
        case 80...: .green
        case 72..<80: Color(red: 0.6, green: 0.85, blue: 0.2)
        case 65..<72: .orange
        default: .gray
        }
    }

    var body: some View {
        Text("\(rating)")
            .font(.system(.subheadline, design: .rounded).weight(.heavy).monospacedDigit())
            .foregroundStyle(.black)
            .frame(width: 38, height: 26)
            .background(color, in: RoundedRectangle(cornerRadius: 7))
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08)))
    }
}

struct PitchBackground: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: [Color(red: 0.03, green: 0.08, blue: 0.06),
                                                             Color(red: 0.05, green: 0.2, blue: 0.11)]),
                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            let stripe = size.height / 12
            for i in stride(from: 0, to: 12, by: 2) {
                ctx.fill(Path(CGRect(x: 0, y: CGFloat(i) * stripe, width: size.width, height: stripe)),
                         with: .color(.white.opacity(0.025)))
            }
            let line = Color.white.opacity(0.08)
            ctx.stroke(Path(ellipseIn: CGRect(x: size.width / 2 - 80, y: size.height * 0.5 - 80, width: 160, height: 160)),
                       with: .color(line), lineWidth: 2)
            var mid = Path()
            mid.move(to: CGPoint(x: 0, y: size.height * 0.5))
            mid.addLine(to: CGPoint(x: size.width, y: size.height * 0.5))
            ctx.stroke(mid, with: .color(line), lineWidth: 2)
            ctx.stroke(Path(CGRect(x: size.width * 0.2, y: -2, width: size.width * 0.6, height: size.height * 0.16)),
                       with: .color(line), lineWidth: 2)
            ctx.stroke(Path(CGRect(x: size.width * 0.2, y: size.height * 0.84, width: size.width * 0.6, height: size.height * 0.2)),
                       with: .color(line), lineWidth: 2)
        }
        .ignoresSafeArea()
    }
}

struct BigButton: View {
    let title: String
    let icon: String
    var prominent = true
    let action: () -> Void

    var body: some View {
        Button(action: { SFX.tap(); action() }) {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 54)
                .foregroundStyle(prominent ? .black : .white)
                .background(prominent ? AnyShapeStyle(gold) : AnyShapeStyle(Color.white.opacity(0.12)),
                            in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
