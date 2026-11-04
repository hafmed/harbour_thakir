#ifndef PRAYERTIMES_H
#define PRAYERTIMES_H

#include <QDate>
#include <QDateTime>
#include <QMap>
#include <QString>

// A self-contained port of the standard published "sun-angle" method used
// almost universally for Islamic prayer time calculation (the same family
// of formulas used by praytimes.org, Aladhan, IslamicFinder, etc). All the
// astronomical formulas here (solar position, equation of time, hour
// angle) are standard low-precision solar-position equations - they are
// mathematics, not anyone's copyrighted text, and this implementation is
// written from scratch.

class PrayerTimes
{
public:
    enum Method {
        MWL = 0,          // Muslim World League: Fajr 18, Isha 17
        ISNA,             // Islamic Society of North America: Fajr 15, Isha 15
        Egyptian,         // Egyptian General Authority: Fajr 19.5, Isha 17.5
        Makkah,           // Umm al-Qura: Fajr 18.5, Isha 90 min after Maghrib
        Karachi,          // University of Islamic Sciences, Karachi: Fajr 18, Isha 18
        Tehran,           // Institute of Geophysics, Tehran: Fajr 17.7, Isha 14
        HighLatitude,     // Prayer Times for High Latitudes: Fajr 15, Isha 15 (with Angle-Based rule)
        Morocco,          // Ministry of Habous & Islamic Affairs, Morocco: Fajr 19, Isha 17, Dhuhr +5, Maghrib +5
        FixedIsha,        // Fixed Isha Angle Interval: Fajr 19.5, Isha 90 min
        EgyptianNew,      // Egyptian General Authority of Survey NEW: Fajr 19.5, Isha 17.5
        UmmAlQuraRamadan, // Umm Al-Qura University, RAMADAN: Fajr 18.5, Isha 120 min
        MoonsightingCommittee, // Moonsighting Committee Worldwide: Fajr 18, Isha 18, Dhuhr +5, Maghrib +3
        FranceUOIF,       // France UOIF: Fajr 12, Isha 12, Dhuhr +5, Maghrib +5
        MalaysiaJAKIM,    // Malaysia JAKIM: Fajr 20, Isha 18
        TurkeyFazilet,    // Turkey Fazilet: Fajr 19, Isha 17, Dhuhr +10, Asr +10, Maghrib +7
        TurkeyTPRA,       // Turkey TPRA: Fajr 18, Isha 17, Dhuhr +8, Asr +5, Maghrib +10
        TurkeyDiyanet,    // Turkey Diyanet: Fajr 18.3, Isha 17.4, Sunrise -5, Dhuhr +8, Asr +5, Maghrib +7
        EnglandBirmingham,// England Birmingham: Fajr 5, Isha 0.84
        JordanMAIAHPJ,    // Jordan MAIAHPJ: Fajr 18, Isha 17, Maghrib +6
        AlgeriaMARWDZ,    // Algeria MARWDZ: Fajr 18, Isha 17, Maghrib +5
        TunisiaMAIAMTU,   // Tunisia MAIAMTU: Fajr 18, Isha 17, Maghrib +3
        OmanMARAOM,       // Oman MARAOM: Fajr 18.5, Isha 17, Maghrib +5
        KuwaitMARAKU,     // Kuwait MARAKU: Fajr 18, Isha 17.5
        LibyaMARALI,      // Libya MARALI: Fajr 18.5, Isha 18, Maghrib +3
        QatarTAQWMQAT     // Qatar TAQWMQAT: Fajr 18.5, Isha 90 min
    };

    enum HighLatitudeRule {
        HL_None = 0,          // No adjustment
        HL_AngleBased = 1,     // Angle-based / Proportional (angle / 60 of night)
        HL_MiddleOfNight = 2,  // Middle of the night (1/2 of night)
        HL_OneSeventh = 3      // One-seventh of the night (1/7 of night)
    };

    enum Madhab {
        Shafi = 0,    // Asr shadow factor 1 (also Maliki/Hanbali)
        Hanafi = 1    // Asr shadow factor 2
    };

    struct Times {
        double fajr = 0;
        double sunrise = 0;
        double dhuhr = 0;
        double asr = 0;
        double maghrib = 0;
        double isha = 0;
        bool valid = false;
    };

