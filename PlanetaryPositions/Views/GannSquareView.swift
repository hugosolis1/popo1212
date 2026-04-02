import SwiftUI

// MARK: - Gann Engine
enum GannEngine {

    static func position(of n: Double, start: Double = 1) -> (ring: Int, angle: Double) {
        let offset = n - start
        if offset <= 0 { return (0, 0) }
        let sq   = sqrt(offset + 1)
        let ring = Int(ceil((sq - 1) / 2))
        guard ring > 0 else { return (0, 0) }
        let ringStart = Double((2 * ring - 1) * (2 * ring - 1))
        let ringSize  = Double(8 * ring)
        let pos = offset - ringStart
        return (ring, max(0, (pos / ringSize) * 360.0))
    }

    static func numberAt(ring: Int, angle: Double, start: Double = 1) -> Double {
        if ring == 0 { return start }
        let ringStart = Double((2 * ring - 1) * (2 * ring - 1))
        let ringSize  = Double(8 * ring)
        return start + ringStart + (angle / 360.0) * ringSize
    }

    static func keyLevels(for value: Double, start: Double = 1, count: Int = 20) -> [Double] {
        let (ring, angle) = position(of: value, start: start)
        var levels = [start]
        let maxRing = ring + count / 2
        for r in 1...max(1, maxRing) {
            let v = numberAt(ring: r, angle: angle, start: start)
            if v > 0 { levels.append(v) }
        }
        return levels.sorted()
    }

    static let cardinalAngles: [(Double, String)] = [
        (0,   "0° Este"),  (45,  "45° NE"),  (90,  "90° Norte"), (135, "135° NO"),
        (180, "180° Oeste"),(225, "225° SO"),(270, "270° Sur"),   (315, "315° SE")
    ]

    static func cardinalTargets(for value: Double, start: Double = 1) -> [(String, [Double])] {
        let (ring, _) = position(of: value, start: start)
        return cardinalAngles.map { deg, label in
            var vals = [start]
            for r in max(1, ring - 3)...ring + 4 {
                let v = numberAt(ring: r, angle: deg, start: start)
                if v > 0 { vals.append(v) }
            }
            return (label, vals.sorted())
        }
    }

    static func spiralMatrix(maxRing: Int, start: Double = 1) -> [[Double]] {
        let size = 2 * maxRing + 1
        var grid = Array(repeating: Array(repeating: Double.nan, count: size), count: size)
        var x = maxRing, y = maxRing
        grid[y][x] = start
        var num = start + 1
        var step = 1, dir = 0
        let dx = [1, 0, -1, 0]; let dy = [0, -1, 0, 1]
        let total = Double(size * size)
        while num <= start + total - 1 {
            for _ in 0..<2 {
                for _ in 0..<step {
                    x += dx[dir % 4]; y += dy[dir % 4]
                    if x >= 0 && x < size && y >= 0 && y < size {
                        grid[y][x] = num; num += 1
                    }
                }
                dir += 1
            }
            step += 1
        }
        return grid
    }

    static func fmt(_ v: Double) -> String {
        if v.isNaN { return "" }
        if abs(v) >= 10000 { return String(format: "%.0fk", v / 1000) }
        if v == v.rounded() { return String(format: "%.0f", v) }
        if abs(v) < 0.01 { return String(format: "%.3f", v) }
        return String(format: "%.1f", v)
    }

    static func fmtFull(_ v: Double) -> String {
        if v == v.rounded() && abs(v) < 1_000_000 { return String(format: "%.0f", v) }
        if abs(v) < 0.01 { return String(format: "%.4f", v) }
        return String(format: "%.2f", v)
    }
}

// MARK: - Result model
struct GannResult {
    let value: Double
    let start: Double
    let ring:  Int
    let angle: Double
    let targets:   [(String, [Double])]
    let keyLevels: [Double]
}

// MARK: - Info card
struct GannCard: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption2).foregroundColor(.gray)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color).minimumScaleFactor(0.5).lineLimit(1)
        }
        .frame(maxWidth: .infinity).padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
    }
}

// MARK: - Cardinal row
struct GannCardinalRow: View {
    let label:  String
    let values: [Double]
    let highlight: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundColor(.yellow).fontWeight(.semibold)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(values, id: \.self) { v in
                        let isHL = abs(v - highlight) < 0.01
                        Text(GannEngine.fmtFull(v))
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6)
                                .fill(isHL ? Color.orange.opacity(0.35) : Color.white.opacity(0.07)))
                            .foregroundColor(isHL ? .orange : .white)
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
    }
}

