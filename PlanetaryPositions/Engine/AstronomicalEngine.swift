import Foundation

// MARK: - Astronomical Constants
struct AstroConstants {
    static let J2000: Double = 2451545.0
    static let DEG_TO_RAD: Double = .pi / 180.0
    static let RAD_TO_DEG: Double = 180.0 / .pi
}

// MARK: - Planet Data Model
struct PlanetPosition: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let longitude: Double      // ecliptic longitude degrees 0-360
    let latitude: Double       // ecliptic latitude degrees
    let distance: Double       // AU
    let speed: Double          // degrees/day (negative = retrograde)
    let sign: ZodiacSign
    let degreeInSign: Double
    let minuteInSign: Double
    let secondInSign: Double
    var isRetrograde: Bool { speed < 0 }

    var formattedPosition: String {
        let d = Int(degreeInSign)
        let m = Int(minuteInSign)
        let s = Int(secondInSign)
        return "\(d)°\(m)'\(s)\" \(sign.rawValue)"
    }

    var decimalDegreeInSign: Double { degreeInSign + minuteInSign / 60.0 + secondInSign / 3600.0 }
}

// MARK: - Zodiac
enum ZodiacSign: String, CaseIterable {
    case aries = "♈ Aries"
    case taurus = "♉ Tauro"
    case gemini = "♊ Géminis"
    case cancer = "♋ Cáncer"
    case leo = "♌ Leo"
    case virgo = "♍ Virgo"
    case libra = "♎ Libra"
    case scorpio = "♏ Escorpio"
    case sagittarius = "♐ Sagitario"
    case capricorn = "♑ Capricornio"
    case aquarius = "♒ Acuario"
    case pisces = "♓ Piscis"

    var glyph: String {
        switch self {
        case .aries: return "♈"
        case .taurus: return "♉"
        case .gemini: return "♊"
        case .cancer: return "♋"
        case .leo: return "♌"
        case .virgo: return "♍"
        case .libra: return "♎"
        case .scorpio: return "♏"
        case .sagittarius: return "♐"
        case .capricorn: return "♑"
        case .aquarius: return "♒"
        case .pisces: return "♓"
        }
    }

    static func from(longitude: Double) -> ZodiacSign {
        let norm = longitude.truncatingRemainder(dividingBy: 360)
        let pos = norm < 0 ? norm + 360 : norm
        let idx = Int(pos / 30.0) % 12
        return ZodiacSign.allCases[idx]
    }
}

// MARK: - Chart Angles
struct ChartAngles {
    let ascendant: Double
    let descendant: Double
    let midheaven: Double
    let imumCoeli: Double
    let northNode: Double
    let southNode: Double
}

// MARK: - Astronomical Engine - Swiss Ephemeris Implementation
class AstronomicalEngine {

    // MARK: - Utility Functions

    /// Normalize angle to 0-360
    static func norm360(_ angle: Double) -> Double {
        return SwissEphemeris.normalizeAngle(angle)
    }

    /// Convert decimal degrees to DMS
    static func toDMS(degrees: Double) -> (d: Double, m: Double, s: Double) {
        let total = abs(degrees)
        let d = floor(total)
        let mFrac = (total - d) * 60
        let m = floor(mFrac)
        let s = (mFrac - m) * 60
        return (d, m, s)
    }

    /// Get current UTC offset in hours
    static func currentUTCOffset() -> Double {
        return Double(TimeZone.current.secondsFromGMT()) / 3600.0
    }

    // MARK: - Main Compute Function using Swiss Ephemeris

    static func computePositions(date: Date, utcOffset: Double, isGeocentric: Bool,
                                  latitude: Double, longitude: Double) -> ([PlanetPosition], ChartAngles) {
        // Calculate Julian Day
        let jd = SwissEphemeris.julianDayFrom(date: date, utcOffset: utcOffset)

        // Calculate houses and angles
        let houses = SwissEphemeris.calculateHouses(jd: jd, latitude: latitude, longitude: longitude)

        // Determine calculation flags
        let flags: Int32 = isGeocentric ? 0 : SwissEphemeris.Flags.heliocentric

        // Calculate planetary positions
        var planets: [PlanetPosition] = []

        // Sun
        let sunData = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.sun, flags: flags)
        planets.append(makePlanetPosition(name: "Sol", symbol: "☉", data: sunData))

