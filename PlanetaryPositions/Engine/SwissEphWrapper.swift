import Foundation

// MARK: - Swiss Ephemeris Wrapper for Swift
// Provides a clean Swift interface to the C library

class SwissEphemeris {

    // MARK: - Constants
    struct Planet {
        static let sun = Int32(SE_SUN)
        static let moon = Int32(SE_MOON)
        static let mercury = Int32(SE_MERCURY)
        static let venus = Int32(SE_VENUS)
        static let mars = Int32(SE_MARS)
        static let jupiter = Int32(SE_JUPITER)
        static let saturn = Int32(SE_SATURN)
        static let uranus = Int32(SE_URANUS)
        static let neptune = Int32(SE_NEPTUNE)
        static let pluto = Int32(SE_PLUTO)
        static let meanNode = Int32(SE_MEAN_NODE)
        static let trueNode = Int32(SE_TRUE_NODE)
    }

    struct Flags {
        static let swissEph = Int32(SEFLG_SWIEPH)
        static let heliocentric = Int32(SEFLG_HELCTR)
        static let speed = Int32(SEFLG_SPEED)
        static let equatorial = Int32(SEFLG_EQUATORIAL)
        static let topocentric = Int32(SEFLG_TOPOCTR)
    }

    // MARK: - Julian Day Calculation

    /// Calculate Julian Day from calendar date
    static func julianDay(year: Int, month: Int, day: Int, hour: Double, gregorian: Bool = true) -> Double {
        let gregFlag: Int32 = gregorian ? SE_GREG_CAL : SE_JUL_CAL
        return swe_julday(Int32(year), Int32(month), Int32(day), hour, gregFlag)
    }

    /// Convert Julian Day to calendar date
    static func reverseJulian(_ jd: Double, gregorian: Bool = true) -> (year: Int, month: Int, day: Int, hour: Double) {
        var year: Int32 = 0
        var month: Int32 = 0
        var day: Int32 = 0
        var hour: Double = 0
        let gregFlag: Int32 = gregorian ? SE_GREG_CAL : SE_JUL_CAL
        swe_revjul(jd, gregFlag, &year, &month, &day, &hour)
        return (Int(year), Int(month), Int(day), hour)
    }

    /// Convert Date to Julian Day with UTC offset
    static func julianDayFrom(date: Date, utcOffset: Double = 0) -> Double {
        let calendar = Calendar(identifier: .gregorian)
        let utcDate = date.addingTimeInterval(-utcOffset * 3600)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: utcDate)

        let year = comps.year ?? 2000
        let month = comps.month ?? 1
        let day = comps.day ?? 1
        let hour = Double(comps.hour ?? 12) + Double(comps.minute ?? 0) / 60.0 + Double(comps.second ?? 0) / 3600.0

        return julianDay(year: year, month: month, day: day, hour: hour, gregorian: true)
    }

    // MARK: - Planet Calculations

    /// Calculate planet position
    /// Returns: (longitude, latitude, distance, speedLong, speedLat, speedDist)
    static func calculatePlanet(jd: Double, planetId: Int32, flags: Int32 = 0) -> (lon: Double, lat: Double, dist: Double, speedLon: Double, speedLat: Double, speedDist: Double, retrograde: Bool) {
        var xx = [Double](repeating: 0, count: 6)
        var serr = [Int8](repeating: 0, count: 256)

        let iflag = Flags.swissEph | Flags.speed | flags
        let result = swe_calc_ut(jd, planetId, iflag, &xx, &serr)

        if result < 0 {
            // Error - return zeros
            return (0, 0, 0, 0, 0, 0, false)
        }

        let retrograde = xx[3] < 0

        return (xx[0], xx[1], xx[2], xx[3], xx[4], xx[5], retrograde)
    }

    /// Calculate heliocentric planet position
    static func calculatePlanetHeliocentric(jd: Double, planetId: Int32) -> (lon: Double, lat: Double, dist: Double, speedLon: Double) {
        var xx = [Double](repeating: 0, count: 6)
        var serr = [Int8](repeating: 0, count: 256)

        let iflag = Flags.swissEph | Flags.speed | Flags.heliocentric
        let _ = swe_calc_ut(jd, planetId, iflag, &xx, &serr)

        return (xx[0], xx[1], xx[2], xx[3])
    }

    // MARK: - House Calculations

    /// Calculate house cusps and angles
    /// Returns: (cusps array[12], ascendant, mc, armc, vertex)
    static func calculateHouses(jd: Double, latitude: Double, longitude: Double, houseSystem: Int32 = 80) -> (cusps: [Double], asc: Double, mc: Double, armc: Double, vertex: Double) {
        // houseSystem: 80 = 'P' (Placidus)
        var cusps = [Double](repeating: 0, count: 13)  // Index 0-12, cusps[0] unused
        var ascmc = [Double](repeating: 0, count: 10)
        var serr = [Int8](repeating: 0, count: 256)

        let _ = swe_houses(jd, latitude, longitude, houseSystem, &cusps, &ascmc, &serr)

        // Extract cusps (1-12)
        let houseCusps = Array(cusps[1...12])

        return (houseCusps, ascmc[0], ascmc[1], ascmc[2], ascmc[3])
    }

    // MARK: - Lunar Nodes

    /// Calculate mean lunar node
    static func calculateMeanNode(jd: Double) -> Double {
        let result = calculatePlanet(jd: jd, planetId: Planet.meanNode)
        return result.lon
    }

    /// Calculate true lunar node
    static func calculateTrueNode(jd: Double) -> Double {
        let result = calculatePlanet(jd: jd, planetId: Planet.trueNode)
        return result.lon
    }

    // MARK: - Ayanamsa

    /// Get ayanamsa (precession)
    static func getAyanamsa(jd: Double) -> Double {
        return swe_get_ayanamsa_ut(jd)
    }

    // MARK: - Utility

    /// Get planet name
    static func getPlanetName(_ planetId: Int32) -> String {
        var nameBuffer = [Int8](repeating: 0, count: 30)
        let namePtr = swe_get_planet_name(planetId)
        return String(cString: namePtr!)
    }

    /// Normalize angle to 0-360
    static func normalizeAngle(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 360)
        if a < 0 { a += 360 }
        return a
    }
}
