import SwiftUI

// MARK: - Model
struct DegreeArrival: Identifiable {
    let id = UUID()
    let planetName: String
    let planetSymbol: String
    let date: Date
    let exactLongitude: Double
    let direction: String
}

// MARK: - Search Engine (pure logic, no View)
enum DegreeSearchEngine {
    static let planetNames  = ["Sol","Luna","Mercurio","Venus","Marte",
                                "Júpiter","Saturno","Urano","Neptuno","Plutón"]
    static let planetSymbols = ["☉","☽","☿","♀","♂","♃","♄","♅","♆","♇"]

    static func longitude(name: String, date: Date) -> Double {
        let jd = AstronomicalEngine.julianDay(date: date)
        let t  = AstronomicalEngine.T(jd: jd)
        switch name {
        case "Sol":      return AstronomicalEngine.sunLongitude(T: t)
        case "Luna":     return AstronomicalEngine.moonLongitude(T: t).lon
        case "Mercurio": return AstronomicalEngine.mercuryLongitude(T: t).lon
        case "Venus":    return AstronomicalEngine.venusLongitude(T: t).lon
        case "Marte":    return AstronomicalEngine.marsLongitude(T: t).lon
        case "Júpiter":  return AstronomicalEngine.jupiterLongitude(T: t).lon
        case "Saturno":  return AstronomicalEngine.saturnLongitude(T: t).lon
        case "Urano":    return AstronomicalEngine.uranusLongitude(T: t).lon
        case "Neptuno":  return AstronomicalEngine.neptuneLongitude(T: t).lon
        case "Plutón":   return AstronomicalEngine.plutoLongitude(T: t).lon
        default:         return 0
        }
    }

    static func angularDelta(from a: Double, to b: Double) -> Double {
        var d = b - a
        while d >  180 { d -= 360 }
        while d < -180 { d += 360 }
        return d
    }

    static func crosses(prev: Double, cur: Double, target: Double) -> Bool {
        let delta = angularDelta(from: prev, to: cur)
        if abs(delta) > 180 { return false }
        if delta >= 0 {
            if prev <= target && cur > target { return true }
            if prev > cur && (target >= prev || target < cur) { return true }
        } else {
            if prev >= target && cur < target { return true }
            if prev < cur && (target <= prev || target > cur) { return true }
        }
        return false
    }

    static func binarySearch(name: String, target: Double,
                              low: Date, high: Date) -> Date {
        var lo = low; var hi = high
        for _ in 0..<40 {
            let mid = Date(timeIntervalSince1970:
                (lo.timeIntervalSince1970 + hi.timeIntervalSince1970) / 2)
            let mLon = longitude(name: name, date: mid)
            let lLon = longitude(name: name, date: lo)
            if crosses(prev: lLon, cur: mLon, target: target) { hi = mid }
            else { lo = mid }
        }
        return Date(timeIntervalSince1970:
            (lo.timeIntervalSince1970 + hi.timeIntervalSince1970) / 2)
    }

    static func search(degree: Double, year: Int,
                       completion: @escaping ([DegreeArrival]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var found: [DegreeArrival] = []
            let cal = Calendar(identifier: .gregorian)
            guard
                let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
                let end   = cal.date(from: DateComponents(year: year+1, month: 1, day: 1))
            else { completion([]); return }

            for (idx, name) in planetNames.enumerated() {
                let step: Double = idx <= 3 ? 3600 : 21600
                var t    = start
                var prev = longitude(name: name, date: t)
                t = t.addingTimeInterval(step)
                while t <= end {
                    let cur  = longitude(name: name, date: t)
                    let prev2 = t.addingTimeInterval(-step)
                    if crosses(prev: prev, cur: cur, target: degree) {
                        let exact    = binarySearch(name: name, target: degree,
                                                     low: prev2, high: t)
                        let exactLon = longitude(name: name, date: exact)
                        let dir      = angularDelta(from: prev, to: cur) < 0
                                       ? "Retrógrado" : "Directo"
                        found.append(DegreeArrival(
                            planetName: name, planetSymbol: planetSymbols[idx],
                            date: exact, exactLongitude: exactLon, direction: dir))
                    }
                    prev = cur
                    t = t.addingTimeInterval(step)
                }
            }
            found.sort { $0.date < $1.date }
            DispatchQueue.main.async { completion(found) }
        }
    }
}

