import SwiftUI

// MARK: - WheelViewModel
class WheelViewModel: ObservableObject {
    @Published var date: Date = Date()
    @Published var planets: [PlanetPosition] = []
    @Published var angles: ChartAngles = ChartAngles(ascendant: 0, descendant: 180, midheaven: 90, imumCoeli: 270, northNode: 0, southNode: 180)
    @Published var hourOffset: Int = 0      // hours from base date
    @Published var isAnimating: Bool = false
    @Published var latitude: Double = 19.4326
    @Published var longitude: Double = -99.1332

    private var animTimer: Timer?
    private var baseDate: Date = Date()

    init() { compute() }

    var displayDate: Date {
        baseDate.addingTimeInterval(Double(hourOffset) * 3600)
    }

    func setBase(_ d: Date) {
        baseDate = d
        hourOffset = 0
        compute()
    }

    func compute() {
        let d = displayDate
        DispatchQueue.global(qos: .userInteractive).async {
            let result = AstronomicalEngine.computePositions(
                date: d, utcOffset: 0, isGeocentric: true,
                latitude: self.latitude, longitude: self.longitude)
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.35)) {
                    self.planets = result.0
                    self.angles  = result.1
                }
            }
        }
    }

    func startAnimation() {
        isAnimating = true
        animTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let s = self else { return }
            s.hourOffset += 1
            s.compute()
        }
    }

    func stopAnimation() {
        isAnimating = false
        animTimer?.invalidate()
        animTimer = nil
    }
}

// MARK: - Main View
struct ZodiacWheelView: View {
    @StateObject private var wvm = WheelViewModel()
    @State private var baseDate: Date = Date()
    @State private var selectedPlanet: PlanetPosition? = nil
    @State private var showDatePicker = false

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.01, blue: 0.10).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                // Wheel
                GeometryReader { geo in
                    let size = min(geo.size.width, geo.size.height) - 24
                    ZStack {
                        AstralWheelCanvas(
                            planets: wvm.planets,
                            angles: wvm.angles,
                            size: size,
                            onTap: { p in selectedPlanet = p }
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Bottom controls
                bottomControls
            }
        }
        .navigationTitle("Carta Astral")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPlanet) { PlanetDetailView(planet: $0) }
        .onAppear { wvm.setBase(baseDate) }
    }

    // MARK: - Top bar
    var topBar: some View {
        VStack(spacing: 6) {
            Button { showDatePicker.toggle() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.circle")
                    Text(formattedDate(wvm.displayDate))
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.yellow)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(Color.yellow.opacity(0.12)))
            }

            if showDatePicker {
                DatePicker("", selection: $baseDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .colorScheme(.dark)
                    .labelsHidden()
                    .onChange(of: baseDate) { d in
                        wvm.setBase(d)
                        showDatePicker = false
                    }
            }
        }
        .padding(.top, 8).padding(.bottom, 4)
        .background(Color.black.opacity(0.4))
    }

    // MARK: - Bottom controls
    var bottomControls: some View {
        VStack(spacing: 10) {
            // Hour slider
            VStack(spacing: 4) {
                Text("Desplazamiento: \(hourLabel(wvm.hourOffset))")
                    .font(.caption2)
                    .foregroundColor(.gray)

                HStack(spacing: 10) {
                    Button {
                        wvm.hourOffset -= 1
                        wvm.compute()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3).foregroundColor(.cyan)
                    }

                    Slider(value: Binding(
                        get: { Double(wvm.hourOffset) },
                        set: { v in
                            wvm.hourOffset = Int(v)
                            wvm.compute()
                        }
                    ), in: -720...720, step: 1)
                    .accentColor(.cyan)

                    Button {
                        wvm.hourOffset += 1
                        wvm.compute()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3).foregroundColor(.cyan)
                    }
                }
            }
            .padding(.horizontal, 16)

            // Playback row
            HStack(spacing: 20) {
                Button {
                    wvm.hourOffset -= 24
                    wvm.compute()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }

                Button {
                    wvm.hourOffset -= 1
                    wvm.compute()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3).foregroundColor(.white)
                }

                // Play / Stop
                Button {
                    if wvm.isAnimating { wvm.stopAnimation() }
                    else { wvm.startAnimation() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(wvm.isAnimating ? Color.red.opacity(0.85) : Color.cyan.opacity(0.85))
                            .frame(width: 52, height: 52)
                        Image(systemName: wvm.isAnimating ? "stop.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }

                Button {
                    wvm.hourOffset += 1
                    wvm.compute()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3).foregroundColor(.white)
                }

                Button {
                    wvm.hourOffset += 24
                    wvm.compute()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }

                Button {
                    wvm.stopAnimation()
                    wvm.hourOffset = 0
                    wvm.compute()
                } label: {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.title3).foregroundColor(.orange)
                }
            }
            .padding(.bottom, 14)
        }
        .background(Color.black.opacity(0.5))
    }

    func formattedDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy  HH:mm"
        f.locale = Locale(identifier: "es_MX")
        return f.string(from: d)
    }

    func hourLabel(_ h: Int) -> String {
        if h == 0 { return "Original" }
        let sign = h > 0 ? "+" : ""
        let abs  = Swift.abs(h)
        if abs < 24  { return "\(sign)\(h)h" }
        if abs < 168 { return "\(sign)\(h/24)d \(h%24)h" }
        return "\(sign)\(h/24)d"
    }
}

