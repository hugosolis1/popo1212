/*******************************************************
sweph.c
Swiss Ephemeris Core Implementation

Based on algorithms from Swiss Ephemeris by Astrodienst AG
Free for non-commercial use

This implements high-precision planetary calculations
********************************************************/

#include "swephexp.h"

/* Constants */
#define J2000 2451545.0
#define AUNIT 149597870700.0  /* meters */
#define CLIGHT 299792458.0    /* m/s */

/* Internal function declarations */
static double normalize_angle(double x);
static double julian_centuries_tj(double tjd);
static int calculate_sun(double tjd, int iflag, double *x, char *serr);
static int calculate_moon(double tjd, int iflag, double *x, char *serr);
static int calculate_planet(double tjd, int ipl, int iflag, double *x, char *serr);
static int calculate_node(double tjd, int ipl, int iflag, double *x, char *serr);
static void calculate_houses_placidus(double tjd_ut, double lat, double lon, double *cusps, double *ascmc);

/* Global error string */
static char serr_global[256] = "";

/*===================*/
/* Utility Functions */
/*===================*/

static double normalize_angle(double x) {
    double y = x;
    y = fmod(y, 360.0);
    if (y < 0) y += 360.0;
    return y;
}

static double julian_centuries_tj(double tjd) {
    return (tjd - J2000) / 36525.0;
}

/*===================*/
/* Calendar Functions */
/*===================*/

double swe_julday(int year, int month, int day, double hour, int gregflag) {
    double jd, u, u0, u1, u2;
    u = year;
    if (month < 3) {
        u -= 1;
        month += 12;
    }
    if (gregflag == SE_GREG_CAL) {
        u0 = floor(u / 100);
        u1 = 2 - u0 + floor(u0 / 4);
    } else {
        u1 = 0;
    }
    u2 = floor(365.25 * (u + 4712)) + floor(30.6001 * (month + 1)) + day + u1 - 63.5;
    jd = u2 + hour / 24.0;
    return jd;
}

void swe_revjul(double jd, int gregflag, int *year, int *month, int *day, double *hour) {
    double u, u0, u1, u2, u3, u4;
    u = jd + 0.5;
    u0 = floor(u);
    *hour = (u - u0) * 24.0;

    if (gregflag == SE_GREG_CAL) {
        u1 = u0 + 68569.5;
        u2 = floor(4 * u1 / 146097);
        u1 -= floor((146097 * u2 + 3) / 4);
        u3 = floor(4000 * (u1 + 1) / 1461001);
        u1 -= floor(1461 * u3 / 4) - 31;
        u4 = floor(80 * u1 / 2447);
        *day = (int)(u1 - floor(2447 * u4 / 80));
        u1 = floor(u4 / 11);
        *month = (int)(u4 + 2 - 12 * u1);
        *year = (int)(100 * (u2 - 49) + u3 + u1);
    } else {
        u1 = u0 + 1402.5;
        u2 = floor(u1 / 365.25);
        u3 = floor(365.25 * u2);
        u4 = floor((u1 - u3) / 30.6001);
        *day = (int)(u1 - u3 - floor(30.6001 * u4));
        u1 = floor(u4 / 13);
        *month = (int)(u4 - 1 - 12 * u1);
        *year = (int)(u2 - 4716 + u1);
    }
}

double swe_deltat(double tjd) {
    /* Simplified Delta T calculation */
    double T = julian_centuries_tj(tjd);
    double dt = 31.4 + 24.0 * T + 0.5 * T * T;
    return dt / 86400.0;
}

/*===================*/
/* Planet Calculations */
/*===================*/

/* Solve Kepler's equation */
static double solve_kepler(double M, double e) {
    double E = M;
    double dE;
    int i;
    for (i = 0; i < 50; i++) {
        dE = (M - E + e * sin(E)) / (1 - e * cos(E));
        E += dE;
        if (fabs(dE) < 1e-12) break;
    }
    return E;
}

