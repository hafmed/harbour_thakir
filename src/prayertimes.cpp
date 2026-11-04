#include "prayertimes.h"
#include <cmath>
#include <algorithm>

PrayerTimes::PrayerTimes()
{
}

void PrayerTimes::setMethod(Method m) { m_method = m; }
void PrayerTimes::setMadhab(Madhab m) { m_madhab = m; }
void PrayerTimes::setHighLatitudeRule(HighLatitudeRule rule) { m_highLatitudeRule = rule; }

double PrayerTimes::nightPortion(double angle, double nightDuration, HighLatitudeRule rule)
{
    double portion = 0.5;
    switch (rule) {
    case HL_None:
        return 0.0;
    case HL_AngleBased:
        portion = angle / 60.0;
        break;
    case HL_MiddleOfNight:
        portion = 0.5;
        break;
    case HL_OneSeventh:
        portion = 1.0 / 7.0;
        break;
    }
    return portion * nightDuration;
}

void PrayerTimes::setLocation(double latitude, double longitude, double elevation)
{
    m_lat = latitude;
    m_lon = longitude;
    m_elevation = elevation;
}

void PrayerTimes::setTimezone(double tzOffsetHours)
{
    m_tz = tzOffsetHours;
}

void PrayerTimes::setPrayerOffset(int prayerIndex, int minutes)
{
    if (prayerIndex >= 0 && prayerIndex < 6) {
        m_offsets[prayerIndex] = minutes;
    }
}

int PrayerTimes::prayerOffset(int prayerIndex) const
{
    if (prayerIndex >= 0 && prayerIndex < 6) {
        return m_offsets[prayerIndex];
    }
    return 0;
}

double PrayerTimes::dtr(double d) const { return d * M_PI / 180.0; }
double PrayerTimes::rtd(double r) const { return r * 180.0 / M_PI; }

double PrayerTimes::fixHour(double a) const
{
    a = a - 24.0 * std::floor(a / 24.0);
    if (a < 0) a += 24.0;
    return a;
}

double PrayerTimes::fixAngle(double a) const
{
    a = a - 360.0 * std::floor(a / 360.0);
    if (a < 0) a += 360.0;
    return a;
}

double PrayerTimes::julianDate(int year, int month, int day) const
{
    if (month <= 2) {
        year -= 1;
        month += 12;
    }
    double A = std::floor(year / 100.0);
    double B = 2 - A + std::floor(A / 4.0);
    double JD = std::floor(365.25 * (year + 4716)) +
                std::floor(30.6001 * (month + 1)) +
                day + B - 1524.5;
    return JD;
}

void PrayerTimes::sunPosition(double jd, double &declination, double &eqOfTime) const
{
    double D = jd - 2451545.0;
    double g = fixAngle(357.529 + 0.98560028 * D);
    double q = fixAngle(280.459 + 0.98564736 * D);
    double L = fixAngle(q + 1.915 * std::sin(dtr(g)) + 0.020 * std::sin(dtr(2 * g)));

    double e = 23.439 - 0.00000036 * D;

    double RA = rtd(std::atan2(std::cos(dtr(e)) * std::sin(dtr(L)), std::cos(dtr(L)))) / 15.0;
    RA = fixHour(RA);

    eqOfTime = q / 15.0 - RA;
    declination = rtd(std::asin(std::sin(dtr(e)) * std::sin(dtr(L))));
}

double PrayerTimes::midDay(double jDate, double time) const
{
    double decl, eqt;
    sunPosition(jDate + time, decl, eqt);
    return fixHour(12.0 - eqt);
}

