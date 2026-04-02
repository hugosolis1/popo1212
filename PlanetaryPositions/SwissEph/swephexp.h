/*******************************************************
swephexp.h
Swiss Ephemeris Export Header
Public API definitions for Swiss Ephemeris

This is a simplified version for iOS integration
********************************************************/

#ifndef _SWEPHEXP_H
#define _SWEPHEXP_H

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Ephemeris constants */
#define SE_SUN          0
#define SE_MOON         1
#define SE_MERCURY      2
#define SE_VENUS        3
#define SE_MARS         4
#define SE_JUPITER      5
#define SE_SATURN       6
#define SE_URANUS       7
#define SE_NEPTUNE      8
#define SE_PLUTO        9
#define SE_MEAN_NODE    10     /* Mean North Node */
#define SE_TRUE_NODE    11     /* True North Node */
#define SE_MEAN_APOG    12     /* Mean Apogee */
#define SE_OSCU_APOG    13     /* Osculating Apogee */
#define SE_EARTH        14
#define SE_CHIRON       15

/* Flag bits for calculation */
#define SEFLG_JPLEPH    0      /* use JPL ephemeris */
#define SEFLG_SWIEPH    1      /* use SWISSEPH ephemeris */
#define SEFLG_MOSEPH    2      /* use Moshier ephemeris */
#define SEFLG_HELCTR    8      /* heliocentric position */
#define SEFLG_TRUEPOS   16     /* true position (no aberration) */
#define SEFLG_J2000     32     /* J2000 coordinates */
#define SEFLG_NONUT     64     /* no nutation */
#define SEFLG_SPEED3    128    /* speed from 3 positions */
#define SEFLG_SPEED     256    /* high precision speed */
#define SEFLG_NOGDEFL   512    /* no gravitational deflection */
#define SEFLG_NOABERR   1024   /* no aberration */
#define SEFLG_ASTROMETRIC (SEFLG_NOABERR|SEFLG_NOGDEFL)
#define SEFLG_EQUATORIAL 2048  /* equatorial coordinates */
#define SEFLG_XYZ       4096   /* cartesian coordinates */
#define SEFLG_RADIANS   8192   /* output in radians */
#define SEFLG_BARYCTR   16384  /* barycentric position */
#define SEFLG_TOPOCTR   32768  /* topocentric position */
#define SEFLG_SIDEREAL  65536  /* sidereal position */
#define SEFLG_ICRS      131072 /* ICRS coordinates */

/* House systems */
#define SE_ASC          0
#define SE_MC           1
#define SE_ARMC         2
#define SE_VERTEX       3
#define SE_EQUASC       4      /* equatorial ascendant */
#define SE_COASC1       5      /* co-ascendant (Walter Koch) */
#define SE_COASC2       6      /* co-ascendant (Michael Munkasey) */
#define SE_POLASC       7      /* polar ascendant */

#define SE_HSYS_PLACIDUS    'P'
#define SE_HSYS_KOCH        'K'
#define SE_HSYS_PORPHYRIUS  'O'
#define SE_HSYS_REGIOMONTANUS 'R'
#define SE_HSYS_CAMPANUS    'C'
#define SE_HSYS_EQUAL       'E'
#define SE_HSYS_WHOLE_SIGN  'W'
#define SE_HSYS_VEHLOW      'V'

/* Error codes */
#define SE_OK               0
#define SE_ERR              -1
#define SE_ERR_EPHFILE      -2
#define SE_ERR_NORESULT     -3

/* Planet structure */
typedef struct {
    double longitude;       /* ecliptic longitude in degrees */
    double latitude;        /* ecliptic latitude in degrees */
    double distance;        /* distance in AU */
    double speed_long;      /* speed in longitude (deg/day) */
    double speed_lat;       /* speed in latitude */
    double speed_dist;      /* speed in distance */
} t_planet_data;

/* Calendar functions */
double swe_julday(int year, int month, int day, double hour, int gregflag);
void swe_revjul(double jd, int gregflag, int *year, int *month, int *day, double *hour);
double swe_julday_utc(int year, int month, int day, double hour, int gregflag);

/* Main calculation functions */
int swe_calc_ut(double tjd_ut, int ipl, int iflag, double *xx, char *serr);
int swe_calc(double tjd_et, int ipl, int iflag, double *xx, char *serr);

/* House calculation */
int swe_houses_ex(double tjd_ut, int iflag, double geolat, double geolon,
                  int hsys, double *cusps, double *ascmc, char *serr);
int swe_houses(double tjd_ut, double geolat, double geolon, int hsys,
               double *cusps, double *ascmc, char *serr);

/* Sidereal modes */
int swe_set_sid_mode(int sid_mode, double t0, double ayan_t0);
double swe_get_ayanamsa(double tjd_et);
double swe_get_ayanamsa_ut(double tjd_ut);
int swe_get_ayanamsa_ex(double tjd_et, int iflag, double *daya, char *serr);
int swe_get_ayanamsa_ex_ut(double tjd_ut, int iflag, double *daya, char *serr);

/* Ephemeris path */
void swe_set_ephe_path(const char *path);
void swe_close(void);

/* Delta T */
double swe_deltat(double tjd);
double swe_deltat_ex(double tjd, int ephe_flag, char *serr);

/* Eclipse functions */
int swe_sol_eclipse_where(double tjd_start, int iflag, double *geopos,
                          double *attr, char *serr);
int swe_lun_eclipse_where(double tjd_start, int iflag, double *geopos,
                          double *attr, char *serr);
int swe_lun_eclipse_how(double tjd_start, int iflag, double *geopos,
                        double *attr, char *serr);

/* Rising/setting */
int swe_rise_trans(double tjd_ut, int ipl, char *starname, int epheflag,
                   int rsmi, double *geopos, double atpress, double attemp,
                   double *tret, char *serr);

/* Coordinate transformations */
void swe_cotrans(double *xpo, double *xpn, double eps);
void swe_cotrans_sp(double *xpo, double *xpn, double eps);

/* Utility functions */
char *swe_get_planet_name(int ipl);
char *swe_get_planet_name_ext(int ipl, char *s);
char *swe_version(char *s);
char *swe_get_library_path(char *s);

/* Constants */
#define SE_GREG_CAL  1
#define SE_JUL_CAL   0

#define PI 3.14159265358979323846
#define DEGTORAD 0.017453292519943295769
#define RADTODEG 57.2957795130823208767

#endif /* _SWEPHEXP_H */