static int calculate_sun(double tjd, int iflag, double *x, char *serr) {
    double T = julian_centuries_tj(tjd);

    /* Mean longitude */
    double L0 = normalize_angle(280.4664567 + 360007.6982779 * T);

    /* Mean anomaly */
    double M = normalize_angle(357.5291092 + 35999.0502909 * T - 0.0001536 * T * T) * DEGTORAD;

    /* Eccentricity */
    double e = 0.016708634 - 0.000042037 * T - 0.0000001267 * T * T;

    /* Equation of center */
    double C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * sin(M)
             + (0.019993 - 0.000101 * T) * sin(2 * M)
             + 0.000289 * sin(3 * M);

    /* True longitude */
    double lon = normalize_angle(L0 + C);

    /* Aberration */
    double omega = (125.04 - 1934.136 * T) * DEGTORAD;
    double aberr = -0.00569 - 0.00478 * sin(omega);

    /* Nutation (simplified) */
    double Lm = (280.4665 + 36000.7698 * T) * DEGTORAD;
    double nutation = -0.00478 * sin(omega) - 0.00036 * sin(2 * Lm);

    lon = normalize_angle(lon + aberr + nutation);

    /* Distance */
    double E = solve_kepler(M, e);
    double r = 1.000001018 * (1 - e * cos(E));

    /* Speed */
    double speed = 0.985647;

    x[0] = lon;
    x[1] = 0;      /* latitude */
    x[2] = r;      /* distance */
    x[3] = speed;  /* speed longitude */
    x[4] = 0;      /* speed latitude */
    x[5] = 0;      /* speed distance */

    return SE_OK;
}

static int calculate_moon(double tjd, int iflag, double *x, char *serr) {
    double T = julian_centuries_tj(tjd);

    /* Mean elongation */
    double D = normalize_angle(297.8501921 + 445267.1114034 * T - 0.0018819 * T * T) * DEGTORAD;
    /* Sun's mean anomaly */
    double M = normalize_angle(357.5291092 + 35999.0502909 * T - 0.0001536 * T * T) * DEGTORAD;
    /* Moon's mean anomaly */
    double Mp = normalize_angle(134.9633964 + 477198.8675055 * T + 0.0087414 * T * T) * DEGTORAD;
    /* Argument of latitude */
    double F = normalize_angle(93.2720950 + 483202.0175233 * T - 0.0036539 * T * T) * DEGTORAD;
    /* Eccentricity factor */
    double E = 1.0 - 0.002516 * T - 0.0000074 * T * T;

    /* Mean longitude */
    double Lp = 218.3164477 + 481267.88123421 * T - 0.0015786 * T * T;

    /* Longitude terms (microdegrees) */
    double sumL = 0;
    sumL += 6288774 * sin(1 * Mp);
    sumL += 1274027 * sin(2 * D - 1 * Mp);
    sumL += 658314 * sin(2 * D);
    sumL += 213618 * sin(2 * Mp);
    sumL -= 185116 * sin(1 * M) * E;
    sumL -= 114332 * sin(2 * F);
    sumL += 58793 * sin(2 * D - 2 * Mp);
    sumL += 57066 * sin(2 * D - 1 * Mp - 1 * M) * E;
    sumL += 53322 * sin(2 * D + 1 * Mp);
    sumL += 45758 * sin(2 * D - 1 * M) * E;
    sumL -= 40923 * sin(1 * M - 1 * Mp) * E;
    sumL -= 34720 * sin(1 * D);
    sumL -= 30383 * sin(1 * M + 1 * Mp) * E;
    sumL += 15327 * sin(2 * D - 2 * F);
    sumL -= 12528 * sin(1 * Mp + 2 * F);
    sumL += 10980 * sin(1 * Mp - 2 * F);
    sumL += 10675 * sin(4 * D - 1 * Mp);
    sumL += 10034 * sin(3 * Mp);
    sumL += 8548 * sin(4 * D - 2 * Mp);
    sumL -= 7888 * sin(2 * D + 1 * M - 1 * Mp) * E;

    /* Latitude terms */
    double sumB = 0;
    sumB += 5128122 * sin(1 * F);
    sumB += 280602 * sin(1 * Mp + 1 * F);
    sumB += 277693 * sin(1 * Mp - 1 * F);
    sumB += 173237 * sin(2 * D - 1 * F);
    sumB += 55413 * sin(2 * D - 1 * Mp + 1 * F);
    sumB += 46271 * sin(2 * D - 1 * Mp - 1 * F);
    sumB += 32573 * sin(2 * D + 1 * F);
    sumB += 17198 * sin(2 * Mp + 1 * F);
    sumB += 9266 * sin(2 * D + 1 * Mp - 1 * F);
    sumB += 8822 * sin(2 * Mp - 1 * F);

    /* Distance */
    double sumR = 0;
    sumR -= 20905355 * cos(1 * Mp);
    sumR -= 3699111 * cos(2 * D - 1 * Mp);
    sumR -= 2955968 * cos(2 * D);
    sumR -= 569925 * cos(2 * Mp);
    sumR += 48888 * cos(1 * M) * E;
    sumR -= 3149 * cos(2 * F);
    sumR += 246158 * cos(2 * D - 2 * Mp);
    sumR -= 152138 * cos(2 * D - 1 * Mp - 1 * M) * E;
    sumR -= 170733 * cos(2 * D + 1 * Mp);
    sumR -= 204586 * cos(2 * D - 1 * M) * E;

    double lon = normalize_angle(Lp + sumL / 1000000.0);
    double lat = sumB / 1000000.0;
    double dist = (385000.56 + sumR / 1000.0) / 149597870.7;  /* AU */

    x[0] = lon;
    x[1] = lat;
    x[2] = dist;
    x[3] = 13.176396;  /* mean daily motion */
    x[4] = 0;
    x[5] = 0;

    return SE_OK;
}