// direction: +1 = afternoon side (sunset/maghrib/isha), -1 = morning side (fajr/sunrise)
bool PrayerTimes::sunAngleTime(double angle, double jDate, double time, int direction, double &resultTime) const
{
    double decl, eqt;
    sunPosition(jDate + time, decl, eqt);
    double noonT = midDay(jDate, time);

    double num = -std::sin(dtr(angle)) - std::sin(dtr(m_lat)) * std::sin(dtr(decl));
    double den = std::cos(dtr(m_lat)) * std::cos(dtr(decl));
    double ratio = num / den;

    bool valid = (ratio >= -1.0 && ratio <= 1.0);
    if (ratio > 1.0) ratio = 1.0;
    if (ratio < -1.0) ratio = -1.0;

    double t = (1.0 / 15.0) * rtd(std::acos(ratio));
    resultTime = noonT + (direction < 0 ? -t : t);
    return valid;
}

double PrayerTimes::sunAngleTime(double angle, double jDate, double time, int direction) const
{
    double t = 0.0;
    sunAngleTime(angle, jDate, time, direction, t);
    return t;
}

double PrayerTimes::asrTime(int shadowFactor, double jDate, double time) const
{
    double decl, eqt;
    sunPosition(jDate + time, decl, eqt);
    double angle = -rtd(std::atan(1.0 / (shadowFactor + std::tan(dtr(std::fabs(m_lat - decl))))));
    return sunAngleTime(angle, jDate, time, +1);
}

double PrayerTimes::angleForMethodFajr() const
{
    switch (m_method) {
    case MWL: return 18.0;
    case ISNA: return 15.0;
    case Egyptian: return 19.5;
    case Makkah: return 18.5;
    case Karachi: return 18.0;
    case Tehran: return 17.7;
    case HighLatitude: return 15.0;
    case Morocco: return 19.0;
    case FixedIsha: return 19.5;
    case EgyptianNew: return 19.5;
    case UmmAlQuraRamadan: return 18.5;
    case MoonsightingCommittee: return 18.0;
    case FranceUOIF: return 12.0;
    case MalaysiaJAKIM: return 20.0;
    case TurkeyFazilet: return 19.0;
    case TurkeyTPRA: return 18.0;
    case TurkeyDiyanet: return 18.3;
    case EnglandBirmingham: return 5.0;
    case JordanMAIAHPJ: return 18.0;
    case AlgeriaMARWDZ: return 18.0;
    case TunisiaMAIAMTU: return 18.0;
    case OmanMARAOM: return 18.5;
    case KuwaitMARAKU: return 18.0;
    case LibyaMARALI: return 18.5;
    case QatarTAQWMQAT: return 18.5;
    }
    return 18.0;
}

double PrayerTimes::angleForMethodIsha() const
{
    switch (m_method) {
    case MWL: return 17.0;
    case ISNA: return 15.0;
    case Egyptian: return 17.5;
    case Makkah: return 0.0; // handled as minutes-after-maghrib instead
    case Karachi: return 18.0;
    case Tehran: return 14.0;
    case HighLatitude: return 15.0;
    case Morocco: return 17.0;
    case FixedIsha: return 0.0; // 90 min interval
    case EgyptianNew: return 17.5;
    case UmmAlQuraRamadan: return 0.0; // 120 min interval
    case MoonsightingCommittee: return 18.0;
    case FranceUOIF: return 12.0;
    case MalaysiaJAKIM: return 18.0;
    case TurkeyFazilet: return 17.0;
    case TurkeyTPRA: return 17.0;
    case TurkeyDiyanet: return 17.4;
    case EnglandBirmingham: return 0.84;
    case JordanMAIAHPJ: return 17.0;
    case AlgeriaMARWDZ: return 17.0;
    case TunisiaMAIAMTU: return 17.0;
    case OmanMARAOM: return 17.0;
    case KuwaitMARAKU: return 17.5;
    case LibyaMARALI: return 18.0;
    case QatarTAQWMQAT: return 0.0; // 90 min interval
    }
    return 17.0;
}

bool PrayerTimes::ishaIsMinutesAfterMaghrib() const
{
    return m_method == Makkah || m_method == FixedIsha
        || m_method == UmmAlQuraRamadan || m_method == QatarTAQWMQAT;
}