// MARK: - Canvas Wheel
struct AstralWheelCanvas: View {
    let planets: [PlanetPosition]
    let angles: ChartAngles
    let size: CGFloat
    let onTap: (PlanetPosition) -> Void

    // Radii ratios
    private var R: CGFloat { size / 2 }
    private var outerR:  CGFloat { R * 0.98 }
    private var zodiacOuter: CGFloat { R * 0.88 }
    private var zodiacInner: CGFloat { R * 0.72 }
    private var houseRing:   CGFloat { R * 0.70 }
    private var planetRing:  CGFloat { R * 0.55 }
    private var innerR:      CGFloat { R * 0.28 }

    private let signs = ZodiacSign.allCases

    var body: some View {
        ZStack {
            Canvas { ctx, sz in
                let center = CGPoint(x: sz.width/2, y: sz.height/2)
                drawBackground(ctx: ctx, center: center)
                drawZodiacRing(ctx: ctx, center: center)
                drawHouseLines(ctx: ctx, center: center)
                drawAngleLines(ctx: ctx, center: center)
                drawAspectLines(ctx: ctx, center: center)
            }
            .frame(width: size, height: size)

            // Planet glyphs overlaid (animatable)
            ForEach(allBodies) { body in
                PlanetGlyph(planet: body, center: CGPoint(x: size/2, y: size/2), radius: planetRing)
                    .onTapGesture { onTap(body) }
            }

            // Angle labels
            AngleGlyphs(angles: angles, center: CGPoint(x: size/2, y: size/2),
                        radius: houseRing * 0.88, innerRadius: innerR)
        }
        .frame(width: size, height: size)
    }

    var allBodies: [PlanetPosition] { planets }

    // MARK: Draw background
    func drawBackground(ctx: GraphicsContext, center: CGPoint) {
        // Outer glow
        var glow = ctx
        glow.opacity = 0.15
        let outerPath = Path(ellipseIn: CGRect(center: center, size: CGSize(width: outerR*2+20, height: outerR*2+20)))
        glow.fill(outerPath, with: .color(.indigo))

        // Main dark circle
        let bg = Path(ellipseIn: CGRect(center: center, size: CGSize(width: outerR*2, height: outerR*2)))
        ctx.fill(bg, with: .linearGradient(
            Gradient(colors: [Color(red:0.06,green:0.02,blue:0.18), Color(red:0.01,green:0.01,blue:0.08)]),
            startPoint: center.offsetBy(dx: -outerR, dy: -outerR),
            endPoint: center.offsetBy(dx: outerR, dy: outerR)
        ))

        // Inner circle fill
        let inner = Path(ellipseIn: CGRect(center: center, size: CGSize(width: innerR*2, height: innerR*2)))
        ctx.fill(inner, with: .color(Color(red:0.04,green:0.01,blue:0.12)))

        // Stars (dots scattered)
        for i in 0..<40 {
            let angle = Double(i) * 137.5 * .pi / 180
            let r = planetRing * CGFloat(0.3 + Double(i%5)*0.09)
            let pt = center.offsetBy(dx: r*CGFloat(cos(angle)), dy: r*CGFloat(sin(angle)))
            let star = Path(ellipseIn: CGRect(center: pt, size: CGSize(width: 1.5, height: 1.5)))
            var sc = ctx; sc.opacity = Double.random(in: 0.2...0.7)
            sc.fill(star, with: .color(.white))
        }
    }