    PrayerTimes();

    void setMethod(Method m);
    void setMadhab(Madhab m);
    void setHighLatitudeRule(HighLatitudeRule rule);
    HighLatitudeRule highLatitudeRule() const { return m_highLatitudeRule; }

    static double nightPortion(double angle, double nightDuration, HighLatitudeRule rule);

    void setLocation(double latitude, double longitude, double elevation = 0.0);
    // timezone offset in hours from UTC (e.g. +1.0), including DST if applicable
    void setTimezone(double tzOffsetHours);
    void setPrayerOffset(int prayerIndex, int minutes);
    int prayerOffset(int prayerIndex) const;

    // Compute times (returned as fractional hours, local time, 0-24) for
    // the given Gregorian calendar date.
    Times computeForDate(const QDate &date) const;

    static QString formatTime(double hours);

    // Kaaba coordinates (Makkah)
    static constexpr double KAABA_LAT = 21.422487;
    static constexpr double KAABA_LON = 39.826206;

    // Computes the Qibla bearing in degrees (0..360, clockwise from True North) from a given coordinate
    static double computeQiblaBearing(double lat, double lon);

    // Computes the great-circle distance in kilometers to the Kaaba
    static double computeQiblaDistanceKm(double lat, double lon);

    // Returns the 16-point cardinal compass direction abbreviation (e.g. "N", "NE", "ESE", "S", etc.)
    static QString compassDirectionName(double bearingDegrees);

    // Gregorian -> Hijri (tabular/civil Islamic calendar - a fixed
    // arithmetic approximation, not true moon-sighting; this is the
    // same practical approach used by most prayer-time software, since
    // sighting-based dates vary by locale and can't be computed with
    // certainty in advance). Returns e.g. "15 Ramadan 1447".
    // Supports optional day adjustment (e.g. -3 to +3).
    static QString hijriDateString(const QDate &gregorianDate, int adjustmentDays = 0);
    static bool isRamadan(const QDate &gregorianDate, int adjustmentDays = 0);

    struct CelestialPosition {
        double azimuth = 0.0;   // 0..360 degrees from True North
        double altitude = 0.0;  // -90..+90 degrees relative to horizon
        bool isVisible = false; // true if above horizon
        double phase = 0.0;     // 0.0..1.0 (0=New, 0.25=First Quarter, 0.5=Full, 0.75=Last Quarter)
        double illumination = 0.0; // 0.0..1.0 (illuminated fraction)
        QString phaseName;      // e.g. "Waxing Crescent", "Full Moon"
    };

    struct HijriDate {
        int year = 0;
        int month = 0; // 1-12
        int day = 0;
        bool valid = false;
    };
    static HijriDate gregorianToHijri(const QDate &gregorianDate);

    // Computes current Sun position (azimuth & altitude) for a given observer location
    static CelestialPosition computeSunPosition(double lat, double lon, const QDateTime &utcDt = QDateTime());

    // Computes current Moon position (azimuth & altitude) for a given observer location
    static CelestialPosition computeMoonPosition(double lat, double lon, const QDateTime &utcDt = QDateTime());

private:

    double dtr(double d) const;
    double rtd(double r) const;
    double fixHour(double a) const;
    double fixAngle(double a) const;

    double julianDate(int year, int month, int day) const;
    void sunPosition(double jd, double &declination, double &eqOfTime) const;
    double midDay(double jDate, double time) const;
    bool sunAngleTime(double angle, double jDate, double time, int direction, double &resultTime) const;
    double sunAngleTime(double angle, double jDate, double time, int direction) const;
    double asrTime(int shadowFactor, double jDate, double time) const;

    double angleForMethodFajr() const;
    double angleForMethodIsha() const;
    bool ishaIsMinutesAfterMaghrib() const;
    double ishaMinutesAfterMaghrib(const QDate &date) const;
    int methodOffsetMinutes(int prayerIndex) const;

    Method m_method = MWL;
    Madhab m_madhab = Shafi;
    HighLatitudeRule m_highLatitudeRule = HL_AngleBased;
    double m_lat = 0.0;
    double m_lon = 0.0;
    double m_elevation = 0.0;
    double m_tz = 0.0;
    int m_offsets[6] = {0, 0, 0, 0, 0, 0};
};

#endif // PRAYERTIMES_H