double PrayerTimes::ishaMinutesAfterMaghrib(const QDate &date) const
{
    if (m_method == UmmAlQuraRamadan)
        return 120.0;
    if (m_method == FixedIsha || m_method == QatarTAQWMQAT)
        return 90.0;
    // Umm al-Qura's own published rule: 120 minutes after Maghrib during
    // Ramadan, 90 minutes the rest of the year.
    return isRamadan(date) ? 120.0 : 90.0;
}

int PrayerTimes::methodOffsetMinutes(int prayerIndex) const
{
    switch (m_method) {
    case Morocco:
    case FranceUOIF:
        if (prayerIndex == 2) return 5; // Dhuhr +5
        if (prayerIndex == 4) return 5; // Maghrib +5
        break;
    case MoonsightingCommittee:
        if (prayerIndex == 2) return 5; // Dhuhr +5
        if (prayerIndex == 4) return 3; // Maghrib +3
        break;
    case TurkeyFazilet:
        if (prayerIndex == 2) return 10; // Dhuhr +10
        if (prayerIndex == 3) return 10; // Asr +10
        if (prayerIndex == 4) return 7;  // Maghrib +7
        break;
    case TurkeyTPRA:
        if (prayerIndex == 2) return 8;  // Dhuhr +8
        if (prayerIndex == 3) return 5;  // Asr +5
        if (prayerIndex == 4) return 10; // Maghrib +10
        break;
    case TurkeyDiyanet:
        if (prayerIndex == 1) return -5; // Sunrise -5
        if (prayerIndex == 2) return 8;  // Dhuhr +8
        if (prayerIndex == 3) return 5;  // Asr +5
        if (prayerIndex == 4) return 7;  // Maghrib +7
        break;
    case JordanMAIAHPJ:
        if (prayerIndex == 4) return 6;  // Maghrib +6
        break;
    case AlgeriaMARWDZ:
    case OmanMARAOM:
        if (prayerIndex == 4) return 5;  // Maghrib +5
        break;
    case TunisiaMAIAMTU:
    case LibyaMARALI:
        if (prayerIndex == 4) return 3;  // Maghrib +3
        break;
    default:
        break;
    }
    return 0;
}

PrayerTimes::HijriDate PrayerTimes::gregorianToHijri(const QDate &gregorianDate)
{
    // Standard tabular/civil Gregorian -> Hijri conversion via Julian
    // Day Number, using the widely-published arithmetic formula (see
    // e.g. Reingold & Dershowitz, "Calendrical Calculations"). This is
    // a fixed arithmetic approximation of the Islamic calendar, not
    // true moon-sighting - typically accurate to within a day of the
    // locally-observed calendar, which is what almost all prayer-time
    // software uses in practice since true sighting dates vary by
    // locale and can't be computed with certainty in advance.
    HijriDate result;
    if (!gregorianDate.isValid())
        return result;

    int y = gregorianDate.year();
    int m = gregorianDate.month();
    int d = gregorianDate.day();

    // Julian Day Number (integer, civil-calendar convention) for this
    // Gregorian date.
    int a = (14 - m) / 12;
    int yy = y + 4800 - a;
    int mm = m + 12 * a - 3;
    long jdn = d + (153 * mm + 2) / 5 + 365L * yy + yy / 4 - yy / 100 + yy / 400 - 32045;

    long l = jdn - 1948440 + 10632;
    long n = (l - 1) / 10631;
    l = l - 10631 * n + 354;
    long j = ((10985 - l) / 5316) * ((50 * l) / 17719)
           + (l / 5670) * ((43 * l) / 15238);
    l = l - ((30 - j) / 15) * ((17719 * j) / 50)
          - (j / 16) * ((15238 * j) / 43) + 29;

    result.month = static_cast<int>((24 * l) / 709);
    result.day = static_cast<int>(l - (709L * result.month) / 24);
    result.year = static_cast<int>(30 * n + j - 30);
    result.valid = true;
    return result;
}

bool PrayerTimes::isRamadan(const QDate &gregorianDate, int adjustmentDays)
{
    QDate adjustedDate = (adjustmentDays != 0) ? gregorianDate.addDays(adjustmentDays) : gregorianDate;
    return gregorianToHijri(adjustedDate).month == 9;
}