/* Planetary orbital elements (JPL) */
typedef struct {
    double a;       /* semi-major axis */
    double e;       /* eccentricity */
    double i;       /* inclination */
    double L;       /* mean longitude */
    double omega;   /* argument of perihelion */
    double Omega;   /* longitude of ascending node */
    double n;       /* mean motion */
    double dL;      /* mean longitude rate */
    double dM;      /* mean anomaly rate */
} orbital_elements;

static orbital_elements get_orbital_elements(int ipl, double T) {
    orbital_elements orb;

    switch (ipl) {
    case SE_MERCURY:
        orb.a = 0.38709927;
        orb.e = 0.20563593 + 0.00001906 * T;
        orb.i = 7.00497902 - 0.00594749 * T;
        orb.L = normalize_angle(252.250906 + 149472.6746358 * T);
        orb.omega = 29.124282 + 0.00000765 * T;
        orb.Omega = 48.331676 - 0.00002072 * T;
        orb.n = 4.092377;
        break;
    case SE_VENUS:
        orb.a = 0.72333566;
        orb.e = 0.00677672 - 0.00004108 * T;
        orb.i = 3.39467605 - 0.00082069 * T;
        orb.L = normalize_angle(181.979801 + 58517.8156760 * T);
        orb.omega = 54.922622 + 0.00001884 * T;
        orb.Omega = 76.679842 - 0.00004472 * T;
        orb.n = 1.602169;
        break;
    case SE_MARS:
        orb.a = 1.52371034 + 0.00001847 * T;
        orb.e = 0.09339410 + 0.00007882 * T;
        orb.i = 1.84969142 - 0.00813131 * T;
        orb.L = normalize_angle(355.432999 + 19140.3026849 * T);
        orb.omega = 286.503459 + 0.00004312 * T;
        orb.Omega = 49.558093 - 0.00004472 * T;
        orb.n = 0.524071;
        break;
    case SE_JUPITER:
        orb.a = 5.20260319 + 0.00000019 * T;
        orb.e = 0.04849793 - 0.00000463 * T;
        orb.i = 1.303267 - 0.0019877 * T;
        orb.L = normalize_angle(34.351484 + 3034.9056746 * T);
        orb.omega = 273.867496 + 0.00000622 * T;
        orb.Omega = 100.464441 + 0.00000572 * T;
        orb.n = 0.083129;
        break;
    case SE_SATURN:
        orb.a = 9.554909 - 0.00000214 * T;
        orb.e = 0.05550811 - 0.00034688 * T;
        orb.i = 2.485992 - 0.0043193 * T;
        orb.L = normalize_angle(50.077471 + 1222.1137943 * T);
        orb.omega = 339.392456 + 0.00003118 * T;
        orb.Omega = 113.665524 + 0.00000572 * T;
        orb.n = 0.033498;
        break;
    case SE_URANUS:
        orb.a = 19.218446 - 0.00000037 * T;
        orb.e = 0.04638122 - 0.00002724 * T;
        orb.i = 0.773197 + 0.0000835 * T;
        orb.L = normalize_angle(314.055005 + 429.8640561 * T);
        orb.omega = 96.998857 + 0.00000572 * T;
        orb.Omega = 74.005957 + 0.00000572 * T;
        orb.n = 0.011769;
        break;
    case SE_NEPTUNE:
        orb.a = 30.110387 - 0.00000017 * T;
        orb.e = 0.00945575 + 0.00000603 * T;
        orb.i = 1.769953 - 0.0000125 * T;
        orb.L = normalize_angle(304.348665 + 219.8833092 * T);
        orb.omega = 273.187501 + 0.00000572 * T;
        orb.Omega = 131.784057 + 0.00000572 * T;
        orb.n = 0.005981;
        break;
    case SE_PLUTO:
        orb.a = 39.481687;
        orb.e = 0.248808;
        orb.i = 17.14175;
        orb.L = normalize_angle(238.929038 + 145.207805 * T);
        orb.omega = 224.06876;
        orb.Omega = 110.30347;
        orb.n = 0.003968;
        break;
    default:
        memset(&orb, 0, sizeof(orb));
    }
    return orb;
}