    // MARK: Draw zodiac ring
    func drawZodiacRing(ctx: GraphicsContext, center: CGPoint) {
        let signColors: [Color] = [.red,.green,.yellow,.blue,.red,.green,.yellow,.blue,.red,.green,.yellow,.blue]

        for i in 0..<12 {
            let startAngle = Angle(degrees: Double(i) * 30 - 90)
            let endAngle   = Angle(degrees: Double(i+1) * 30 - 90)

            // Colored arc segment
            var path = Path()
            path.addArc(center: center, radius: zodiacOuter, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            path.addArc(center: center, radius: zodiacInner, startAngle: endAngle, endAngle: startAngle, clockwise: true)
            path.closeSubpath()
            ctx.fill(path, with: .color(signColors[i].opacity(0.18)))
            ctx.stroke(path, with: .color(signColors[i].opacity(0.4)), lineWidth: 0.5)

            // Divider line
            let divAngle = Double(i) * 30 - 90
            let divRad = divAngle * .pi / 180
            let p1 = center.offsetBy(dx: zodiacInner * CGFloat(cos(divRad)), dy: zodiacInner * CGFloat(sin(divRad)))
            let p2 = center.offsetBy(dx: zodiacOuter * CGFloat(cos(divRad)), dy: zodiacOuter * CGFloat(sin(divRad)))
            var divPath = Path(); divPath.move(to: p1); divPath.addLine(to: p2)
            ctx.stroke(divPath, with: .color(.white.opacity(0.25)), lineWidth: 0.8)
        }

        // Outer border
        let outerCircle = Path(ellipseIn: CGRect(center: center, size: CGSize(width: zodiacOuter*2, height: zodiacOuter*2)))
        ctx.stroke(outerCircle, with: .color(.white.opacity(0.4)), lineWidth: 1)
        let innerCircle = Path(ellipseIn: CGRect(center: center, size: CGSize(width: zodiacInner*2, height: zodiacInner*2)))
        ctx.stroke(innerCircle, with: .color(.white.opacity(0.2)), lineWidth: 0.8)

        // House ring
        let houseCircle = Path(ellipseIn: CGRect(center: center, size: CGSize(width: houseRing*2, height: houseRing*2)))
        ctx.stroke(houseCircle, with: .color(.white.opacity(0.15)), lineWidth: 0.6)

        // Inner circle
        let innerC = Path(ellipseIn: CGRect(center: center, size: CGSize(width: innerR*2, height: innerR*2)))
        ctx.stroke(innerC, with: .color(.white.opacity(0.3)), lineWidth: 1)
    }

    // MARK: Degree tick marks
    func drawHouseLines(ctx: GraphicsContext, center: CGPoint) {
        for deg in stride(from: 0, to: 360, by: 5) {
            let rad = (Double(deg) - 90) * .pi / 180
            let isMajor = deg % 30 == 0
            let inner = isMajor ? zodiacInner : (deg % 10 == 0 ? zodiacInner * 1.04 : zodiacInner * 1.02)
            let outer = zodiacOuter

            let p1 = center.offsetBy(dx: inner * CGFloat(cos(rad)), dy: inner * CGFloat(sin(rad)))
            let p2 = center.offsetBy(dx: outer * CGFloat(cos(rad)), dy: outer * CGFloat(sin(rad)))
            var tp = Path(); tp.move(to: p1); tp.addLine(to: p2)
            ctx.stroke(tp, with: .color(isMajor ? .white.opacity(0.5) : .white.opacity(0.15)),
                       lineWidth: isMajor ? 1.0 : 0.4)
        }
    }

    // MARK: Angle cross lines (ASC/DSC/MC/IC)
    func drawAngleLines(ctx: GraphicsContext, center: CGPoint) {
        let angleData: [(Double, Color)] = [
            (angles.ascendant,  .yellow),
            (angles.descendant, .yellow),
            (angles.midheaven,  .orange),
            (angles.imumCoeli,  .orange),
        ]
        for (lon, color) in angleData {
            let rad = (lon - 90) * .pi / 180
            let p1 = center.offsetBy(dx: innerR * CGFloat(cos(rad)), dy: innerR * CGFloat(sin(rad)))
            let p2 = center.offsetBy(dx: zodiacInner * CGFloat(cos(rad)), dy: zodiacInner * CGFloat(sin(rad)))
            var lp = Path(); lp.move(to: p1); lp.addLine(to: p2)
            ctx.stroke(lp, with: .color(color.opacity(0.8)), lineWidth: 1.5)
        }
    }

    // MARK: Aspect lines between planets
    func drawAspectLines(ctx: GraphicsContext, center: CGPoint) {
        let aspectAngles: [(Double, Color, Double)] = [
            (0, .yellow, 8), (60, .blue, 6), (90, .red, 6),
            (120, .green, 8), (150, .gray, 5), (180, .red, 8)
        ]
        let bodies = planets.prefix(10) // just main 10
        for i in 0..<bodies.count {
            for j in (i+1)..<bodies.count {
                let a = bodies[bodies.index(bodies.startIndex, offsetBy: i)]
                let b = bodies[bodies.index(bodies.startIndex, offsetBy: j)]
                var diff = abs(a.longitude - b.longitude)
                if diff > 180 { diff = 360 - diff }
                for (aspDeg, color, orb) in aspectAngles {
                    if abs(diff - aspDeg) <= orb {
                        let strength = 1.0 - (abs(diff - aspDeg) / orb)
                        let ra = (a.longitude - 90) * .pi / 180
                        let rb = (b.longitude - 90) * .pi / 180
                        let pa = center.offsetBy(dx: innerR*0.95*CGFloat(cos(ra)), dy: innerR*0.95*CGFloat(sin(ra)))
                        let pb = center.offsetBy(dx: innerR*0.95*CGFloat(cos(rb)), dy: innerR*0.95*CGFloat(sin(rb)))
                        var ap = Path(); ap.move(to: pa); ap.addLine(to: pb)
                        var ac = ctx; ac.opacity = strength * 0.55
                        ac.stroke(ap, with: .color(color), lineWidth: 0.8)
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Planet Glyph (animatable)
struct PlanetGlyph: View {
    let planet: PlanetPosition
    let center: CGPoint
    let radius: CGFloat

    private var position: CGPoint {
        let rad = (planet.longitude - 90) * .pi / 180
        return center.offsetBy(dx: radius * CGFloat(cos(rad)), dy: radius * CGFloat(sin(rad)))
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(glyphColor.opacity(0.25))
                .frame(width: 28, height: 28)
            Text(planet.symbol)
                .font(.system(size: 14))
                .foregroundColor(glyphColor)
        }
        .position(position)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: planet.longitude)
    }

    var glyphColor: Color {
        switch planet.name {
        case "Sol":      return .yellow
        case "Luna":     return .white
        case "Mercurio": return .mint
        case "Venus":    return .pink
        case "Marte":    return .red
        case "Júpiter":  return .orange
        case "Saturno":  return Color(red:0.8,green:0.6,blue:0.2)
        case "Urano":    return .cyan
        case "Neptuno":  return .blue
        case "Plutón":   return .purple
        case "Nodo Norte","Nodo Sur": return .green
        default: return .gray
        }
    }
}

// MARK: - Angle Labels (ASC/DSC/MC/IC)
struct AngleGlyphs: View {
    let angles: ChartAngles
    let center: CGPoint
    let radius: CGFloat
    let innerRadius: CGFloat

    var body: some View {
        ZStack {
            angleLabel("AC", lon: angles.ascendant,  color: .yellow)
            angleLabel("DC", lon: angles.descendant, color: .yellow)
            angleLabel("MC", lon: angles.midheaven,  color: .orange)
            angleLabel("IC", lon: angles.imumCoeli,  color: .orange)

            // Sign glyphs in zodiac ring
            ForEach(Array(ZodiacSign.allCases.enumerated()), id: \.offset) { i, sign in
                let midDeg = Double(i) * 30 + 15 - 90
                let rad = midDeg * .pi / 180
                let r = radius * 1.28
                Text(sign.glyph)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
                    .position(center.offsetBy(dx: r*CGFloat(cos(rad)), dy: r*CGFloat(sin(rad))))
            }
        }
    }

    func angleLabel(_ label: String, lon: Double, color: Color) -> some View {
        let rad = (lon - 90) * .pi / 180
        let r = innerRadius * 0.7
        return Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .position(center.offsetBy(dx: r * CGFloat(cos(rad)), dy: r * CGFloat(sin(rad))))
    }
}

// MARK: - CGRect helper
extension CGRect {
    init(center: CGPoint, size: CGSize) {
        self.init(x: center.x - size.width/2, y: center.y - size.height/2,
                  width: size.width, height: size.height)
    }
}

extension CGPoint {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> CGPoint {
        CGPoint(x: x + dx, y: y + dy)
    }
}