QString PrayerTimes::hijriDateString(const QDate &gregorianDate, int adjustmentDays)
{
    QDate adjustedDate = (adjustmentDays != 0) ? gregorianDate.addDays(adjustmentDays) : gregorianDate;
    HijriDate h = gregorianToHijri(adjustedDate);
    if (!h.valid || h.month < 1 || h.month > 12)
        return QString();

    static const char *monthNames[12] = {
        "Muharram", "Safar", "Rabi al-Awwal", "Rabi al-Thani",
        "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Shaban",
        "Ramadan", "Shawwal", "Dhu al-Qidah", "Dhu al-Hijjah"
    };
    return QString("%1 %2 %3").arg(h.day)
            .arg(monthNames[h.month - 1]).arg(h.year);
}

PrayerTimes::Times PrayerTimes::computeForDate(const QDate &date) const
{
    Times result;
    if (!date.isValid())
        return result;

    double jDate = julianDate(date.year(), date.month(), date.day()) - m_lon / (15.0 * 24.0);

    double dhuhrT = midDay(jDate, 12.0 / 24.0);
    double sunriseT = 0.0, sunsetT = 0.0;
    sunAngleTime(0.833, jDate, dhuhrT / 24.0, -1, sunriseT);
    sunAngleTime(0.833, jDate, dhuhrT / 24.0, +1, sunsetT);
    double maghribT = sunsetT;

    double fajrT = 0.0;
    bool hasFajr = sunAngleTime(angleForMethodFajr(), jDate, dhuhrT / 24.0, -1, fajrT);

    double ishaT = 0.0;
    bool hasIsha = true;
    if (ishaIsMinutesAfterMaghrib()) {
        ishaT = maghribT + ishaMinutesAfterMaghrib(date) / 60.0;
    } else {
        hasIsha = sunAngleTime(angleForMethodIsha(), jDate, dhuhrT / 24.0, +1, ishaT);
    }

    // High Latitude Adjustment for extreme northern/southern regions
    HighLatitudeRule hlRule = m_highLatitudeRule;
    if (m_method == HighLatitude && hlRule == HL_None) {
        hlRule = HL_AngleBased;
    }

    if (hlRule != HL_None) {
        double nightDuration = fixHour(sunriseT - sunsetT);
        if (nightDuration <= 0.0 || nightDuration >= 24.0) {
            nightDuration = 24.0;
        }

        double fajrPortion = nightPortion(angleForMethodFajr(), nightDuration, hlRule);
        double fajrDiff = fixHour(sunriseT - fajrT);
        if (!hasFajr || fajrDiff > fajrPortion) {
            fajrT = sunriseT - fajrPortion;
        }

        if (!ishaIsMinutesAfterMaghrib()) {
            double ishaPortion = nightPortion(angleForMethodIsha(), nightDuration, hlRule);
            double ishaDiff = fixHour(ishaT - sunsetT);
            if (!hasIsha || ishaDiff > ishaPortion) {
                ishaT = sunsetT + ishaPortion;
            }
        }
    }

    int shadowFactor = (m_madhab == Hanafi) ? 2 : 1;
    double asrT = asrTime(shadowFactor, jDate, dhuhrT / 24.0);

    // Convert from "hours since Greenwich apparent solar day" to local
    // clock time using timezone and longitude correction.
    double tzAdjust = m_tz - m_lon / 15.0;

    result.fajr = fixHour(fajrT + tzAdjust + (methodOffsetMinutes(0) + m_offsets[0]) / 60.0);
    result.sunrise = fixHour(sunriseT + tzAdjust + (methodOffsetMinutes(1) + m_offsets[1]) / 60.0);
    result.dhuhr = fixHour(dhuhrT + tzAdjust + (methodOffsetMinutes(2) + m_offsets[2]) / 60.0);
    result.asr = fixHour(asrT + tzAdjust + (methodOffsetMinutes(3) + m_offsets[3]) / 60.0);
    result.maghrib = fixHour(maghribT + tzAdjust + (methodOffsetMinutes(4) + m_offsets[4]) / 60.0);
    result.isha = fixHour(ishaT + tzAdjust + (methodOffsetMinutes(5) + m_offsets[5]) / 60.0);
    result.valid = true;
    return result;
}