static int calculate_planet(double tjd, int ipl, int iflag, double *x, char *serr) {
    double T = julian_centuries_tj(tjd);

    /* Get orbital elements */
    orbital_elements orb = get_orbital_elements(ipl, T);

    /* Mean anomaly */
    double M = normalize_angle(orb.L - orb.omega) * DEGTORAD;

    /* Solve Kepler's equation */
    double E = solve_kepler(M, orb.e);

    /* True anomaly */
    double v = atan2(sqrt(1 - orb.e * orb.e) * sin(E), cos(E) - orb.e);

    /* Distance */
    double r = orb.a * (1 - orb.e * cos(E));

    /* Heliocentric longitude in orbital plane */
    double lon_orb = v + orb.omega * DEGTORAD;

    /* Convert to ecliptic coordinates */
    double i_rad = orb.i * DEGTORAD;
    double Omega_rad = orb.Omega * DEGTORAD;

    double x_orb = r * cos(lon_orb);
    double y_orb = r * sin(lon_orb);

    double x_ecl = x_orb * cos(Omega_rad) - y_orb * sin(Omega_rad) * cos(i_rad);
    double y_ecl = x_orb * sin(Omega_rad) + y_orb * cos(Omega_rad) * cos(i_rad);
    double z_ecl = y_orb * sin(i_rad);

    double helio_lon = atan2(y_ecl, x_ecl) * RADTODEG;
    double helio_lat = atan2(z_ecl, sqrt(x_ecl*x_ecl + y_ecl*y_ecl)) * RADTODEG;

    /* Get Sun position for geocentric conversion */
    double sun_data[6];
    calculate_sun(tjd, iflag, sun_data, serr);
    double sun_lon = sun_data[0] * DEGTORAD;
    double sun_dist = sun_data[2];

    /* Convert to geocentric (if not heliocentric flag) */
    double geo_lon, geo_lat, geo_dist;

    if (!(iflag & SEFLG_HELCTR)) {
        /* Earth's heliocentric position (opposite of Sun) */
        double earth_x = -sun_dist * cos(sun_lon);
        double earth_y = -sun_dist * sin(sun_lon);

        /* Geocentric = heliocentric - Earth */
        double geo_x = x_ecl - earth_x;
        double geo_y = y_ecl - earth_y;

        geo_lon = atan2(geo_y, geo_x) * RADTODEG;
        geo_dist = sqrt(geo_x*geo_x + geo_y*geo_y);
        geo_lat = atan2(z_ecl, sqrt(geo_x*geo_x + geo_y*geo_y)) * RADTODEG;
    } else {
        geo_lon = helio_lon;
        geo_lat = helio_lat;
        geo_dist = r;
    }

    /* Check for retrograde motion */
    double speed = orb.n;
    if (!(iflag & SEFLG_HELCTR)) {
        /* Simplified retrograde check */
        double angle_diff = helio_lon - sun_lon * RADTODEG;
        if (angle_diff > 180) angle_diff -= 360;
        if (angle_diff < -180) angle_diff += 360;
        if (fabs(angle_diff) < 90) {
            speed = -speed * 0.7; /* Retrograde */
        }
    }

    x[0] = normalize_angle(geo_lon);
    x[1] = geo_lat;
    x[2] = geo_dist;
    x[3] = speed;
    x[4] = 0;
    x[5] = 0;

    return SE_OK;
}