        // Moon
        let moonData = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.moon, flags: flags)
        planets.append(makePlanetPosition(name: "Luna", symbol: "☽", data: moonData))

        // Mercury
        let mercuryData = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.mercury, flags: flags)
        planets.append(makePlanetPosition(name: "Mercurio", symbol: "☿", data: mercuryData))

        // Venus
        let venusData = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.venus, flags: flags)
        planets.append(makePlanetPosition(name: "Venus", symbol: "♀", data: venusData))

        // Mars
        let marsData = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.mars, flags: flags)
        planets.append(makePlanetPosition(name: "Marte", symbol: "♂", data: marsData))

        // Jupiter
        let jupiterData = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.jupiter, flags: flags)
        planets.append(makePlanetPosition(name: "Júpiter", symbol: "♃", data: jupiterData))

        // Saturn
        let saturnData = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.saturn, flags: flags)
        planets.append(makePlanetPosition(name: "Saturno", symbol: "♄", data: saturnData))

        // Uranus
        let uranusData = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.uranus, flags: flags)
        planets.append(makePlanetPosition(name: "Urano", symbol: "♅", data: uranusData))

        // Neptune
        let neptuneData = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.neptune, flags: flags)
        planets.append(makePlanetPosition(name: "Neptuno", symbol: "♆", data: neptuneData))

        // Pluto
        let plutoData = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.pluto, flags: flags)
        planets.append(makePlanetPosition(name: "Plutón", symbol: "♇", data: plutoData))

        // Mean Lunar Node (North Node)
        let nodeData = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.meanNode, flags: flags)
        planets.append(makePlanetPosition(name: "Nodo Norte", symbol: "☊", data: nodeData))

        // South Node is opposite to North Node
        let southNodeLon = norm360(nodeData.lon + 180)
        let southNodeDms = toDMS(degrees: southNodeLon.truncatingRemainder(dividingBy: 30))
        let southNode = PlanetPosition(
            name: "Nodo Sur", symbol: "☋",
            longitude: southNodeLon, latitude: 0, distance: 0, speed: nodeData.speedLon,
            sign: ZodiacSign.from(longitude: southNodeLon),
            degreeInSign: southNodeDms.d, minuteInSign: southNodeDms.m, secondInSign: southNodeDms.s
        )
        planets.append(southNode)

        // Chart angles
        let angles = ChartAngles(
            ascendant: houses.asc,
            descendant: norm360(houses.asc + 180),
            midheaven: houses.mc,
            imumCoeli: norm360(houses.mc + 180),
            northNode: nodeData.lon,
            southNode: southNodeLon
        )

        return (planets, angles)
    }

    // MARK: - Helper Functions

    private static func makePlanetPosition(name: String, symbol: String,
                                            data: (lon: Double, lat: Double, dist: Double, speedLon: Double, speedLat: Double, speedDist: Double, retrograde: Bool)) -> PlanetPosition {
        let lon = norm360(data.lon)
        let sign = ZodiacSign.from(longitude: lon)
        let degInSign = lon.truncatingRemainder(dividingBy: 30)
        let dms = toDMS(degrees: degInSign)

        return PlanetPosition(
            name: name,
            symbol: symbol,
            longitude: lon,
            latitude: data.lat,
            distance: data.dist,
            speed: data.speedLon,
            sign: sign,
            degreeInSign: dms.d,
            minuteInSign: dms.m,
            secondInSign: dms.s
        )
    }

    // MARK: - House Calculations

    static func calculateHouses(date: Date, utcOffset: Double, latitude: Double, longitude: Double) -> [Double] {
        let jd = SwissEphemeris.julianDayFrom(date: date, utcOffset: utcOffset)
        let houses = SwissEphemeris.calculateHouses(jd: jd, latitude: latitude, longitude: longitude)
        return houses.cusps
    }

    // MARK: - Planetary Aspects

    enum AspectType: String {
        case conjunction = "Conjunción"
        case opposition = "Oposición"
        case trine = "Trino"
        case square = "Cuadratura"
        case sextile = "Sextil"
        case quincunx = "Quincuncio"
        case semisextile = "Semisextil"
        case semisquare = "Semicuadratura"

        var symbol: String {
            switch self {
            case .conjunction: return "☌"
            case .opposition: return "☍"
            case .trine: return "△"
            case .square: return "□"
            case .sextile: return "✶"
            case .quincunx: return "⚹"
            case .semisextile: return "⚶"
            case .semisquare: return "∠"
            }
        }

        var angle: Double {
            switch self {
            case .conjunction: return 0
            case .semisextile: return 30
            case .semisquare: return 45
            case .sextile: return 60
            case .square: return 90
            case .trine: return 120
            case .quincunx: return 150
            case .opposition: return 180
            }
        }

        var orb: Double {
            switch self {
            case .conjunction: return 10
            case .opposition: return 8
            case .trine: return 8
            case .square: return 8
            case .sextile: return 6
            case .quincunx: return 3
            case .semisextile: return 3
            case .semisquare: return 2
            }
        }
    }

    struct Aspect: Identifiable {
        let id = UUID()
        let planet1: String
        let planet1Symbol: String
        let planet2: String
        let planet2Symbol: String
        let aspect: AspectType
        let angle: Double
        let orb: Double
        let applying: Bool
    }

    static func angularDifference(_ lon1: Double, _ lon2: Double) -> Double {
        var diff = abs(lon1 - lon2)
        if diff > 180 { diff = 360 - diff }
        return diff
    }

    static func isApplying(lon1: Double, speed1: Double, lon2: Double, speed2: Double, exactAngle: Double) -> Bool {
        let diff = lon2 - lon1
        var normDiff = diff
        while normDiff > 180 { normDiff -= 360 }
        while normDiff < -180 { normDiff += 360 }

        let relativeSpeed = speed2 - speed1
        return (normDiff > 0 && relativeSpeed < 0) || (normDiff < 0 && relativeSpeed > 0)
    }

    static func calculateAspects(planets: [PlanetPosition]) -> [Aspect] {
        var aspects: [Aspect] = []

        for i in 0..<planets.count {
            for j in (i+1)..<planets.count {
                let p1 = planets[i]
                let p2 = planets[j]

                let diff = angularDifference(p1.longitude, p2.longitude)

                for aspectType in [AspectType.conjunction, AspectType.sextile, AspectType.square, AspectType.trine, AspectType.opposition, AspectType.quincunx] {
                    let exactAngle = aspectType.angle
                    let orb = aspectType.orb
                    let deviation = abs(diff - exactAngle)

                    if deviation <= orb {
                        let applying = isApplying(
                            lon1: p1.longitude, speed1: p1.speed,
                            lon2: p2.longitude, speed2: p2.speed,
                            exactAngle: exactAngle
                        )

                        aspects.append(Aspect(
                            planet1: p1.name,
                            planet1Symbol: p1.symbol,
                            planet2: p2.name,
                            planet2Symbol: p2.symbol,
                            aspect: aspectType,
                            angle: exactAngle,
                            orb: deviation,
                            applying: applying
                        ))
                        break
                    }
                }
            }
        }

        return aspects.sorted { $0.orb < $1.orb }
    }
    
    // MARK: - Helper Functions for DegreeFinderView
    
    /// Convert date to Julian Day (for DegreeFinderView compatibility)
    static func julianDay(date: Date) -> Double {
        return SwissEphemeris.julianDayFrom(date: date, utcOffset: 0)
    }
    
    /// Julian centuries from J2000 (for DegreeFinderView compatibility)
    static func T(jd: Double) -> Double {
        return (jd - AstroConstants.J2000) / 36525.0
    }
    
    /// Get Sun longitude for a given T (for DegreeFinderView compatibility)
    static func sunLongitude(T: Double) -> Double {
        // Mean longitude
        var L = 280.4664567 + 360007.6982779 * T
        // Mean anomaly
        let M = norm360(357.5291092 + 35999.0502909 * T - 0.0001536 * T * T) * AstroConstants.DEG_TO_RAD
        // Equation of center
        var C = 0.0
        C += (1.914602 - 0.004817 * T) * sin(M)
        C += (0.019993 - 0.000101 * T) * sin(2 * M)
        C += 0.000289 * sin(3 * M)
        L += C
        // Aberration
        let omega = (125.04 - 1934.136 * T) * AstroConstants.DEG_TO_RAD
        let aberr = -0.00569 - 0.00478 * sin(omega)
        return norm360(L + aberr)
    }
    
    /// Get Moon longitude for a given T (for DegreeFinderView compatibility)
    static func moonLongitude(T: Double) -> (lon: Double, lat: Double, dist: Double) {
        let jd = AstroConstants.J2000 + T * 36525.0
        let data = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.moon)
        return (data.lon, data.lat, data.dist)
    }
    
    /// Get Mercury longitude for a given T
    static func mercuryLongitude(T: Double) -> (lon: Double, lat: Double, dist: Double, speed: Double) {
        let jd = AstroConstants.J2000 + T * 36525.0
        let data = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.mercury)
        return (data.lon, data.lat, data.dist, data.speedLon)
    }
    
    /// Get Venus longitude for a given T
    static func venusLongitude(T: Double) -> (lon: Double, lat: Double, dist: Double, speed: Double) {
        let jd = AstroConstants.J2000 + T * 36525.0
        let data = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.venus)
        return (data.lon, data.lat, data.dist, data.speedLon)
    }
    
    /// Get Mars longitude for a given T
    static func marsLongitude(T: Double) -> (lon: Double, lat: Double, dist: Double, speed: Double) {
        let jd = AstroConstants.J2000 + T * 36525.0
        let data = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.mars)
        return (data.lon, data.lat, data.dist, data.speedLon)
    }
    
    /// Get Jupiter longitude for a given T
    static func jupiterLongitude(T: Double) -> (lon: Double, lat: Double, dist: Double, speed: Double) {
        let jd = AstroConstants.J2000 + T * 36525.0
        let data = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.jupiter)
        return (data.lon, data.lat, data.dist, data.speedLon)
    }
    
    /// Get Saturn longitude for a given T
    static func saturnLongitude(T: Double) -> (lon: Double, lat: Double, dist: Double, speed: Double) {
        let jd = AstroConstants.J2000 + T * 36525.0
        let data = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.saturn)
        return (data.lon, data.lat, data.dist, data.speedLon)
    }
    
    /// Get Uranus longitude for a given T
    static func uranusLongitude(T: Double) -> (lon: Double, lat: Double, dist: Double, speed: Double) {
        let jd = AstroConstants.J2000 + T * 36525.0
        let data = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.uranus)
        return (data.lon, data.lat, data.dist, data.speedLon)
    }
    
    /// Get Neptune longitude for a given T
    static func neptuneLongitude(T: Double) -> (lon: Double, lat: Double, dist: Double, speed: Double) {
        let jd = AstroConstants.J2000 + T * 36525.0
        let data = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.neptune)
        return (data.lon, data.lat, data.dist, data.speedLon)
    }
    
    /// Get Pluto longitude for a given T
    static func plutoLongitude(T: Double) -> (lon: Double, lat: Double, dist: Double, speed: Double) {
        let jd = AstroConstants.J2000 + T * 36525.0
        let data = SwissEphemeris.calculatePlanet(jd: jd, planetId: SwissEphemeris.Planet.pluto)
        return (data.lon, data.lat, data.dist, data.speedLon)
    }
}