QString PrayerTimes::formatTime(double hours)
{
    int h = static_cast<int>(std::floor(hours));
    int m = static_cast<int>(std::round((hours - h) * 60.0));
    if (m == 60) { m = 0; h += 1; }
    h = ((h % 24) + 24) % 24;
    return QString("%1:%2").arg(h, 2, 10, QChar('0')).arg(m, 2, 10, QChar('0'));
}

double PrayerTimes::computeQiblaBearing(double lat, double lon)
{
    double phi1 = lat * M_PI / 180.0;
    double lambda1 = lon * M_PI / 180.0;
    double phi2 = KAABA_LAT * M_PI / 180.0;
    double lambda2 = KAABA_LON * M_PI / 180.0;

    double deltaLambda = lambda2 - lambda1;

    double y = std::sin(deltaLambda) * std::cos(phi2);
    double x = std::cos(phi1) * std::sin(phi2) - std::sin(phi1) * std::cos(phi2) * std::cos(deltaLambda);

    double bearingRad = std::atan2(y, x);
    double bearingDeg = bearingRad * 180.0 / M_PI;

    return std::fmod(bearingDeg + 360.0, 360.0);
}

double PrayerTimes::computeQiblaDistanceKm(double lat, double lon)
{
    const double R = 6371.0;
    double phi1 = lat * M_PI / 180.0;
    double phi2 = KAABA_LAT * M_PI / 180.0;
    double deltaPhi = (KAABA_LAT - lat) * M_PI / 180.0;
    double deltaLambda = (KAABA_LON - lon) * M_PI / 180.0;

    double a = std::sin(deltaPhi / 2.0) * std::sin(deltaPhi / 2.0) +
               std::cos(phi1) * std::cos(phi2) *
               std::sin(deltaLambda / 2.0) * std::sin(deltaLambda / 2.0);
    double c = 2.0 * std::atan2(std::sqrt(a), std::sqrt(1.0 - a));

    return R * c;
}

QString PrayerTimes::compassDirectionName(double bearingDegrees)
{
    static const char *directions[] = {
        "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
        "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"
    };
    int index = static_cast<int>(std::floor((std::fmod(bearingDegrees + 11.25, 360.0)) / 22.5));
    if (index < 0 || index >= 16) index = 0;
    return QString::fromLatin1(directions[index]);
}

namespace {
inline double degToRad(double deg) {
    return deg * M_PI / 180.0;
}

inline double radToDeg(double rad) {
    return rad * 180.0 / M_PI;
}

inline double normalizeDegrees(double deg) {
    deg = std::fmod(deg, 360.0);
    if (deg < 0.0) deg += 360.0;
    return deg;
}

inline double calculateJD(const QDateTime &dt) {
    QDateTime utc = dt.isValid() ? dt.toUTC() : QDateTime::currentDateTimeUtc();
    QDate d = utc.date();
    QTime t = utc.time();

    int year = d.year();
    int month = d.month();
    int day = d.day();

    if (month <= 2) {
        year -= 1;
        month += 12;
    }

    double a = std::floor(year / 100.0);
    double b = 2.0 - a + std::floor(a / 4.0);
    double jd = std::floor(365.25 * (year + 4716)) +
                std::floor(30.6001 * (month + 1)) +
                day + b - 1524.5;

    double dayFraction = (t.hour() + t.minute() / 60.0 + t.second() / 3600.0 + t.msec() / 3600000.0) / 24.0;
    return jd + dayFraction;
}
}