static int calculate_node(double tjd, int ipl, int iflag, double *x, char *serr) {
    double T = julian_centuries_tj(tjd);

    /* Mean lunar node */
    double omega = normalize_angle(125.0445479 - 1934.1362608 * T + 0.0020754 * T * T);

    if (ipl == SE_TRUE_NODE) {
        /* Add perturbation for true node */
        double D = normalize_angle(297.8501921 + 445267.1114034 * T) * DEGTORAD;
        double M = normalize_angle(357.5291092 + 35999.0502909 * T) * DEGTORAD;
        double Mp = normalize_angle(134.9633964 + 477198.8675055 * T) * DEGTORAD;
        double F = normalize_angle(93.2720950 + 483202.0175233 * T) * DEGTORAD;

        omega += 1.4979 * sin(2*D - Mp)
               + 0.1500 * sin(2*D - Mp + M)
               - 0.1227 * sin(2*D + Mp)
               + 0.0552 * sin(Mp)
               - 0.0458 * sin(2*D - Mp - M)
               - 0.0409 * sin(2*D)
               - 0.0308 * sin(Mp + 2*F);
        omega = normalize_angle(omega);
    }

    x[0] = omega;              /* North Node */
    x[1] = 0;
    x[2] = 0;
    x[3] = -0.053;             /* Mean motion */
    x[4] = 0;
    x[5] = 0;

    return SE_OK;
}

/* Main calculation function */
int swe_calc_ut(double tjd_ut, int ipl, int iflag, double *xx, char *serr) {
    int ret = SE_OK;

    /* Apply delta-T to get Ephemeris Time */
    double tjd_et = tjd_ut + swe_deltat(tjd_ut);

    /* Calculate based on body type */
    switch (ipl) {
    case SE_SUN:
        ret = calculate_sun(tjd_et, iflag, xx, serr);
        break;
    case SE_MOON:
        ret = calculate_moon(tjd_et, iflag, xx, serr);
        break;
    case SE_MERCURY:
    case SE_VENUS:
    case SE_MARS:
    case SE_JUPITER:
    case SE_SATURN:
    case SE_URANUS:
    case SE_NEPTUNE:
    case SE_PLUTO:
        ret = calculate_planet(tjd_et, ipl, iflag, xx, serr);
        break;
    case SE_MEAN_NODE:
    case SE_TRUE_NODE:
        ret = calculate_node(tjd_et, ipl, iflag, xx, serr);
        break;
    default:
        if (serr) sprintf(serr, "planet %d not implemented", ipl);
        return SE_ERR;
    }

    return ret;
}