// MARK: - Legend dot
struct GannDot: View {
    let color: Color; let label: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - Grid cell (extracted to fix type-check)
struct GannCell: View {
    let value: Double
    let isTarget: Bool
    let isCenter: Bool
    let sameAngle: Bool
    let isCardinal: Bool

    var body: some View {
        Text(GannEngine.fmt(value))
            .font(.system(size: 8, weight: isTarget || isCenter ? .black : .regular,
                          design: .monospaced))
            .foregroundColor(cellFg)
            .frame(maxWidth: .infinity).frame(height: 20)
            .background(RoundedRectangle(cornerRadius: 3).fill(cellBg))
    }

    private var cellFg: Color {
        if isTarget || isCenter { return .black }
        if sameAngle  { return .orange }
        if isCardinal { return .cyan }
        return .white.opacity(0.75)
    }
    private var cellBg: Color {
        if isTarget   { return .orange }
        if isCenter   { return .yellow }
        if sameAngle  { return Color.orange.opacity(0.18) }
        if isCardinal { return Color.cyan.opacity(0.12) }
        return Color.white.opacity(0.04)
    }
}

// MARK: - Grid row
struct GannGridRow: View {
    let rowValues: [Double]
    let centerValue: Double
    let startValue:  Double
    let targetAngle: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<rowValues.count, id: \.self) { col in
                let v = rowValues[col]
                let isNaN     = v.isNaN
                let isTarget  = !isNaN && abs(v - centerValue) < 0.01
                let isCenter  = !isNaN && abs(v - startValue) < 0.001
                let (_, angle) = isNaN ? (0, -1.0)
                                       : GannEngine.position(of: v, start: startValue)
                let sameAngle  = !isNaN && !isCenter && abs(angle - targetAngle) < 4.5
                let isCardinal = !isNaN && !isCenter
                    && GannEngine.cardinalAngles.contains { abs(angle - $0.0) < 3.0 }
                GannCell(value: v, isTarget: isTarget, isCenter: isCenter,
                         sameAngle: sameAngle, isCardinal: isCardinal)
            }
        }
    }
}

// MARK: - Full grid
struct GannGridView: View {
    let centerValue: Double
    let startValue:  Double
    private let maxRing = 4
    private var grid: [[Double]] {
        GannEngine.spiralMatrix(maxRing: maxRing, start: startValue)
    }
    private var targetAngle: Double {
        GannEngine.position(of: centerValue, start: startValue).angle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ESPIRAL — CENTRO: \(GannEngine.fmtFull(startValue))")
                .font(.caption2).foregroundColor(.gray).tracking(2)
            ForEach(0..<grid.count, id: \.self) { row in
                GannGridRow(rowValues:    grid[row],
                            centerValue:  centerValue,
                            startValue:   startValue,
                            targetAngle:  targetAngle)
            }
            HStack(spacing: 12) {
                GannDot(color: .yellow,            label: "Centro")
                GannDot(color: .orange,            label: "Valor")
                GannDot(color: .orange.opacity(0.5),label: "Mismo ángulo")
                GannDot(color: .cyan.opacity(0.7), label: "Cardinal")
            }
            .font(.caption2).foregroundColor(.gray).padding(.top, 4)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
    }
}

// MARK: - Key levels grid
struct GannKeyLevels: View {
    let levels:    [Double]
    let value:     Double
    let startValue: Double

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
            ForEach(levels, id: \.self) { v in
                let isTarget = abs(v - value) < 0.01
                let isCenter = abs(v - startValue) < 0.001
                Text(GannEngine.fmtFull(v))
                    .font(.system(size: 12, design: .monospaced))
                    .fontWeight(isTarget || isCenter ? .bold : .regular)
                    .foregroundColor(isTarget ? .orange : isCenter ? .yellow : .white)
                    .padding(6).frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 8).fill(
                        isTarget ? Color.orange.opacity(0.25) :
                        isCenter ? Color.yellow.opacity(0.15) :
                        Color.white.opacity(0.06)
                    ))
            }
        }
    }
}

// MARK: - Controls bar
struct GannControls: View {
    @Binding var centerText: String
    @Binding var inputText:  String
    @Binding var showGrid:   Bool
    let onCalculate: () -> Void