PrayerTimes::CelestialPosition PrayerTimes::computeSunPosition(double lat, double lon, const QDateTime &utcDt)
{
    CelestialPosition pos;
    double jd = calculateJD(utcDt);
    double d = jd - 2451545.0; // Days since J2000.0

    // Mean anomaly and mean longitude of Sun
    double g = normalizeDegrees(357.529 + 0.98560028 * d);
    double q = normalizeDegrees(280.459 + 0.98564736 * d);

    // Ecliptic longitude of Sun
    double lambda = normalizeDegrees(q + 1.915 * std::sin(degToRad(g)) + 0.020 * std::sin(degToRad(2.0 * g)));

    // Obliquity of ecliptic
    double e = 23.439 - 0.00000036 * d;

    // Right ascension (in degrees)
    double raRad = std::atan2(std::cos(degToRad(e)) * std::sin(degToRad(lambda)), std::cos(degToRad(lambda)));
    double raDeg = normalizeDegrees(radToDeg(raRad));

    // Declination
    double sinDec = std::sin(degToRad(e)) * std::sin(degToRad(lambda));
    sinDec = std::max(-1.0, std::min(1.0, sinDec));
    double decRad = std::asin(sinDec);

    // Greenwich Mean Sidereal Time (GMST) and Local Sidereal Time (LST)
    double gmst = normalizeDegrees(280.46061837 + 360.98564736629 * d);
    double lst = normalizeDegrees(gmst + lon);

    // Hour Angle (degrees)
    double hDeg = normalizeDegrees(lst - raDeg);
    double hRad = degToRad(hDeg);
    double phiRad = degToRad(lat);

    // Topocentric Altitude
    double sinAlt = std::sin(phiRad) * std::sin(decRad) + std::cos(phiRad) * std::cos(decRad) * std::cos(hRad);
    sinAlt = std::max(-1.0, std::min(1.0, sinAlt));
    double altRad = std::asin(sinAlt);
    pos.altitude = radToDeg(altRad);

    // Azimuth from North (clockwise)
    double y = -std::sin(hRad) * std::cos(decRad);
    double x = std::sin(decRad) * std::cos(phiRad) - std::cos(decRad) * std::sin(phiRad) * std::cos(hRad);
    pos.azimuth = normalizeDegrees(radToDeg(std::atan2(y, x)));

    // Standard atmospheric refraction + solar semi-diameter puts sunrise/sunset at -0.833°
    pos.isVisible = (pos.altitude > -0.833);
    return pos;
}