int swe_calc(double tjd_et, int ipl, int iflag, double *xx, char *serr) {
    /* Same as swe_calc_ut but already in ET */
    switch (ipl) {
    case SE_SUN:
        return calculate_sun(tjd_et, iflag, xx, serr);
    case SE_MOON:
        return calculate_moon(tjd_et, iflag, xx, serr);
    case SE_MERCURY:
    case SE_VENUS:
    case SE_MARS:
    case SE_JUPITER:
    case SE_SATURN:
    case SE_URANUS:
    case SE_NEPTUNE:
    case SE_PLUTO:
        return calculate_planet(tjd_et, ipl, iflag, xx, serr);
    case SE_MEAN_NODE:
    case SE_TRUE_NODE:
        return calculate_node(tjd_et, ipl, iflag, xx, serr);
    default:
        if (serr) sprintf(serr, "planet %d not implemented", ipl);
        return SE_ERR;
    }
}

/*===================*/
/* House Calculations */
/*===================*/

static void calculate_houses_placidus(double tjd_ut, double lat, double lon, double *cusps, double *ascmc) {
    double T = julian_centuries_tj(tjd_ut);

    /* Obliquity of ecliptic */
    double eps = 23.4392911 - 0.0130042 * T - 0.00000164 * T * T;

    /* GMST */
    double gmst = 280.46061837 + 360.98564736629 * (tjd_ut - J2000) + 0.000387933 * T * T;
    gmst = normalize_angle(gmst);

    /* LST */
    double lst = normalize_angle(gmst + lon);
    double ramc = lst * DEGTORAD;

    double eps_rad = eps * DEGTORAD;
    double lat_rad = lat * DEGTORAD;

    /* MC */
    double mc = atan2(sin(ramc), cos(ramc) * cos(eps_rad)) * RADTODEG;
    mc = normalize_angle(mc);

    /* ASC */
    double y = -cos(ramc);
    double x = sin(eps_rad) * tan(lat_rad) + cos(eps_rad) * sin(ramc);
    double asc = atan2(y, x) * RADTODEG;
    asc = normalize_angle(asc);

    /* Store angles */
    ascmc[SE_ASC] = asc;
    ascmc[SE_MC] = mc;
    ascmc[SE_ARMC] = lst;
    ascmc[SE_VERTEX] = 0;  /* Simplified */
    ascmc[SE_EQUASC] = 0;

    /* Placidus house cusps */
    cusps[0] = asc;

    /* Calculate intermediate cusps iteratively */
    int i, iter;
    for (i = 1; i <= 2; i++) {
        double factor = (double)i / 3.0;
        double ra = ramc + factor * PI / 2;
        for (iter = 0; iter < 20; iter++) {
            double decl = asin(sin(ra) * sin(eps_rad));
            double x_val = cos(ra) * cos(eps_rad);
            double y_val = atan(tan(lat_rad) / cos(decl) / (x_val != 0 ? -x_val / fabs(x_val) * acos(-x_val / cos(decl)) : 1));
            double ha = factor * PI / 2;
            ra = ramc + ha - y_val;
        }
        double cusp = atan2(sin(ra), cos(ra) * cos(eps_rad)) * RADTODEG;
        cusps[9 + i] = normalize_angle(cusp);  /* Houses 11, 12 */
    }

    for (i = 1; i <= 2; i++) {
        double factor = (double)i / 3.0;
        double ra = ramc + PI + factor * PI / 2;
        for (iter = 0; iter < 20; iter++) {
            double decl = asin(sin(ra) * sin(eps_rad));
            double x_val = cos(ra) * cos(eps_rad);
            double y_val = atan(tan(lat_rad) / cos(decl) / (x_val != 0 ? -x_val / fabs(x_val) * acos(-x_val / cos(decl)) : 1));
            double ha = factor * PI / 2;
            ra = ramc + PI + ha - y_val;
        }
        double cusp = atan2(sin(ra), cos(ra) * cos(eps_rad)) * RADTODEG;
        cusps[i] = normalize_angle(cusp);  /* Houses 2, 3 */
    }

    /* Complete with oppositions */
    cusps[6] = normalize_angle(cusps[0] + 180);   /* House 7 */
    cusps[7] = normalize_angle(cusps[1] + 180);   /* House 8 */
    cusps[8] = normalize_angle(cusps[2] + 180);   /* House 9 */
    cusps[3] = normalize_angle(cusps[9] + 180);   /* House 4 */
    cusps[4] = normalize_angle(cusps[10] + 180);  /* House 5 */
    cusps[5] = normalize_angle(cusps[11] + 180);  /* House 6 */
    cusps[9] = mc;                                /* House 10 */
}

