#include "geocoder.h"

#include <QNetworkReply>
#include <QUrl>
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

Geocoder::Geocoder(QObject *parent) : QObject(parent)
{
    connect(&m_ncm, &QNetworkConfigurationManager::onlineStateChanged, this, [this](bool) {
        emit onlineStateChanged(isOnline());
    });
    connect(&m_nam, &QNetworkAccessManager::networkAccessibleChanged, this, [this](QNetworkAccessManager::NetworkAccessibility) {
        emit onlineStateChanged(isOnline());
    });
}

bool Geocoder::isOnline() const
{
    if (m_nam.networkAccessible() == QNetworkAccessManager::NotAccessible) {
        return false;
    }
    return m_ncm.isOnline();
}

void Geocoder::search(const QString &cityName)
{
    if (!isOnline()) {
        emit searchFailed(QStringLiteral("Network access is disabled"));
        return;
    }

    QUrl url("https://geocoding-api.open-meteo.com/v1/search");
    QUrlQuery q;
    q.addQueryItem("name", cityName);
    q.addQueryItem("count", "10");
    q.addQueryItem("language", "en");
    q.addQueryItem("format", "json");
    url.setQuery(q);

    QNetworkReply *reply = m_nam.get(QNetworkRequest(url));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            if (!isOnline() || reply->error() == QNetworkReply::HostNotFoundError ||
                reply->error() == QNetworkReply::ConnectionRefusedError ||
                reply->error() == QNetworkReply::TimeoutError ||
                reply->error() == QNetworkReply::NetworkSessionFailedError ||
                reply->error() == QNetworkReply::UnknownNetworkError) {
                emit searchFailed(QStringLiteral("Network access is disabled"));
            } else {
                emit searchFailed(reply->errorString());
            }
            return;
        }
        const QByteArray data = reply->readAll();
        const QJsonDocument doc = QJsonDocument::fromJson(data);
        if (!doc.isObject()) {
            emit searchFailed("Unexpected response");
            return;
        }
        const QJsonArray arr = doc.object().value("results").toArray();
        QVariantList out;
        for (const QJsonValue &v : arr) {
            const QJsonObject o = v.toObject();
            QVariantMap m;
            m["name"] = o.value("name").toString();
            m["country"] = o.value("country").toString();
            m["countryCode"] = o.value("country_code").toString().toUpper();
            m["admin1"] = o.value("admin1").toString();
            m["latitude"] = o.value("latitude").toDouble();
            m["longitude"] = o.value("longitude").toDouble();
            m["timezone"] = o.value("timezone").toString();
            out.append(m);
        }
        emit resultsReady(out);
    });
}

void Geocoder::reverseSearch(double latitude, double longitude)
{
    if (!isOnline()) {
        emit searchFailed(QStringLiteral("Network access is disabled"));
        return;
    }

    // Step 1: reverse-geocode the tapped point to a place name via
    // Nominatim (OpenStreetMap's free reverse geocoding service) -
    // Open-Meteo itself has no reverse endpoint. Nominatim's usage
    // policy requires a real User-Agent identifying the app (not the
    // default Qt one), and reasonable request rates - fine here since
    // this only fires on a deliberate user tap, not in a loop.
    QUrl url("https://nominatim.openstreetmap.org/reverse");
    QUrlQuery q;
    q.addQueryItem("lat", QString::number(latitude, 'f', 6));
    q.addQueryItem("lon", QString::number(longitude, 'f', 6));
    q.addQueryItem("format", "json");
    q.addQueryItem("addressdetails", "1");
    q.addQueryItem("zoom", "10"); // city-level, not street-level detail
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, QByteArray("harbour-thakir/1.0"));

    QNetworkReply *reply = m_nam.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, latitude, longitude]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            if (!isOnline() || reply->error() == QNetworkReply::HostNotFoundError ||
                reply->error() == QNetworkReply::ConnectionRefusedError ||
                reply->error() == QNetworkReply::TimeoutError ||
                reply->error() == QNetworkReply::NetworkSessionFailedError ||
                reply->error() == QNetworkReply::UnknownNetworkError) {
                emit searchFailed(QStringLiteral("Network access is disabled"));
            } else {
                emit searchFailed(reply->errorString());
            }
            return;
        }
        const QByteArray data = reply->readAll();
        const QJsonDocument doc = QJsonDocument::fromJson(data);
        if (!doc.isObject()) {
            emit searchFailed("Unexpected reverse-geocoding response");
            return;
        }
        const QJsonObject addr = doc.object().value("address").toObject();
        // Nominatim doesn't have one consistent "city" field across all
        // regions - fall back through the common alternatives.
        QString name = addr.value("city").toString();
        if (name.isEmpty()) name = addr.value("town").toString();
        if (name.isEmpty()) name = addr.value("village").toString();
        if (name.isEmpty()) name = addr.value("county").toString();
        if (name.isEmpty()) name = addr.value("state").toString();

        if (name.isEmpty()) {
            emit searchFailed("Could not identify a city at that location");
            return;
        }

        // Step 2: re-run it through the normal forward search, which
        // does give us a timezone (and a consistent result shape QML
        // already knows how to handle identically to a text search).
        // Note: this loses the exact tapped coordinates in favour of
        // Open-Meteo's own coordinates for the matched city name - fine
        // for picking "which city", since prayer times are computed for
        // the city's coordinates either way, not the literal tap point.
        Q_UNUSED(latitude)
        Q_UNUSED(longitude)
        search(name);
    });
}