// MARK: - Arrival Row (standalone struct)
struct ArrivalRowView: View {
    let arrival: DegreeArrival

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy  HH:mm"
        f.locale = Locale(identifier: "es_MX")
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(arrival.direction == "Retrógrado"
                          ? Color.red.opacity(0.2) : Color.indigo.opacity(0.2))
                    .frame(width: 44, height: 44)
                Text(arrival.planetSymbol).font(.system(size: 22))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(arrival.planetName)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(.white)
                    if arrival.direction == "Retrógrado" {
                        Text("℞").font(.caption).foregroundColor(.red)
                            .padding(.horizontal, 4)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                Text(arrival.direction)
                    .font(.caption2)
                    .foregroundColor(arrival.direction == "Retrógrado" ? .red : .green)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(Self.df.string(from: arrival.date))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.yellow)
                Text(String(format: "%.3f°", arrival.exactLongitude))
                    .font(.caption2).foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
}

// MARK: - Controls (standalone struct)
struct DegreeFinderControls: View {
    @Binding var targetDegree: String
    @Binding var searchYear: Int
    let isSearching: Bool
    let onSearch: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GRADO (0°–359°)")
                        .font(.caption2).foregroundColor(.gray).tracking(1)
                    TextField("ej. 111", text: $targetDegree)
                        .keyboardType(.numberPad)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.08))
                        )
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("AÑO")
                        .font(.caption2).foregroundColor(.gray).tracking(1)
                    HStack {
                        Button { searchYear -= 1 } label: {
                            Image(systemName: "chevron.left").foregroundColor(.yellow)
                        }
                        Text("\(searchYear)")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(minWidth: 55)
                        Button { searchYear += 1 } label: {
                            Image(systemName: "chevron.right").foregroundColor(.yellow)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08))
                    )
                }
            }
            .padding(.horizontal)

            Button(action: onSearch) {
                HStack {
                    if isSearching {
                        ProgressView().tint(.white)
                        Text("Buscando...").fontWeight(.semibold)
                    } else {
                        Image(systemName: "magnifyingglass.circle.fill")
                        Text("Buscar Tránsitos al \(targetDegree)°").fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSearching ? Color.gray : Color.indigo)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isSearching)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - Results list (standalone struct)
struct DegreeResultsList: View {
    let results: [DegreeArrival]
    let targetDegree: String

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                Text("\(results.count) tránsitos — \(targetDegree)°")
                    .font(.caption).foregroundColor(.gray).padding(.top, 8)
                ForEach(results) { r in
                    ArrivalRowView(arrival: r)
                }
            }
            .padding()
        }
    }
}

// MARK: - Empty state (standalone struct)
struct DegreeFinderEmpty: View {
    let isSearching: Bool
    let searched: Bool
    let targetDegree: String

    var body: some View {
        VStack(spacing: 12) {
            if isSearching {
                ProgressView().scaleEffect(1.4).tint(.yellow)
                Text("Calculando tránsitos...").foregroundColor(.gray).font(.subheadline)
            } else if searched {
                Image(systemName: "magnifyingglass").font(.largeTitle)
                    .foregroundColor(.gray.opacity(0.4))
                Text("Sin resultados para \(targetDegree)°")
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "sparkles").font(.largeTitle)
                    .foregroundColor(.indigo.opacity(0.5))
                Text("Ingresa un grado y el año").foregroundColor(.gray).font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Main View
struct DegreeFinderView: View {
    @State private var targetDegree = "111"
    @State private var searchYear   = Calendar.current.component(.year, from: Date())
    @State private var results: [DegreeArrival] = []
    @State private var isSearching  = false
    @State private var searched     = false

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.01, blue: 0.12).ignoresSafeArea()
            VStack(spacing: 0) {
                DegreeFinderControls(
                    targetDegree: $targetDegree,
                    searchYear:   $searchYear,
                    isSearching:  isSearching,
                    onSearch:     runSearch
                )
                if !results.isEmpty {
                    DegreeResultsList(results: results, targetDegree: targetDegree)
                } else {
                    DegreeFinderEmpty(isSearching: isSearching,
                                      searched:    searched,
                                      targetDegree: targetDegree)
                }
            }
        }
        .navigationTitle("Buscador de Grados")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func runSearch() {
        guard let deg = Double(targetDegree), deg >= 0, deg < 360 else { return }
        isSearching = true
        searched    = false
        results     = []
        DegreeSearchEngine.search(degree: deg, year: searchYear) { found in
            self.results     = found
            self.isSearching = false
            self.searched    = true
        }
    }
}