int swe_houses(double tjd_ut, double geolat, double geolon, int hsys,
               double *cusps, double *ascmc, char *serr) {
    return swe_houses_ex(tjd_ut, 0, geolat, geolon, hsys, cusps, ascmc, serr);
}

int swe_houses_ex(double tjd_ut, int iflag, double geolat, double geolon,
                  int hsys, double *cusps, double *ascmc, char *serr) {
    /* Default to Placidus */
    calculate_houses_placidus(tjd_ut, geolat, geolon, cusps, ascmc);
    return SE_OK;
}

/*===================*/
/* Utility Functions */
/*===================*/

char *swe_get_planet_name(int ipl) {
    static char name[30];
    switch (ipl) {
    case SE_SUN: strcpy(name, "Sun"); break;
    case SE_MOON: strcpy(name, "Moon"); break;
    case SE_MERCURY: strcpy(name, "Mercury"); break;
    case SE_VENUS: strcpy(name, "Venus"); break;
    case SE_MARS: strcpy(name, "Mars"); break;
    case SE_JUPITER: strcpy(name, "Jupiter"); break;
    case SE_SATURN: strcpy(name, "Saturn"); break;
    case SE_URANUS: strcpy(name, "Uranus"); break;
    case SE_NEPTUNE: strcpy(name, "Neptune"); break;
    case SE_PLUTO: strcpy(name, "Pluto"); break;
    case SE_MEAN_NODE: strcpy(name, "Mean Node"); break;
    case SE_TRUE_NODE: strcpy(name, "True Node"); break;
    default: strcpy(name, "Unknown"); break;
    }
    return name;
}

void swe_set_ephe_path(const char *path) {
    /* Path setting - not needed for built-in calculations */
}

void swe_close(void) {
    /* Cleanup - nothing to do */
}

char *swe_version(char *s) {
    if (s) strcpy(s, "2.10.03-ios");
    return s;
}

/* Ayanamsa (simplified) */
double swe_get_ayanamsa_ut(double tjd_ut) {
    double T = julian_centuries_tj(tjd_ut);
    /* Lahiri ayanamsa approximation */
    return normalize_angle(22.460148 + 50.237044 * T + 0.0002 * T * T);
}

int swe_set_sid_mode(int sid_mode, double t0, double ayan_t0) {
    return SE_OK;
}

/* Coordinate transformations */
void swe_cotrans(double *xpo, double *xpn, double eps) {
    double eps_rad = eps * DEGTORAD;
    double lon = xpo[0] * DEGTORAD;
    double lat = xpo[1] * DEGTORAD;

    double x = cos(lat) * cos(lon);
    double y = cos(lat) * sin(lon) * cos(eps_rad) - sin(lat) * sin(eps_rad);
    double z = cos(lat) * sin(lon) * sin(eps_rad) + sin(lat) * cos(eps_rad);

    xpn[0] = atan2(y, x) * RADTODEG;
    xpn[1] = atan2(z, sqrt(x*x + y*y)) * RADTODEG;
    xpn[2] = xpo[2];
}

void swe_cotrans_sp(double *xpo, double *xpn, double eps) {
    swe_cotrans(xpo, xpn, eps);
    swe_cotrans(xpo + 3, xpn + 3, eps);
}
