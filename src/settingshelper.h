#ifndef SETTINGSHELPER_H
#define SETTINGSHELPER_H

#include <QSettings>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QVariant>
#include <QDebug>

class SettingsHelper
{
public:
    static QString settingsFilePath()
    {
        // Under Sailjail sandboxing with:
        //   OrganizationName=org.hafsoftdz
        //   ApplicationName=harbour-thakir
        // Sailjail explicitly whitelists:
        //   $HOME/.config/org.hafsoftdz/harbour-thakir/
        //
        // Bare QSettings instances target $HOME/.config/org.hafsoftdz/harbour-thakir.conf,
        // which sits outside the whitelisted subdirectory and is blocked by Sailjail.
        // QStandardPaths::AppConfigLocation returns the whitelisted directory.
        QString dir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
        if (dir.isEmpty()) {
            dir = QDir::homePath() + QStringLiteral("/.config/org.hafsoftdz/harbour-thakir");
        }
        QDir().mkpath(dir);

        QString targetFile = dir + QStringLiteral("/harbour-thakir.conf");

        // Migrate settings from legacy / unsandboxed paths if new file does not exist yet
        if (!QFile::exists(targetFile)) {
            QString home = QDir::homePath();
            QString legacy1 = home + QStringLiteral("/.config/harbour-thakir/harbour-thakir.conf");
            QString legacy2 = home + QStringLiteral("/.config/org.hafsoftdz/harbour-thakir.conf");

            if (QFile::exists(legacy1)) {
                qDebug() << "SettingsHelper: Migrating settings from legacy path:" << legacy1 << "to" << targetFile;
                QFile::copy(legacy1, targetFile);
            } else if (QFile::exists(legacy2)) {
                qDebug() << "SettingsHelper: Migrating settings from legacy path:" << legacy2 << "to" << targetFile;
                QFile::copy(legacy2, targetFile);
            }
        }

        return targetFile;
    }

    static void setValue(const QString &key, const QVariant &val)
    {
        QSettings s(settingsFilePath(), QSettings::IniFormat);
        s.setValue(key, val);
    }

    static QVariant value(const QString &key, const QVariant &defaultValue = QVariant())
    {
        QSettings s(settingsFilePath(), QSettings::IniFormat);
        return s.value(key, defaultValue);
    }

    static bool contains(const QString &key)
    {
        QSettings s(settingsFilePath(), QSettings::IniFormat);
        return s.contains(key);
    }

    static void ensureSanity(QSettings &s)
    {
        Q_UNUSED(s);
    }
};

#endif // SETTINGSHELPER_H
