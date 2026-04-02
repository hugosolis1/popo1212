import SwiftUI

struct ContentView: View {
    @StateObject var vm = AstroViewModel()
    @State var showSettings = false
    @State var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PlanetListTab(vm: vm, showSettings: $showSettings)
                .tabItem { Label("Posiciones", systemImage: "globe") }
                .tag(0)

            NavigationView { DegreeFinderView() }
                .tabItem { Label("Buscador °", systemImage: "magnifyingglass.circle") }
                .tag(1)

            NavigationView { ZodiacWheelView() }
                .tabItem { Label("Carta Astral", systemImage: "circle.hexagonpath.fill") }
                .tag(2)

            NavigationView { GannSquareView() }
                .tabItem { Label("Gann 9", systemImage: "squareshape.split.3x3") }
                .tag(3)
        }
        .preferredColorScheme(.dark)
        .accentColor(.yellow)
    }
}

// MARK: - Planet List Tab
struct PlanetListTab: View {
    @ObservedObject var vm: AstroViewModel
    @Binding var showSettings: Bool
    @State private var selectedPlanet: PlanetPosition? = nil
    @State private var showAspects = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.07, green: 0.02, blue: 0.13),
                             Color(red: 0.00, green: 0.01, blue: 0.10)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        DatePicker("Fecha", selection: $vm.selectedDate,
                                   displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .colorScheme(.dark)
                            .padding(.horizontal)
                        
                        // UTC Offset Selector
                        HStack {
                            Text("Zona Horaria:")
                                .font(.subheadline).foregroundColor(.gray)
                            Spacer()
                            Menu {
                                ForEach(AstroViewModel.commonUTCOffsets, id: \.1) { offset in
                                    Button(offset.0) {
                                        vm.utcOffset = offset.1
                                        vm.compute()
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(vm.utcOffsetString)
                                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.cyan)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2).foregroundColor(.gray)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)

                        Picker("Perspectiva", selection: $vm.isGeocentric) {
                            Text("Geocéntrico").tag(true)
                            Text("Heliocéntrico").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        Button(action: { vm.compute() }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Calcular Posiciones").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.indigo)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 12).padding(.bottom, 8)
                    .background(Color.black.opacity(0.3))

                    if vm.isLoading {
                        Spacer()
                        ProgressView("Calculando...").foregroundColor(.white)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                // Ángulos
                                SectionHeader(title: "Ángulos de la Carta")
                                ForEach([vm.ascendantPosition, vm.midheavenPosition,
                                         vm.descendantPosition, vm.imumCoeliPosition,
                                         vm.northNodePosition, vm.southNodePosition]) { p in
                                    PlanetRow360(planet: p, isAngle: true)
                                        .onTapGesture { selectedPlanet = p }
                                }

                                // Planetas
                                SectionHeader(title: "Planetas")
                                ForEach(vm.planets) { p in
                                    PlanetRow360(planet: p, isAngle: false)
                                        .onTapGesture { selectedPlanet = p }
                                }
                                
                                // Casas
                                SectionHeader(title: "Casas Placidus")
                                ForEach(0..<12, id: \.self) { i in
                                    HouseRow(houseNumber: i + 1, cusp: vm.houseCusps[i])
                                }
                                
                                // Aspectos
                                SectionHeader(title: "Aspectos Planetarios")
                                ForEach(vm.aspects.prefix(15)) { aspect in
                                    AspectRow(aspect: aspect)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Grados Planetarios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings.toggle() } label: {
                        Image(systemName: "location.circle")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { LocationSettingsView(vm: vm) }
            .sheet(item: $selectedPlanet) { planet in PlanetDetailView(planet: planet) }
        }
        .onChange(of: vm.selectedDate) { _ in vm.compute() }
        .onChange(of: vm.isGeocentric) { _ in vm.compute() }
        .onChange(of: vm.utcOffset) { _ in vm.compute() }
    }
}

// MARK: - Shared sub-views

struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption).fontWeight(.bold)
                .foregroundColor(.yellow.opacity(0.8)).tracking(2)
            Spacer()
        }
        .padding(.top, 8).padding(.bottom, 2)
    }
}

// MARK: - Planet Row with 360 degree format
struct PlanetRow360: View {
    let planet: PlanetPosition
    let isAngle: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(symbolColor.opacity(0.2)).frame(width: 40, height: 40)
                Text(planet.symbol).font(.system(size: 20)).foregroundColor(symbolColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(planet.name)
                        .font(.system(size: 15)).fontWeight(.medium).foregroundColor(.white)
                    if planet.isRetrograde {
                        Text("℞").font(.caption).foregroundColor(.red)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.red.opacity(0.2)).cornerRadius(4)
                    }
                }
                Text(planet.sign.rawValue).font(.caption2).foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                // Grados 360 (formato principal)
                Text(String(format: "%.2f°", planet.longitude))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                
                // Signo y posición dentro del signo
                HStack(spacing: 2) {
                    Text(planet.sign.glyph).font(.caption)
                    Text("\(Int(planet.degreeInSign))°\(Int(planet.minuteInSign))'")
                        .font(.caption2).foregroundColor(.gray)
                }
            }

            Image(systemName: "chevron.right").font(.caption2).foregroundColor(.gray.opacity(0.5))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isAngle ? 0.07 : 0.05))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        )
        .contentShape(Rectangle())
    }

    var symbolColor: Color {
        if isAngle { return .yellow }
        switch planet.name {
        case "Sol":      return .yellow
        case "Luna":     return .white
        case "Mercurio": return .mint
        case "Venus":    return .pink
        case "Marte":    return .red
        case "Júpiter":  return .orange
        case "Saturno":  return Color(red: 0.7, green: 0.5, blue: 0.2)
        case "Urano":    return .cyan
        case "Neptuno":  return .blue
        case "Plutón":   return .purple
        case "Nodo Norte": return .green
        case "Nodo Sur": return .red
        default: return .gray
        }
    }
}

// MARK: - House Row
struct HouseRow: View {
    let houseNumber: Int
    let cusp: Double
    
    var sign: ZodiacSign { ZodiacSign.from(longitude: cusp) }
    
    var body: some View {
        HStack {
            Text("Casa \(houseNumber)")
                .font(.subheadline).foregroundColor(.white)
            Spacer()
            HStack(spacing: 4) {
                Text(sign.glyph).font(.title3)
                Text(String(format: "%.2f°", cusp))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }
}

// MARK: - Aspect Row
struct AspectRow: View {
    let aspect: AstronomicalEngine.Aspect
    
    var aspectColor: Color {
        switch aspect.aspect {
        case .conjunction: return .green
        case .opposition: return .red
        case .trine: return .blue
        case .square: return .orange
        case .sextile: return .cyan
        case .quincunx: return .purple
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Text(aspect.planet1Symbol)
                .font(.system(size: 18))
                .frame(width: 28)
            
            Text(aspect.aspect.symbol)
                .font(.system(size: 16))
                .foregroundColor(aspectColor)
                .frame(width: 24)
            
            Text(aspect.planet2Symbol)
                .font(.system(size: 18))
                .frame(width: 28)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(aspect.aspect.rawValue)
                    .font(.caption).foregroundColor(aspectColor)
                Text(String(format: "órbe: %.1f°", aspect.orb))
                    .font(.caption2).foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(aspectColor.opacity(0.3), lineWidth: 1))
        )
    }
}

// Original PlanetRow kept for compatibility
struct PlanetRow: View {
    let planet: PlanetPosition
    let isAngle: Bool

    var body: some View {
        PlanetRow360(planet: planet, isAngle: isAngle)
    }
}