    private let presets = ["1","0","0.1","100","1000"]

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CENTRO").font(.caption2).foregroundColor(.gray).tracking(1)
                    TextField("ej. 1", text: $centerText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow).padding(8)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08)))
                }
                .frame(maxWidth: 90)

                VStack(alignment: .leading, spacing: 4) {
                    Text("VALOR").font(.caption2).foregroundColor(.gray).tracking(1)
                    TextField("ej. 100", text: $inputText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange).padding(8)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08)))
                }

                Button(action: onCalculate) {
                    VStack(spacing: 2) {
                        Image(systemName: "squareshape.split.3x3").font(.title2)
                        Text("Calc").font(.caption2)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.85)))
                    .foregroundColor(.white)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { p in
                        Button {
                            centerText = p
                            onCalculate()
                        } label: {
                            Text("C:\(p)").font(.caption2)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(
                                    centerText == p
                                    ? Color.yellow.opacity(0.3)
                                    : Color.white.opacity(0.08)))
                                .foregroundColor(centerText == p ? .yellow : .gray)
                        }
                    }
                }
                .padding(.horizontal)
            }

            Picker("Vista", selection: $showGrid) {
                Text("🔲 Cuadrado").tag(true)
                Text("🎯 Niveles").tag(false)
            }
            .pickerStyle(.segmented).padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.35))
    }
}

// MARK: - Summary cards row
struct GannSummary: View {
    let result: GannResult
    var body: some View {
        HStack(spacing: 10) {
            GannCard(title: "Centro", value: GannEngine.fmtFull(result.start),  color: .yellow)
            GannCard(title: "Valor",  value: GannEngine.fmtFull(result.value),  color: .orange)
            GannCard(title: "Anillo", value: "\(result.ring)",                   color: .cyan)
            GannCard(title: "Ángulo", value: String(format: "%.1f°", result.angle), color: .mint)
        }
        .padding(.horizontal)
    }
}

// MARK: - Main View
struct GannSquareView: View {
    @State private var inputText  = "100"
    @State private var centerText = "1"
    @State private var showGrid   = true
    @State private var result: GannResult? = nil
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.03, blue: 0.01),
                         Color(red: 0.02, green: 0.01, blue: 0.05)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                GannControls(centerText: $centerText, inputText: $inputText,
                             showGrid: $showGrid, onCalculate: calculate)
                    .focused($isInputFocused)

                if let r = result {
                    ScrollView {
                        VStack(spacing: 16) {
                            GannSummary(result: r)
                            if showGrid {
                                GannGridView(centerValue: r.value, startValue: r.start)
                                    .padding(.horizontal)
                            } else {
                                VStack(spacing: 8) {
                                    Text("NIVELES CARDINALES")
                                        .font(.caption).foregroundColor(.gray).tracking(2)
                                    ForEach(r.targets, id: \.0) { label, vals in
                                        GannCardinalRow(label: label, values: vals,
                                                        highlight: r.value)
                                    }
                                }
                                .padding(.horizontal)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("MISMO ÁNGULO")
                                        .font(.caption).foregroundColor(.gray).tracking(2)
                                    GannKeyLevels(levels: r.keyLevels,
                                                  value:  r.value,
                                                  startValue: r.start)
                                }
                                .padding(.horizontal)
                            }
                            infoBox
                        }
                        .padding(.bottom, 30)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "squareshape.split.3x3")
                            .font(.system(size: 50)).foregroundColor(.orange.opacity(0.3))
                        Text("Ingresa centro y valor").foregroundColor(.gray)
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle("Cuadrado de 9 — Gann")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") {
                    isInputFocused = false
                }
                .foregroundColor(.yellow)
            }
        }
        .onAppear { calculate() }
        .onTapGesture {
            isInputFocused = false
        }
    }

    private var infoBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ℹ️ Cómo usar").font(.caption).fontWeight(.bold).foregroundColor(.orange)
            Text("Centro: valor en el núcleo de la espiral (default 1). Valor: número a ubicar. Mismo ángulo = zonas de soporte/resistencia. Cardinales 0°/90°/180°/270° son los más potentes.")
                .font(.caption2).foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
        .padding(.horizontal)
    }

    private func calculate() {
        guard let v = Double(inputText), let sv = Double(centerText) else { return }
        let (ring, angle) = GannEngine.position(of: v, start: sv)
        result = GannResult(
            value: v, start: sv, ring: ring, angle: angle,
            targets:   GannEngine.cardinalTargets(for: v, start: sv),
            keyLevels: GannEngine.keyLevels(for: v, start: sv, count: 20)
        )
    }
}
