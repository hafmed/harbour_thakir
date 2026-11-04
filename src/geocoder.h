#ifndef GEOCODER_H
#define GEOCODER_H

#include <QObject>
#include <QVariantList>
#include <QNetworkAccessManager>
#include <QNetworkConfigurationManager>

// Resolves a free-text city name to candidate locations (name, country,
// country code, latitude, longitude, timezone) using the free
// Open-Meteo Geocoding API, which covers cities worldwide and needs no
// API key. https://geocoding-api.open-meteo.com
//
// Also supports the reverse direction (coordinates -> place name) via
// OpenStreetMap's free Nominatim service, for the map-based city picker
// - Open-Meteo itself is forward-only (name search), so reverseSearch()
// resolves a tapped map point to a name via Nominatim, then internally
// re-runs it through the normal forward search() to get a matching
// entry with a timezone attached (Nominatim doesn't provide timezone).
class Geocoder : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isOnline READ isOnline NOTIFY onlineStateChanged)
public:
    explicit Geocoder(QObject *parent = nullptr);

    Q_INVOKABLE bool isOnline() const;
    Q_INVOKABLE void search(const QString &cityName);

    // Resolves a tapped map coordinate to the same kind of result
    // list search() produces (so QML can treat them identically) -
    // emits resultsReady()/searchFailed() the same way.
    Q_INVOKABLE void reverseSearch(double latitude, double longitude);

signals:
    void resultsReady(const QVariantList &results);
    void searchFailed(const QString &error);
    void onlineStateChanged(bool isOnline);

private:
    QNetworkAccessManager m_nam;
    QNetworkConfigurationManager m_ncm;
};

#endif // GEOCODER_H