PrayerTimes::CelestialPosition PrayerTimes::computeMoonPosition(double lat, double lon, const QDateTime &utcDt)
{
    CelestialPosition pos;
    double jd = calculateJD(utcDt);
    double d = jd - 2451545.0; // Days since J2000.0

    // Moon orbital elements (Meeus low-precision method)
    double lPrime = normalizeDegrees(218.316 + 13.176396 * d);
    double mPrime = normalizeDegrees(134.963 + 13.064993 * d);
    double f = normalizeDegrees(93.272 + 13.229350 * d);
    double m = normalizeDegrees(357.529 + 0.985600 * d);
    double dElong = normalizeDegrees(297.850 + 12.190749 * d);

    // Ecliptic longitude of Moon (lambda_m)
    double lambdaM = lPrime
        + 6.289 * std::sin(degToRad(mPrime))
        - 1.274 * std::sin(degToRad(mPrime - 2.0 * dElong))
        + 0.658 * std::sin(degToRad(2.0 * dElong))
        - 0.214 * std::sin(degToRad(2.0 * mPrime))
        - 0.186 * std::sin(degToRad(m))
        - 0.114 * std::sin(degToRad(2.0 * f));
    lambdaM = normalizeDegrees(lambdaM);

    // Ecliptic latitude of Moon (beta_m)
    double betaM = 5.128 * std::sin(degToRad(f))
        + 0.2806 * std::sin(degToRad(mPrime + f))
        + 0.2777 * std::sin(degToRad(mPrime - f))
        + 0.1732 * std::sin(degToRad(2.0 * dElong - f));

    // Obliquity of ecliptic
    double e = 23.439 - 0.00000036 * d;

    // Convert (lambdaM, betaM) to Equatorial coordinates (Right Ascension & Declination)
    double sinDec = std::sin(degToRad(betaM)) * std::cos(degToRad(e)) +
                    std::cos(degToRad(betaM)) * std::sin(degToRad(e)) * std::sin(degToRad(lambdaM));
    sinDec = std::max(-1.0, std::min(1.0, sinDec));
    double decRad = std::asin(sinDec);

    double yEq = std::cos(degToRad(betaM)) * std::cos(degToRad(e)) * std::sin(degToRad(lambdaM)) -
                 std::sin(degToRad(betaM)) * std::sin(degToRad(e));
    double xEq = std::cos(degToRad(betaM)) * std::cos(degToRad(lambdaM));
    double raDeg = normalizeDegrees(radToDeg(std::atan2(yEq, xEq)));

    // Greenwich Mean Sidereal Time (GMST) and Local Sidereal Time (LST)
    double gmst = normalizeDegrees(280.46061837 + 360.98564736629 * d);
    double lst = normalizeDegrees(gmst + lon);

    // Hour Angle (degrees)
    double hDeg = normalizeDegrees(lst - raDeg);
    double hRad = degToRad(hDeg);
    double phiRad = degToRad(lat);

    // Geocentric Altitude
    double sinAlt = std::sin(phiRad) * std::sin(decRad) + std::cos(phiRad) * std::cos(decRad) * std::cos(hRad);
    sinAlt = std::max(-1.0, std::min(1.0, sinAlt));
    double altGeoDeg = radToDeg(std::asin(sinAlt));

    // Topocentric Parallax Correction (Moon is close to Earth; horizontal parallax ~0.9507°)
    double parallax = 0.9507 * std::cos(degToRad(std::max(0.0, altGeoDeg)));
    pos.altitude = altGeoDeg - parallax;

    // Azimuth from North (clockwise)
    double y = -std::sin(hRad) * std::cos(decRad);
    double x = std::sin(decRad) * std::cos(phiRad) - std::cos(decRad) * std::sin(phiRad) * std::cos(hRad);
    pos.azimuth = normalizeDegrees(radToDeg(std::atan2(y, x)));

    // Moon is visible when above horizon (alt > 0°)
    pos.isVisible = (pos.altitude > 0.0);

    // Sun ecliptic longitude for phase angle calculation
    double gSun = normalizeDegrees(357.529 + 0.98560028 * d);
    double qSun = normalizeDegrees(280.459 + 0.98564736 * d);
    double lambdaSun = normalizeDegrees(qSun + 1.915 * std::sin(degToRad(gSun)) + 0.020 * std::sin(degToRad(2.0 * gSun)));

    // Phase elongation (difference between Moon and Sun ecliptic longitudes)
    double phaseAngle = normalizeDegrees(lambdaM - lambdaSun);
    pos.phase = phaseAngle / 360.0; // 0.0 .. 1.0
    pos.illumination = (1.0 - std::cos(degToRad(phaseAngle))) / 2.0; // 0.0 .. 1.0

    if (pos.phase < 0.03 || pos.phase >= 0.97) {
        pos.phaseName = QStringLiteral("New Moon");
    } else if (pos.phase < 0.22) {
        pos.phaseName = QStringLiteral("Waxing Crescent");
    } else if (pos.phase < 0.28) {
        pos.phaseName = QStringLiteral("First Quarter");
    } else if (pos.phase < 0.47) {
        pos.phaseName = QStringLiteral("Waxing Gibbous");
    } else if (pos.phase < 0.53) {
        pos.phaseName = QStringLiteral("Full Moon");
    } else if (pos.phase < 0.72) {
        pos.phaseName = QStringLiteral("Waning Gibbous");
    } else if (pos.phase < 0.78) {
        pos.phaseName = QStringLiteral("Last Quarter");
    } else {
        pos.phaseName = QStringLiteral("Waning Crescent");
    }

    return pos;
}

