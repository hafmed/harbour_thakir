#include "quranmanager.h"
#include "settingshelper.h"
#include "powerbuttonwatcher.h"

#include <algorithm>
#include <cmath>
#include <QtMath>
#include <QCoreApplication>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>
#include <QRegularExpression>
#include <QSslConfiguration>
#include <QSslError>
#include <QSvgRenderer>
#include <QPainter>
#include <QSet>
#include <QPointer>
#include <QRunnable>
#include <QThreadPool>
#include <sailfishapp.h>

static QString cleanUthmaniText(const QString &text, int riwayah = 0);

class PreloadNextAyahRunnable : public QRunnable
{
public:
    PreloadNextAyahRunnable(QuranManager *mgr, int page, int surah, int ayah, int rId, bool dark, bool tajweed = false)
        : m_mgr(mgr), m_page(page), m_surah(surah), m_ayah(ayah), m_rId(rId), m_dark(dark), m_tajweed(tajweed)
    {
        setAutoDelete(true);
    }

    void run() override
    {
        if (m_mgr) {
            m_mgr->renderPageImage(m_page, m_surah, m_ayah, m_dark, m_rId, m_tajweed);
        }
    }

private:
    QPointer<QuranManager> m_mgr;
    int m_page;
    int m_surah;
    int m_ayah;
    int m_rId;
    bool m_dark;
    bool m_tajweed;
};

QuranManager::QuranManager(QObject *parent)
    : QObject(parent)
    , m_riwayah(1)
    , m_fontSize(32)
    , m_tafsirFontSize(24)
    , m_viewMode(0) // Default to Text View
    , m_darkMode(false)
    , m_tajweedMode(false)
    , m_tajweedHdMode(false)
    , m_screenBlankingDisabled(true)
    , m_readerActive(false)
    , m_isPreventingBlanking(false)
    , m_blankingTimer(nullptr)
    , m_lastSurah(1)
    , m_lastAyah(1)
    , m_lastPage(1)
    , m_player(nullptr)
    , m_playingSurah(0)
    , m_playingAyah(0)
    , m_maxAyahInPlayingSurah(7)
    , m_audioProgress(0.0)
    , m_currentDuration(0)
    , m_currentAudioFileIndex(0)
    , m_pendingSeekMs(0)
    , m_netManager(new QNetworkAccessManager(this))
    , m_isDownloadingPages(false)
    , m_bulkPagesRiwayah(1)
    , m_bulkPagesTotalInBatch(0)
    , m_bulkPagesDownloadedInBatch(0)
    , m_bulkPagesActiveCount(0)
    , m_isDownloadingTajweedPages(false)
    , m_bulkTajweedPagesRiwayah(2)
    , m_bulkTajweedPagesHd(false)
    , m_bulkTajweedPagesTotalInBatch(0)
    , m_bulkTajweedPagesDownloadedInBatch(0)
    , m_bulkTajweedPagesActiveCount(0)
    , m_algeriaMode(false)
    , m_isDownloadingAlgeriaPages(false)
    , m_bulkAlgeriaPagesTotalInBatch(0)
    , m_bulkAlgeriaPagesDownloadedInBatch(0)
    , m_bulkAlgeriaPagesActiveCount(0)
    , m_isDownloadingAudio(false)
    , m_audioTotalInBatch(0)
    , m_audioDownloadedInBatch(0)
    , m_activeAudioReply(nullptr)
    , m_memCachedPageNumber(-1)
    , m_memCachedRiwayah(-1)
{
    m_pageImageCache.setMaxCost(30);
    m_netManager->setNetworkAccessible(QNetworkAccessManager::Accessible);

    connect(&m_ncm, &QNetworkConfigurationManager::onlineStateChanged, this, [this](bool) {
        emit onlineStateChanged(isOnline());
    });
    connect(m_netManager, &QNetworkAccessManager::networkAccessibleChanged, this, [this](QNetworkAccessManager::NetworkAccessibility) {
        emit onlineStateChanged(isOnline());
    });

    // Load persisted settings
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    m_fontSize = s.value(QStringLiteral("quran/fontSize"), 32).toInt();
    m_tafsirFontSize = s.value(QStringLiteral("quran/tafsirFontSize"), 24).toInt();
    m_viewMode = s.value(QStringLiteral("quran/viewMode"), 0).toInt();
    m_darkMode = s.value(QStringLiteral("quran/darkMode"), false).toBool();
    m_tajweedMode = s.value(QStringLiteral("quran/tajweedMode"), false).toBool();
    m_tajweedHdMode = s.value(QStringLiteral("quran/tajweedHdMode"), false).toBool();
    m_algeriaMode = s.value(QStringLiteral("quran/algeriaMode"), false).toBool();
    m_screenBlankingDisabled = s.value(QStringLiteral("quran/screenBlankingDisabled"), true).toBool();
    m_lastSurah = s.value(QStringLiteral("quran/lastSurah"), 1).toInt();
    m_lastAyah = s.value(QStringLiteral("quran/lastAyah"), 1).toInt();
    m_lastPage = s.value(QStringLiteral("quran/lastPage"), 1).toInt();
    m_selectedTafsirEditionId = s.value(QStringLiteral("quran/tafsirEdition"), QStringLiteral("ar.muyassar")).toString();

    // Default Riwayah: check if previously chosen by user
    if (s.contains(QStringLiteral("quran/riwayah"))) {
        m_riwayah = s.value(QStringLiteral("quran/riwayah"), 1).toInt();
    } else {
        // Auto-detect: if country is Algeria / Maghreb, default to Warsh (2)!
        QString country = s.value(QStringLiteral("city/country")).toString().toLower();
        QString tz = s.value(QStringLiteral("city/tz")).toString().toLower();
        if (country.contains(QStringLiteral("algeria")) || country.contains(QString::fromUtf8("الجزائر"))
            || country.contains(QStringLiteral("morocco")) || country.contains(QString::fromUtf8("المغرب"))
            || country.contains(QStringLiteral("tunisia")) || country.contains(QString::fromUtf8("تونس"))
            || country.contains(QStringLiteral("mauritania")) || country.contains(QString::fromUtf8("موريتانيا"))
            || tz.contains(QStringLiteral("algiers")) || tz.contains(QStringLiteral("casablanca"))
            || tz.contains(QStringLiteral("tunis"))) {
            m_riwayah = 2; // Warsh 'an Nafi'
        } else {
            m_riwayah = 1; // Hafs 'an 'Asim
        }
    }

    m_selectedReciterId = s.value(QStringLiteral("quran/reciterId")).toString();

    if (!s.contains(QStringLiteral("quran/favoriteReciters"))) {
        m_favoriteReciters = QStringList()
            << QStringLiteral("alafasy")
            << QStringLiteral("minshawi")
            << QStringLiteral("husary")
            << QStringLiteral("abdulbasit")
            << QStringLiteral("yassin_al_jazaery")
            << QStringLiteral("abdulbasit_warsh");
        s.setValue(QStringLiteral("quran/favoriteReciters"), m_favoriteReciters);
    } else {
        m_favoriteReciters = s.value(QStringLiteral("quran/favoriteReciters")).toStringList();
    }

    initDatabase();
    initAudio();
}

QuranManager::~QuranManager()
{
    if (m_isPreventingBlanking) {
        if (m_blankingTimer) {
            m_blankingTimer->stop();
        }
        PowerButtonWatcher::cancelBlankingPause();
    }
    cancelBulkTajweedPagesDownload();
    cancelBulkAlgeriaPagesDownload();
    if (m_db.isOpen()) {
        m_db.close();
    }
}

QString QuranManager::findDatabasePath() const
{
    // 1. SailfishApp path
    QString p1 = SailfishApp::pathTo("data/quran.db").toLocalFile();
    if (QFile::exists(p1)) return p1;

    // 2. Installed path
    QString p2 = QStringLiteral("/usr/share/harbour-thakir/data/quran.db");
    if (QFile::exists(p2)) return p2;

    // 3. Local relative path (development)
    QString p3 = QDir::current().filePath("data/quran.db");
    if (QFile::exists(p3)) return p3;

    // 4. App directory relative
    QString p4 = QCoreApplication::applicationDirPath() + QStringLiteral("/../data/quran.db");
    if (QFile::exists(p4)) return p4;

    return p1;
}

void QuranManager::initDatabase()
{
    QString dbFile = findDatabasePath();
    qDebug() << "QuranManager: Loading database from:" << dbFile;

    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("quran_connection"));
    m_db.setDatabaseName(dbFile);

    if (!m_db.open()) {
        qWarning() << "QuranManager: Failed to open SQLite database:" << m_db.lastError().text();
    } else {
        qDebug() << "QuranManager: Database successfully opened.";
        loadWarshToHafsMap();
        initAlgeriaPageMaps();
        int exactPage = getPageForAyah(m_lastSurah, m_lastAyah, m_riwayah);
        if (exactPage > 0) {
            m_lastPage = exactPage;
        }
    }

    // Ensure default reciter is set if empty
    if (m_selectedReciterId.isEmpty()) {
        QVariantList reciters = getAvailableReciters();
        if (!reciters.isEmpty()) {
            m_selectedReciterId = reciters.first().toMap().value(QStringLiteral("id")).toString();
        }
    }
}

int QuranManager::mapHafsToWarsh(int surah, int hafsAyah) const
{
    if (m_riwayah != 2) return hafsAyah;
    quint32 hKey = (static_cast<quint32>(surah) << 16) | static_cast<quint32>(hafsAyah);
    return m_hafsToWarshMap.value(hKey, static_cast<quint16>(hafsAyah));
}

void QuranManager::loadWarshToHafsMap()
{
    m_warshToHafsMap.clear();
    m_hafsToWarshMap.clear();
    m_warshPageMap.clear();
    if (!m_db.isOpen()) return;

    // Ensure start_ms and end_ms columns exist in warsh_to_hafs_map table
    bool hasOffsetCols = false;
    QSqlQuery checkQ(QStringLiteral("PRAGMA table_info(warsh_to_hafs_map)"), m_db);
    while (checkQ.next()) {
        if (checkQ.value(1).toString() == QStringLiteral("start_ms")) {
            hasOffsetCols = true;
            break;
        }
    }
    if (!hasOffsetCols) {
        m_db.exec(QStringLiteral("ALTER TABLE warsh_to_hafs_map ADD COLUMN start_ms INTEGER DEFAULT 0"));
        m_db.exec(QStringLiteral("ALTER TABLE warsh_to_hafs_map ADD COLUMN end_ms INTEGER DEFAULT 0"));
    }

    QSqlQuery q(QStringLiteral("SELECT surah_number, warsh_ayah, hafs_ayah_start, hafs_ayah_end, start_ms, end_ms FROM warsh_to_hafs_map"), m_db);
    if (!q.isActive()) {
        q = QSqlQuery(QStringLiteral("SELECT surah_number, warsh_ayah, hafs_ayah_start, hafs_ayah_end, 0, 0 FROM warsh_to_hafs_map"), m_db);
    }
    while (q.next()) {
        int surah = q.value(0).toInt();
        int wAyah = q.value(1).toInt();
        int hStart = q.value(2).toInt();
        int hEnd = q.value(3).toInt();
        HafsRange r;
        r.start = hStart;
        r.end = hEnd;
        r.startMs = q.value(4).toInt();
        r.endMs = q.value(5).toInt();
        quint32 key = (static_cast<quint32>(surah) << 16) | static_cast<quint32>(wAyah);
        m_warshToHafsMap.insert(key, r);

        for (int h = hStart; h <= hEnd; ++h) {
            quint32 hKey = (static_cast<quint32>(surah) << 16) | static_cast<quint32>(h);
            m_hafsToWarshMap.insert(hKey, static_cast<quint16>(wAyah));
        }
    }

    QSqlQuery qP(QStringLiteral("SELECT surah_number, ayah_number, page_number FROM ayahs WHERE riwayah_id = 2"), m_db);
    while (qP.next()) {
        quint32 key = (static_cast<quint32>(qP.value(0).toInt()) << 16) | static_cast<quint32>(qP.value(1).toInt());
        m_warshPageMap.insert(key, static_cast<quint16>(qP.value(2).toInt()));
    }

    qDebug() << "[QuranManager] Loaded" << m_warshToHafsMap.size() << "Warsh-to-Hafs mappings and" << m_warshPageMap.size() << "Warsh pages.";
}

static int calculateBaseWeight(const QString &txt);

void QuranManager::initAlgeriaPageMaps()
{
    m_algeriaAyahPageMap.clear();
    m_algeriaPageAyahsMap.clear();
    if (!m_db.isOpen()) return;

    for (int p = 1; p <= 706; ++p) {
        m_algeriaPageAyahsMap.insert(p, QVariantList());
    }

    // 1. First attempt: load verified coordinates directly from algeria_ayah_lines database
    QSqlQuery dbQ(QStringLiteral(
        "SELECT l.page_number, l.surah_number, l.ayah_number, l.start_line, l.end_line, "
        "a.text_uthmani, a.juz_number, a.hizb_number, a.rub_number, a.sajda, s.name_ar, s.name_en, a.text_tajweed "
        "FROM algeria_ayah_lines l "
        "JOIN ayahs a ON l.surah_number = a.surah_number AND l.ayah_number = a.ayah_number AND a.riwayah_id = 2 "
        "JOIN surahs s ON l.surah_number = s.number "
        "ORDER BY l.page_number ASC, l.start_line ASC"
    ), m_db);

    if (dbQ.exec() && dbQ.next()) {
        do {
            int p = dbQ.value(0).toInt();
            int s = dbQ.value(1).toInt();
            int ay = dbQ.value(2).toInt();
            double sL = dbQ.value(3).toDouble();
            double eL = dbQ.value(4).toDouble();

            QVariantMap item;
            item[QStringLiteral("surah_number")] = s;
            item[QStringLiteral("ayah_number")] = ay;
            item[QStringLiteral("page_number")] = p;
            item[QStringLiteral("start_line")] = sL;
            item[QStringLiteral("end_line")] = eL;
            item[QStringLiteral("text_uthmani")] = cleanUthmaniText(dbQ.value(5).toString(), 2);
            item[QStringLiteral("juz_number")] = dbQ.value(6).toInt();
            item[QStringLiteral("hizb_number")] = dbQ.value(7).toInt();
            item[QStringLiteral("rub_number")] = dbQ.value(8).toInt();
            item[QStringLiteral("sajda")] = dbQ.value(9).toInt() == 1;
            item[QStringLiteral("surah_name_ar")] = dbQ.value(10).toString();
            item[QStringLiteral("surah_name_en")] = dbQ.value(11).toString();
            item[QStringLiteral("text_tajweed")] = dbQ.value(12).toString();
            item[QStringLiteral("isBookmarked")] = isBookmarked(s, ay);

            m_algeriaPageAyahsMap[p].append(item);

            quint32 key = (static_cast<quint32>(s) << 16) | static_cast<quint32>(ay);
            if (!m_algeriaAyahPageMap.contains(key)) {
                m_algeriaAyahPageMap.insert(key, static_cast<quint16>(p));
            }
        } while (dbQ.next());

        qDebug() << "[QuranManager] Loaded" << m_algeriaAyahPageMap.size() << "Algerian Warsh ayah page mappings from verified database across 706 pages.";
        return;
    }

    struct AyahBrief {
        int surah;
        int ayah;
        int page604;
        double textWeight;
        double markerWeight;
        double totalWeight;
        QVariantMap data;
    };

    QVector<AyahBrief> allAyahs;
    allAyahs.reserve(6220);

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT a.surah_number, a.ayah_number, a.text_uthmani, a.juz_number, a.hizb_number, a.rub_number, a.sajda, s.name_ar, s.name_en, a.text_tajweed, a.page_number "
                             "FROM ayahs a JOIN surahs s ON a.surah_number = s.number "
                             "WHERE a.riwayah_id = 2 ORDER BY a.surah_number ASC, a.ayah_number ASC"));
    if (q.exec()) {
        while (q.next()) {
            AyahBrief ab;
            ab.surah = q.value(0).toInt();
            ab.ayah = q.value(1).toInt();
            QString txt = q.value(2).toString();
            ab.page604 = q.value(10).toInt();
            ab.textWeight = calculateBaseWeight(txt);
            ab.markerWeight = 5.5;
            ab.totalWeight = ab.textWeight + ab.markerWeight;

            ab.data[QStringLiteral("surah_number")] = ab.surah;
            ab.data[QStringLiteral("ayah_number")] = ab.ayah;
            ab.data[QStringLiteral("text_uthmani")] = cleanUthmaniText(txt, 2);
            ab.data[QStringLiteral("juz_number")] = q.value(3).toInt();
            ab.data[QStringLiteral("hizb_number")] = q.value(4).toInt();
            ab.data[QStringLiteral("rub_number")] = q.value(5).toInt();
            ab.data[QStringLiteral("sajda")] = q.value(6).toInt() == 1;
            ab.data[QStringLiteral("surah_name_ar")] = q.value(7).toString();
            ab.data[QStringLiteral("surah_name_en")] = q.value(8).toString();
            ab.data[QStringLiteral("text_tajweed")] = q.value(9).toString();
            ab.data[QStringLiteral("isBookmarked")] = isBookmarked(ab.surah, ab.ayah);
            allAyahs.append(ab);
        }
    }

    if (allAyahs.isEmpty()) return;

    // 1. Pages 1 and 2 (special 8-line ornate layout)
    double p1TotalWeight = 0.0;
    for (int i = 0; i < allAyahs.size(); ++i) {
        if (allAyahs[i].surah == 1) p1TotalWeight += allAyahs[i].totalWeight;
    }
    if (p1TotalWeight <= 0.0) p1TotalWeight = 1.0;
    double p1Cur = 0.0;
    for (int i = 0; i < allAyahs.size(); ++i) {
        if (allAyahs[i].surah == 1) {
            double textSpan = (allAyahs[i].textWeight / p1TotalWeight) * 8.0;
            double totalSpan = (allAyahs[i].totalWeight / p1TotalWeight) * 8.0;
            QVariantMap item = allAyahs[i].data;
            item[QStringLiteral("page_number")] = 1;
            item[QStringLiteral("start_line")] = p1Cur;
            item[QStringLiteral("end_line")] = p1Cur + textSpan;
            m_algeriaPageAyahsMap[1].append(item);
            quint32 key = (1 << 16) | allAyahs[i].ayah;
            m_algeriaAyahPageMap.insert(key, 1);
            p1Cur += totalSpan;
        }
    }

    double p2TotalWeight = 0.0;
    for (int i = 0; i < allAyahs.size(); ++i) {
        if (allAyahs[i].surah == 2 && allAyahs[i].ayah <= 4) p2TotalWeight += allAyahs[i].totalWeight;
    }
    if (p2TotalWeight <= 0.0) p2TotalWeight = 1.0;
    double p2Cur = 2.0; // Header banner and Basmalah occupy top 2 lines
    for (int i = 0; i < allAyahs.size(); ++i) {
        if (allAyahs[i].surah == 2 && allAyahs[i].ayah <= 4) {
            double textSpan = (allAyahs[i].textWeight / p2TotalWeight) * 6.0;
            double totalSpan = (allAyahs[i].totalWeight / p2TotalWeight) * 6.0;
            QVariantMap item = allAyahs[i].data;
            item[QStringLiteral("page_number")] = 2;
            item[QStringLiteral("start_line")] = p2Cur;
            item[QStringLiteral("end_line")] = p2Cur + textSpan;
            m_algeriaPageAyahsMap[2].append(item);
            quint32 key = (2 << 16) | allAyahs[i].ayah;
            m_algeriaAyahPageMap.insert(key, 2);
            p2Cur += totalSpan;
        }
    }

    // 2. Pages 3 through 706 (704 pages x 13 lines = 9152 continuous lines)
    struct PieceAnchor {
        int surah;
        int ayah;
        double line; // continuous line coordinate in [0.0, 9152.0]
    };

    static const PieceAnchor s_pieceAnchors[] = {
        { 2,   5,      0.0 }, // Page 2/3+
        { 2,  17,     16.2 }, // Page 2/3+
        { 2,  33,     56.0 }, // Page 2/3+
        { 2,  75,    138.0 }, // Page 2/3+
        { 2,  83,    154.0 }, // Page 2/3+
        { 2, 142,    297.0 }, // Page 2/3+
        { 2, 143,    300.0 }, // Page 2/3+
        { 2, 203,    448.0 }, // Page 2/3+
        { 2, 213,    467.0 }, // Page 2/3+
        { 2, 253,    596.0 }, // Page 2/3+
        { 2, 255,    599.0 }, // Page 2/3+
        {   3,   1,    702.1 }, // Page  57, line  0.1 (Surah 3: آل عمران)
        {   3,  15,    819.0 },
        {   3,  93,    949.0 },
        {   4,   1,   1087.2 }, // Page  86, line  8.2 (Surah 4: النساء)
        {   4,  24,   1222.0 },
        {   4,  88,   1365.0 },
        {   5,   1,   1508.0 }, // Page 119, line  0.0 (Surah 5: المائدة)
        {   5,  25,   1588.0 },
        {   5,  29,   1596.0 },
        {   5,  42,   1625.0 },
        {   5,  44,   1637.0 },
        {   5,  49,   1657.0 },
        {   5,  51,   1661.5 },
        {   5,  53,   1664.0 },
        {   5,  59,   1677.0 },
        {   5,  60,   1679.0 },
        {   5,  61,   1680.3 },
        {   5,  62,   1682.5 },
        {   5,  63,   1685.2 },
        {   5,  64,   1687.2 },
        {   5,  65,   1689.0 },
        {   5,  66,   1690.0 },
        {   5,  67,   1696.0 },
        {   5,  68,   1697.2 },
        {   5,  69,   1700.3 },
        {   5,  70,   1703.0 },
        {   5,  71,   1706.7 },
        {   5,  72,   1709.0 },
        {   6,   1,   1828.2 }, // Page 143, line  8.2 (Surah 6: الأنعام)
        {   6,  36,   1924.0 },
        {   6, 111,   2041.0 },
        {   7,   1,   2158.8 }, // Page 169, line  0.8 (Surah 7: الأعراف)
        {   7,  80,   2327.0 },
        {   7,  86,   2339.0 },
        {   7,  93,   2340.0 },
        {   7,  99,   2350.0 },
        {   8,   1,   2565.2 }, // Page 200, line  4.2 (Surah 8: الأنفال)
        {   8,  60,   2678.0 },
        {   9,   1,   2710.2 }, // Page 211, line  6.2 (Surah 9: التوبة)
        {   9,  34,   2795.0 },
        {   9,  84,   2899.0 },
        {   9,  85,   2900.0 },
        {   9,  86,   2902.0 },
        {   9,  87,   2904.5 },
        {   9,  88,   2907.0 },
        {   9,  89,   2908.2 },
        {   9,  90,   2910.0 },
        {   9,  91,   2911.3 },
        {   9,  92,   2912.0 },
        {  10,   1,   3003.1 }, // Page 234, line  0.1 (Surah 10: يونس)
        {  10,   5,   3016.0 },
        {  10,  10,   3025.5 },
        {  10,  12,   3029.0 },
        {  11,   1,   3207.2 }, // Page 249, line  9.2 (Surah 11: هود)
        {  11,   6,   3217.0 },
        {  12,   1,   3422.1 }, // Page 266, line  3.1 (Surah 12: يوسف)
        {  13,   1,   3620.2 }, // Page 281, line  6.2 (Surah 13: الرعد)
        {  14,   1,   3718.0 }, // Page 289, line  0.0 (Surah 14: ابراهيم)
        {  15,   1,   3814.1 }, // Page 296, line  5.1 (Surah 15: الحجر)
        {  16,   1,   3895.2 }, // Page 302, line  8.2 (Surah 16: النحل)
        {  16,  51,   3991.0 },
        {  17,   1,   4102.2 }, // Page 318, line  7.2 (Surah 17: الإسراء)
        {  18,   1,   4284.2 }, // Page 332, line  7.2 (Surah 18: الكهف)
        {  19,   1,   4473.3 }, // Page 347, line  1.3 (Surah 19: مريم)
        {  20,   1,   4597.2 }, // Page 356, line  8.2 (Surah 20: طه)
        {  21,   1,   4752.2 }, // Page 368, line  7.2 (Surah 21: الأنبياء)
        {  22,   1,   4893.2 }, // Page 379, line  5.2 (Surah 22: الحج)
        {  23,   1,   5037.2 }, // Page 390, line  6.2 (Surah 23: المؤمنون)
        {  24,   1,   5161.1 }, // Page 400, line  0.1 (Surah 24: النور)
        {  25,   1,   5311.2 }, // Page 411, line  7.2 (Surah 25: الفرقان)
        {  26,   1,   5415.2 }, // Page 419, line  7.2 (Surah 26: الشعراء)
        {  27,   1,   5573.2 }, // Page 431, line  9.2 (Surah 27: النمل)
        {  28,   1,   5707.1 }, // Page 442, line  0.1 (Surah 28: القصص)
        {  29,   1,   5864.1 }, // Page 454, line  1.1 (Surah 29: العنكبوت)
        {  30,   1,   5980.1 }, // Page 463, line  0.1 (Surah 30: الروم)
        {  31,   1,   6078.2 }, // Page 470, line  7.2 (Surah 31: لقمان)
        {  32,   1,   6139.1 }, // Page 475, line  3.1 (Surah 32: السجدة)
        {  33,   1,   6183.2 }, // Page 478, line  8.2 (Surah 33: الأحزاب)
        {  34,   1,   6335.2 }, // Page 490, line  4.2 (Surah 34: سبإ)
        {  35,   1,   6435.0 }, // Page 498, line  0.0 (Surah 35: فاطر)
        {  36,   1,   6526.7 }, // Page 505, line  0.7 (Surah 36: يس)
        {  37,   1,   6624.2 }, // Page 512, line  7.2 (Surah 37: الصافات)
        {  38,   1,   6734.1 }, // Page 521, line  0.1 (Surah 38: ص)
        {  39,   1,   6825.0 }, // Page 528, line  0.0 (Surah 39: الزمر)
        {  40,   1,   6957.1 }, // Page 538, line  2.1 (Surah 40: غافر)
        {  41,   1,   7094.2 }, // Page 548, line  9.2 (Surah 41: فصلت)
        {  42,   1,   7183.2 }, // Page 555, line  7.2 (Surah 42: الشورى)
        {  43,   1,   7280.0 }, // Page 563, line  0.0 (Surah 43: الزخرف)
        {  44,   1,   7376.2 }, // Page 570, line  5.2 (Surah 44: الدخان)
        {  45,   1,   7417.2 }, // Page 573, line  7.2 (Surah 45: الجاثية)
        {  46,   1,   7475.0 }, // Page 578, line  0.0 (Surah 46: الأحقاف)
        {  47,   1,   7545.2 }, // Page 583, line  5.2 (Surah 47: محمد)
        {  48,   1,   7611.2 }, // Page 588, line  6.2 (Surah 48: الفتح)
        {  49,   1,   7676.2 }, // Page 593, line  6.2 (Surah 49: الحجرات)
        {  50,   1,   7716.2 }, // Page 596, line  7.2 (Surah 50: ق)
        {  51,   1,   7761.0 }, // Page 600, line  0.0 (Surah 51: الذاريات)
        {  52,   1,   7806.2 }, // Page 603, line  6.2 (Surah 52: الطور)
        {  53,   1,   7845.2 }, // Page 606, line  6.2 (Surah 53: النجم)
        {  54,   1,   7886.2 }, // Page 609, line  8.2 (Surah 54: القمر)
        {  55,   1,   7930.0 }, // Page 613, line  0.0 (Surah 55: الرحمن)
        {  56,   1,   7977.2 }, // Page 616, line  8.2 (Surah 56: الواقعة)
        {  57,   1,   8026.1 }, // Page 620, line  5.1 (Surah 57: الحديد)
        {  58,   1,   8099.0 }, // Page 626, line  0.0 (Surah 58: المجادلة)
        {  59,   1,   8151.0 }, // Page 630, line  0.0 (Surah 59: الحشر)
        {  60,   1,   8204.1 }, // Page 634, line  1.1 (Surah 60: الممتحنة)
        {  61,   1,   8248.2 }, // Page 637, line  6.2 (Surah 61: الصف)
        {  62,   1,   8275.2 }, // Page 639, line  7.2 (Surah 62: الجمعة)
        {  63,   1,   8297.1 }, // Page 641, line  3.1 (Surah 63: المنافقون)
        {  64,   1,   8320.0 }, // Page 643, line  0.0 (Surah 64: التغابن)
        {  65,   1,   8348.0 }, // Page 645, line  2.0 (Surah 65: الطلاق)
        {  66,   1,   8379.2 }, // Page 647, line  7.2 (Surah 66: التحريم)
        {  67,   1,   8411.1 }, // Page 650, line  0.1 (Surah 67: الملك)
        {  68,   1,   8450.1 }, // Page 653, line  0.1 (Surah 68: القلم)
        {  69,   1,   8485.2 }, // Page 655, line  9.2 (Surah 69: الحاقة)
        {  70,   1,   8519.1 }, // Page 658, line  4.1 (Surah 70: المعارج)
        {  71,   1,   8549.2 }, // Page 660, line  8.2 (Surah 71: نوح)
        {  72,   1,   8580.1 }, // Page 663, line  0.1 (Surah 72: الجن)
        {  73,   1,   8613.2 }, // Page 665, line  7.2 (Surah 73: المزمل)
        {  74,   1,   8638.2 }, // Page 667, line  6.2 (Surah 74: المدثر)
        {  75,   1,   8671.1 }, // Page 670, line  0.1 (Surah 75: القيامة)
        {  76,   1,   8693.2 }, // Page 671, line  9.2 (Surah 76: الانسان)
        {  77,   1,   8723.1 }, // Page 674, line  0.1 (Surah 77: المرسلات)
        {  78,   1,   8749.0 }, // Page 676, line  0.0 (Surah 78: النبإ)
        {  79,   1,   8771.2 }, // Page 677, line  9.2 (Surah 79: النازعات)
        {  80,   1,   8796.2 }, // Page 679, line  8.2 (Surah 80: عبس)
        {  81,   1,   8814.1 }, // Page 681, line  0.1 (Surah 81: التكوير)
        {  82,   1,   8829.1 }, // Page 682, line  2.1 (Surah 82: الإنفطار)
        {  83,   1,   8841.1 }, // Page 683, line  1.1 (Surah 83: المطففين)
        {  84,   1,   8862.2 }, // Page 684, line  9.2 (Surah 84: الإنشقاق)
        {  85,   1,   8879.1 }, // Page 686, line  0.1 (Surah 85: البروج)
        {  86,   1,   8895.1 }, // Page 687, line  3.1 (Surah 86: الطارق)
        {  87,   1,   8906.1 }, // Page 688, line  1.1 (Surah 87: الأعلى)
        {  88,   1,   8918.1 }, // Page 689, line  0.1 (Surah 88: الغاشية)
        {  89,   1,   8932.0 }, // Page 690, line  1.0 (Surah 89: الفجر)
        {  90,   1,   8950.7 }, // Page 691, line  6.7 (Surah 90: البلد)
        {  91,   1,   8963.2 }, // Page 692, line  6.2 (Surah 91: الشمس)
        {  92,   1,   8972.1 }, // Page 693, line  2.1 (Surah 92: الليل)
        {  93,   1,   8985.1 }, // Page 694, line  2.1 (Surah 93: الضحى)
        {  94,   1,   8992.2 }, // Page 694, line  9.2 (Surah 94: الشرح)
        {  95,   1,   8998.1 }, // Page 695, line  2.1 (Surah 95: التين)
        {  96,   1,   9005.2 }, // Page 695, line  9.2 (Surah 96: العلق)
        {  97,   1,   9016.2 }, // Page 696, line  7.2 (Surah 97: القدر)
        {  98,   1,   9022.1 }, // Page 697, line  0.1 (Surah 98: البينة)
        {  99,   1,   9037.2 }, // Page 698, line  2.2 (Surah 99: الزلزلة)
        { 100,   1,   9044.3 }, // Page 698, line  9.3 (Surah 100: العاديات)
        { 101,   1,   9052.1 }, // Page 699, line  4.1 (Surah 101: القارعة)
        { 102,   1,   9061.1 }, // Page 700, line  0.1 (Surah 102: التكاثر)
        { 103,   1,   9069.2 }, // Page 700, line  8.2 (Surah 103: العصر)
        { 104,   1,   9074.1 }, // Page 701, line  0.1 (Surah 104: الهمزة)
        { 105,   1,   9082.2 }, // Page 701, line  8.2 (Surah 105: الفيل)
        { 106,   1,   9088.1 }, // Page 702, line  1.1 (Surah 106: قريش)
        { 107,   1,   9093.2 }, // Page 702, line  6.2 (Surah 107: الماعون)
        { 108,   1,   9100.1 }, // Page 703, line  0.1 (Surah 108: الكوثر)
        { 109,   1,   9104.1 }, // Page 703, line  4.1 (Surah 109: الكافرون)
        { 110,   1,   9109.2 }, // Page 703, line  9.2 (Surah 110: النصر)
        { 111,   1,   9115.1 }, // Page 704, line  2.1 (Surah 111: المسد)
        { 112,   1,   9121.2 }, // Page 704, line  8.2 (Surah 112: الإخلاص)
        { 113,   1,   9126.7 }, // Page 705, line  0.7 (Surah 113: الفلق)
        { 114,   1,   9139.7 }, // Page 706, line  0.7 (Surah 114: الناس)
        { 114,   6,   9152.0 }, // Page 706, line 13.0 (End of Quran)
    };
    static const int numAnchors = sizeof(s_pieceAnchors) / sizeof(s_pieceAnchors[0]);

    auto findAyahIdx = [&allAyahs](int s, int a) -> int {
        for (int i = 0; i < allAyahs.size(); ++i) {
            if (allAyahs[i].surah == s && allAyahs[i].ayah == a) return i;
        }
        for (int i = 0; i < allAyahs.size(); ++i) {
            if (allAyahs[i].surah == s) return i;
        }
        return -1;
    };

    for (int seg = 0; seg < numAnchors - 1; ++seg) {
        int idxStart = findAyahIdx(s_pieceAnchors[seg].surah, s_pieceAnchors[seg].ayah);
        int idxEnd = findAyahIdx(s_pieceAnchors[seg + 1].surah, s_pieceAnchors[seg + 1].ayah);
        if (seg == numAnchors - 2) {
            idxEnd = allAyahs.size();
        }
        if (idxStart < 0 || idxEnd <= idxStart) continue;

        double segStartTextL = s_pieceAnchors[seg].line;
        if (s_pieceAnchors[seg].ayah == 1) {
            segStartTextL += (s_pieceAnchors[seg].surah == 9) ? 2.0 : 3.0;
        }

        double nextAnchorL = s_pieceAnchors[seg + 1].line;
        double spanL = nextAnchorL - segStartTextL;
        if (spanL <= 0.0) spanL = 13.0;

        double headerCost = 0.0;
        double segWeight = 0.0;
        for (int i = idxStart; i < idxEnd; ++i) {
            if (i > idxStart && allAyahs[i].surah != allAyahs[i - 1].surah) {
                headerCost += (allAyahs[i].surah == 9) ? 2.0 : 3.0;
            }
            segWeight += allAyahs[i].totalWeight;
        }
        if (segWeight <= 0.0) segWeight = 1.0;
        double netTextLines = qMax(spanL * 0.5, spanL - headerCost);

        double curL = segStartTextL;
        for (int i = idxStart; i < idxEnd; ++i) {
            if (i > idxStart && allAyahs[i].surah != allAyahs[i - 1].surah) {
                curL += (allAyahs[i].surah == 9) ? 2.0 : 3.0;
            }
            double textDuration = (allAyahs[i].textWeight / segWeight) * netTextLines;
            double markerDuration = (allAyahs[i].markerWeight / segWeight) * netTextLines;
            double totalDuration = textDuration + markerDuration;

            double startL = curL;
            double endL = curL + textDuration;
            curL += totalDuration;

            int pStart = 3 + static_cast<int>(std::floor(startL / 13.0));
            int pEnd = 3 + static_cast<int>(std::floor((endL - 0.0001) / 13.0));
            pStart = qBound(3, pStart, 706);
            pEnd = qBound(3, pEnd, 706);

            for (int p = pStart; p <= pEnd; ++p) {
                double pBase = (p - 3) * 13.0;
                double localStart = qBound(0.0, startL - pBase, 13.0);
                double localEnd = qBound(0.0, endL - pBase, 13.0);

                if (localEnd > localStart) {
                    QVariantMap item = allAyahs[i].data;
                    item[QStringLiteral("page_number")] = p;
                    item[QStringLiteral("start_line")] = localStart;
                    item[QStringLiteral("end_line")] = localEnd;
                    m_algeriaPageAyahsMap[p].append(item);
                }
            }

            int primaryPage = pStart;
            if (pStart < pEnd && (startL - (pStart - 3) * 13.0) >= 11.5) {
                primaryPage = pEnd;
            }
            quint32 key = (static_cast<quint32>(allAyahs[i].surah) << 16) | static_cast<quint32>(allAyahs[i].ayah);
            m_algeriaAyahPageMap.insert(key, static_cast<quint16>(primaryPage));
        }
    }

    // Ensure every page in [1, 706] has at least one ayah entry (carry forward continuation)
    for (int p = 1; p <= 706; ++p) {
        if (m_algeriaPageAyahsMap[p].isEmpty() && p > 1) {
            if (!m_algeriaPageAyahsMap[p - 1].isEmpty()) {
                QVariantMap carry = m_algeriaPageAyahsMap[p - 1].last().toMap();
                carry[QStringLiteral("page_number")] = p;
                carry[QStringLiteral("start_line")] = 0.0;
                carry[QStringLiteral("end_line")] = 13.0;
                m_algeriaPageAyahsMap[p].append(carry);
            }
        }
    }

    qDebug() << "[QuranManager] Loaded" << m_algeriaAyahPageMap.size() << "Algerian Warsh ayah page mappings across 706 pages.";
}

int QuranManager::getAlgeriaPageForAyah(int surah, int ayah) const
{
    if (m_algeriaAyahPageMap.isEmpty()) {
        const_cast<QuranManager*>(this)->initAlgeriaPageMaps();
    }
    quint32 key = (static_cast<quint32>(surah) << 16) | static_cast<quint32>(ayah);
    if (m_algeriaAyahPageMap.contains(key)) {
        return m_algeriaAyahPageMap.value(key);
    }
    // Backward fallback within the same surah
    for (int a = ayah - 1; a >= 1; --a) {
        quint32 fallbackKey = (static_cast<quint32>(surah) << 16) | static_cast<quint32>(a);
        if (m_algeriaAyahPageMap.contains(fallbackKey)) {
            return m_algeriaAyahPageMap.value(fallbackKey);
        }
    }
    // Forward fallback within the same surah
    for (int a = ayah + 1; a <= 286; ++a) {
        quint32 fallbackKey = (static_cast<quint32>(surah) << 16) | static_cast<quint32>(a);
        if (m_algeriaAyahPageMap.contains(fallbackKey)) {
            return m_algeriaAyahPageMap.value(fallbackKey);
        }
    }
    return 1;
}

QVariantList QuranManager::getAyahsForAlgeriaPage(int pageNumber)
{
    if (pageNumber < 1 || pageNumber > 706) return QVariantList();
    if (!m_algeriaPageAyahsMap.contains(pageNumber) || m_algeriaPageAyahsMap.value(pageNumber).isEmpty()) {
        initAlgeriaPageMaps();
    }
    return m_algeriaPageAyahsMap.value(pageNumber);
}

bool QuranManager::reciterNeedsHafsMapping(const QString &reciterId) const
{
    QString rId = reciterId.isEmpty() ? m_selectedReciterId : reciterId;
    return rId == QStringLiteral("yassin_al_jazaery") || rId == QStringLiteral("ibrahim_aldosary");
}

QList<int> QuranManager::getAudioFilesForAyah(const QString &reciterId, int surah, int ayah) const
{
    QList<int> result;
    if (m_riwayah == 2 && reciterNeedsHafsMapping(reciterId)) {
        quint32 key = (static_cast<quint32>(surah) << 16) | static_cast<quint32>(ayah);
        if (m_warshToHafsMap.contains(key)) {
            HafsRange range = m_warshToHafsMap.value(key);
            for (int h = range.start; h <= range.end; ++h) {
                result.append(h);
            }
            return result;
        }
    }
    result.append(ayah);
    return result;
}

int QuranManager::getAudioStartOffsetMs(const QString &reciterId, int surah, int ayah) const
{
    if (m_riwayah == 2 && reciterNeedsHafsMapping(reciterId)) {
        quint32 key = (static_cast<quint32>(surah) << 16) | static_cast<quint32>(ayah);
        if (m_warshToHafsMap.contains(key)) {
            return m_warshToHafsMap.value(key).startMs;
        }
    }
    return 0;
}

int QuranManager::getEffectiveAudioAyah(const QString &reciterId, int surah, int ayah) const
{
    QList<int> files = getAudioFilesForAyah(reciterId, surah, ayah);
    return files.isEmpty() ? ayah : files.first();
}

void QuranManager::initAudio()
{
    m_player = new QMediaPlayer(this);
    connect(m_player, &QMediaPlayer::mediaStatusChanged, this, &QuranManager::onMediaStatusChanged);
    connect(m_player, &QMediaPlayer::positionChanged, this, &QuranManager::onPositionChanged);
    connect(m_player, &QMediaPlayer::durationChanged, this, &QuranManager::onDurationChanged);
    connect(m_player, static_cast<void(QMediaPlayer::*)(QMediaPlayer::Error)>(&QMediaPlayer::error),
            this, &QuranManager::onPlayerError);
}

void QuranManager::onPlayerError(QMediaPlayer::Error error)
{
    if (error != QMediaPlayer::NoError) {
        qWarning() << "[QuranManager] QMediaPlayer error:" << error << (m_player ? m_player->errorString() : QString());
        bool isNetwork = (error == QMediaPlayer::NetworkError || error == QMediaPlayer::ResourceError);
        emit audioPlaybackFailed(m_playingSurah, m_playingAyah, isNetwork);
    }
}

int QuranManager::riwayah() const
{
    return m_riwayah;
}

void QuranManager::setRiwayah(int rId)
{
    if (rId != 1 && rId != 2) return;
    if (m_riwayah != rId) {
        if (isPlaying()) {
            stopAudio();
        }
        m_riwayah = rId;
        m_memCachedPageNumber = -1;
        m_memCachedRiwayah = -1;
        m_memCachedSvgContent.clear();

        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        s.setValue(QStringLiteral("quran/riwayah"), m_riwayah);

        if (m_riwayah == 1 && m_algeriaMode) {
            m_algeriaMode = false;
            s.setValue(QStringLiteral("quran/algeriaMode"), false);
            emit algeriaModeChanged();
        }

        // Update default reciter for new Riwayah
        QVariantList reciters = getAvailableReciters();
        if (!reciters.isEmpty()) {
            m_selectedReciterId = reciters.first().toMap().value(QStringLiteral("id")).toString();
            s.setValue(QStringLiteral("quran/reciterId"), m_selectedReciterId);
            emit reciterChanged();
        }

        int exactPage = getPageForAyah(m_lastSurah, m_lastAyah, m_riwayah);
        if (exactPage > 0) {
            m_lastPage = exactPage;
            s.setValue(QStringLiteral("quran/lastPage"), m_lastPage);
        }
        s.sync();

        emit riwayahChanged();
        emit mushafNameChanged();
        emit lastPositionChanged();
    }
}

QString QuranManager::riwayahCode() const
{
    return m_riwayah == 2 ? QStringLiteral("warsh") : QStringLiteral("hafs");
}

QString QuranManager::riwayahName() const
{
    if (m_riwayah == 2) {
        return QString::fromUtf8("ورش عن نافع");
    }
    return QString::fromUtf8("حفص عن عاصم");
}

QString QuranManager::riwayahDescription() const
{
    return m_riwayah == 2
        ? QString::fromUtf8("رواية الإمام ورش عن نافع المدني من طريق الأزرق، الرواية الرسمية في الجزائر والمغرب العربي.")
        : QString::fromUtf8("رواية الإمام حفص عن عاصم، الرواية الأكثر انتشاراً في العالم الإسلامي.");
}

QString QuranManager::mushafName() const
{
    if (m_algeriaMode && m_riwayah == 2) {
        return QString::fromUtf8("المصحف الجزائري");
    }
    if (m_tajweedMode) {
        return QString::fromUtf8("مصحف التجويد");
    }
    return QString::fromUtf8("مصحف المدينة المنورة");
}

QString QuranManager::mushafDisplayName() const
{
    if (m_algeriaMode && m_riwayah == 2) {
        return QStringLiteral("Algerian Mushaf");
    }
    if (m_tajweedMode) {
        return QStringLiteral("Tajweed Mushaf");
    }
    return QStringLiteral("Medina Mushaf");
}

int QuranManager::fontSize() const
{
    return m_fontSize;
}

void QuranManager::setFontSize(int size)
{
    int clamped = qBound(18, size, 75);
    if (m_fontSize != clamped) {
        m_fontSize = clamped;
        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        s.setValue(QStringLiteral("quran/fontSize"), m_fontSize);
        s.sync();
        emit fontSizeChanged();
    }
}

int QuranManager::tafsirFontSize() const
{
    return m_tafsirFontSize;
}

void QuranManager::setTafsirFontSize(int size)
{
    int clamped = qBound(14, size, 56);
    if (m_tafsirFontSize != clamped) {
        m_tafsirFontSize = clamped;
        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        s.setValue(QStringLiteral("quran/tafsirFontSize"), m_tafsirFontSize);
        s.sync();
        emit tafsirFontSizeChanged();
    }
}

int QuranManager::viewMode() const
{
    return m_viewMode;
}

void QuranManager::setViewMode(int mode)
{
    if (mode < 0 || mode > 1) mode = 0;
    if (m_viewMode != mode) {
        m_viewMode = mode;
        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        s.setValue(QStringLiteral("quran/viewMode"), m_viewMode);
        s.sync();
        emit viewModeChanged();
    }
}

bool QuranManager::darkMode() const
{
    return m_darkMode;
}

void QuranManager::setDarkMode(bool dark)
{
    if (m_darkMode != dark) {
        m_darkMode = dark;
        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        s.setValue(QStringLiteral("quran/darkMode"), m_darkMode);
        s.sync();
        emit darkModeChanged();
    }
}

int QuranManager::maxPages() const
{
    if (m_algeriaMode && m_riwayah == 2) {
        return 706;
    }
    return 604;
}

bool QuranManager::tajweedMode() const
{
    return m_tajweedMode;
}

void QuranManager::setTajweedMode(bool enabled)
{
    if (m_tajweedMode != enabled) {
        m_tajweedMode = enabled;
        if (m_tajweedMode && m_algeriaMode) {
            m_algeriaMode = false;
            QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
            s.setValue(QStringLiteral("quran/algeriaMode"), false);
            emit algeriaModeChanged();
        } else if (!m_tajweedMode && m_riwayah == 2) {
            m_algeriaMode = true;
            QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
            s.setValue(QStringLiteral("quran/algeriaMode"), true);
            emit algeriaModeChanged();
        }
        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        s.setValue(QStringLiteral("quran/tajweedMode"), m_tajweedMode);
        s.sync();
        emit tajweedModeChanged();
        emit riwayahChanged(); // To refresh maxPages
        emit mushafNameChanged();
        emit pageCached(m_lastPage);
    }
}

bool QuranManager::algeriaMode() const
{
    return m_algeriaMode;
}

void QuranManager::setAlgeriaMode(bool enabled)
{
    if (m_algeriaMode != enabled) {
        m_algeriaMode = enabled;
        if (m_algeriaMode) {
            m_riwayah = 2; // Auto-switch to Warsh
            if (m_tajweedMode) {
                m_tajweedMode = false;
                QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
                s.setValue(QStringLiteral("quran/tajweedMode"), false);
                emit tajweedModeChanged();
            }
        }
        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        s.setValue(QStringLiteral("quran/algeriaMode"), m_algeriaMode);
        s.setValue(QStringLiteral("quran/riwayah"), m_riwayah);
        s.sync();
        emit algeriaModeChanged();
        emit riwayahChanged(); // Updates maxPages to 706
        emit mushafNameChanged();
        emit pageCached(m_lastPage);
    }
}

bool QuranManager::tajweedHdMode() const
{
    return m_tajweedHdMode;
}

void QuranManager::setTajweedHdMode(bool hd)
{
    if (m_tajweedHdMode != hd) {
        m_tajweedHdMode = hd;
        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        s.setValue(QStringLiteral("quran/tajweedHdMode"), m_tajweedHdMode);
        s.sync();
        emit tajweedHdModeChanged();
        emit pageCached(m_lastPage);
    }
}

bool QuranManager::screenBlankingDisabled() const
{
    return m_screenBlankingDisabled;
}

void QuranManager::setScreenBlankingDisabled(bool disabled)
{
    if (m_screenBlankingDisabled != disabled) {
        m_screenBlankingDisabled = disabled;
        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        s.setValue(QStringLiteral("quran/screenBlankingDisabled"), m_screenBlankingDisabled);
        s.sync();
        emit screenBlankingDisabledChanged();
        updateBlankingState();
    }
}

void QuranManager::setReaderActive(bool active)
{
    if (m_readerActive != active) {
        m_readerActive = active;
        updateBlankingState();
    }
}

void QuranManager::updateBlankingState()
{
    // Screen blanking is disabled (kept awake) ONLY when reader is active (pages, text, or tajweed)
    // AND the user chose "disabled" (m_screenBlankingDisabled == true)
    bool prevent = m_readerActive && m_screenBlankingDisabled;
    if (m_isPreventingBlanking == prevent) {
        return;
    }
    m_isPreventingBlanking = prevent;

    if (prevent) {
        PowerButtonWatcher::requestBlankingPause();
        if (!m_blankingTimer) {
            m_blankingTimer = new QTimer(this);
            m_blankingTimer->setInterval(30000);
            connect(m_blankingTimer, &QTimer::timeout, this, []() {
                PowerButtonWatcher::requestBlankingPause();
            });
        }
        m_blankingTimer->start();
        qDebug() << "QuranManager: Screen blanking PAUSED (screen kept on while actively reading Quran)";
    } else {
        if (m_blankingTimer) {
            m_blankingTimer->stop();
        }
        PowerButtonWatcher::cancelBlankingPause();
        qDebug() << "QuranManager: Screen blanking RESTORED (standard system screen sleep policy)";
    }
}

static bool isTransparentArabic(QChar c)
{
    ushort u = c.unicode();
    return (u >= 0x064B && u <= 0x065F) // harakat, sukun, shaddah, tanween
        || (u == 0x0670)                // dagger alif
        || (u >= 0x06D6 && u <= 0x06ED) // Quranic marks
        || (u == 0x0653)                // maddah above
        || (u >= 0x08D4 && u <= 0x08ED)
        || (u >= 0x200B && u <= 0x200F); // formatting marks (ZWJ, ZWNJ, etc.)
}

static bool connectsToNextArabic(QChar c)
{
    ushort u = c.unicode();
    // Dual-joining letters connect to the following letter:
    switch (u) {
    case 0x0628: case 0x062A: case 0x062B: // ب ت ث
    case 0x062C: case 0x062D: case 0x062E: // ج ح خ
    case 0x0633: case 0x0634:             // س ش
    case 0x0635: case 0x0636:             // ص ض
    case 0x0637: case 0x0638:             // ط ظ
    case 0x0639: case 0x063A:             // ع غ
    case 0x0641: case 0x0642:             // ف ق
    case 0x0643: case 0x0644: case 0x0645: case 0x0646: case 0x0647: case 0x064A: // ك ل م ن ه ي
    case 0x0626:                         // ئ
    case 0x0640:                         // Tatweel ـ
    case 0x200D:                         // ZWJ
    case 0x066E: case 0x066F:             // Dotless baa / qaf
    case 0x067E: case 0x0686: case 0x06A9: case 0x06AF: case 0x06CC:
        return true;
    default:
        return false;
    }
}

static bool connectsToPrevArabic(QChar c)
{
    if (connectsToNextArabic(c)) return true;
    ushort u = c.unicode();
    // Right-joining letters:
    switch (u) {
    case 0x0627: case 0x0622: case 0x0623: case 0x0625: case 0x0671: // ا آ أ إ ٱ
    case 0x062F: case 0x0630: // د ذ
    case 0x0631: case 0x0632: // ر ز
    case 0x0648: case 0x0624: // و ؤ
    case 0x0629:             // ة
    case 0x0649:             // ى
    case 0x0672: case 0x0673: case 0x0675: case 0x0688: case 0x0698:
        return true;
    default:
        return false;
    }
}

static QChar lastBaseChar(const QString &s)
{
    for (int i = s.length() - 1; i >= 0; --i) {
        if (!isTransparentArabic(s.at(i)))
            return s.at(i);
    }
    return QChar();
}

static QChar firstBaseChar(const QString &s)
{
    for (int i = 0; i < s.length(); ++i) {
        if (!isTransparentArabic(s.at(i)))
            return s.at(i);
    }
    return QChar();
}

QString QuranManager::formatTajweedHtml(const QString &tajweedText, bool isDark) const
{
    if (tajweedText.isEmpty()) return QString();

    auto getColor = [isDark](QChar rule) -> QString {
        switch (rule.toLatin1()) {
        case 'h': // Hamzat Wasl (همزة وصل)
        case 's': // Silent (حروف لا تنطق)
        case 'l': // Laam Shamsiyah (لام شمسية)
            return isDark ? QStringLiteral("#888888") : QStringLiteral("#999999");
        case 'n': // Madd Tabii (مد طبيعي - حركتان)
            return isDark ? QStringLiteral("#7BA0FF") : QStringLiteral("#537FFF");
        case 'p': // Madd Aaridh (مد عارض للسكون - 2 أو 4 أو 6 حركات)
            return isDark ? QStringLiteral("#6E88FF") : QStringLiteral("#4050FF");
        case 'm': // Madd Lazim (مد لازم - 6 حركات)
            return isDark ? QStringLiteral("#506FFF") : QStringLiteral("#000EBC");
        case 'o': // Madd Wajib / Jaiz Munfasil (مد واجب أو منفصل - 4-5 حركات)
            return isDark ? QStringLiteral("#5F7DF5") : QStringLiteral("#2144C1");
        case 'q': // Qalqalah (قلقلة)
            return isDark ? QStringLiteral("#FF5555") : QStringLiteral("#DD0008");
        case 'g': // Ghunnah (غنة)
            return isDark ? QStringLiteral("#FFA540") : QStringLiteral("#FF7E1E");
        case 'f': // Ikhfa (إخفاء)
            return isDark ? QStringLiteral("#D055E8") : QStringLiteral("#9400A8");
        case 'c': // Ikhfa Shafawi (إخفاء شفوي)
            return isDark ? QStringLiteral("#F260E0") : QStringLiteral("#D500B7");
        case 'i': // Iqlab (إقلاب)
            return isDark ? QStringLiteral("#60D5FF") : QStringLiteral("#26BFFD");
        case 'a': // Idgham with Ghunnah (إدغام بغنة)
        case 'u': // Idgham without Ghunnah (إدغام بغير غنة)
            return isDark ? QStringLiteral("#4ED436") : QStringLiteral("#169200");
        case 'w': // Idgham Shafawi (إدغام شفوي)
            return isDark ? QStringLiteral("#8CE442") : QStringLiteral("#58B800");
        case 'd': // Idgham Mutajanisayn (إدغام متجانسين)
        case 'b': // Idgham Mutaqaribayn (إدغام متقاربين)
            return isDark ? QStringLiteral("#B0B0B0") : QStringLiteral("#8E8E8E");
        default:
            return QString();
        }
    };

    QString text = tajweedText;

    // Fix 1: Merge [s[و][n[ٲ] or [s[و][n[ٰ] into [n[وٰ] (Madd Tabii on Waw with Dagger Alif)
    // In words like ٱلرِّبَوٰا۟, ٱلصَّلَوٰةَ, ٱلزَّكَوٰةَ, ٱلْحَيَوٰةَ:
    // the source dataset used [s[و][n[ٲ], which renders as an extra standalone Alef
    // instead of a dagger alif on top of waw.
    static const QRegularExpression wawDaggerRx(QStringLiteral("\\[s[a-z0-9_:]*\\[\\x{0648}\\]\\[n[a-z0-9_:]*\\[[\\x{0672}\\x{0670}]\\]"));
    text.replace(wawDaggerRx, QStringLiteral("[n[") + QChar(0x0648) + QChar(0x0670) + QStringLiteral("]"));

    // Fix 2: Normalize all remaining occurrences of 0x0672 (Alef with wavy hamza)
    // to 0x0670 (Arabic letter superscript/dagger alif).
    text.replace(QChar(0x0672), QChar(0x0670));

    // Normalize 0x06ED (Small low meem for Iqlab) to 0x06E2 (Small high meem),
    // because official Uthmanic fonts (like UthmanicHafs) map uni06ED to uni0600 (dotted circle).
    text.replace(QChar(0x06ED), QChar(0x06E2));

    // Normalize broken yaa + tatweel + hamza sequences in raw text (e.g. Warsh: نَبِّيـُٔكُم -> نَبِّئُكُم, يُنَبِّيـُٔهُمُ -> يُنَبِّئُهُمُ)
    text.replace(QString::fromUtf8("\u064a\u0640\u0654"), QString::fromUtf8("\u0626"));
    text.replace(QString::fromUtf8("\u064a\u0654"), QString::fromUtf8("\u0626"));

    // Fix 3: Collapse multiple consecutive tatweels (ـ) to a single tatweel
    // Words like يَسْــَٔلُونَ, تَسْــَٔلُوا, تُسْــَٔلُونَ had double tatweels (ـ)
    // which breaks the baseline in OpenType fonts and leaves a wide gap with a detached hamza.
    static const QRegularExpression multiTatweelRx(QStringLiteral("\\x{0640}{2,}"));
    text.replace(multiTatweelRx, QString(QChar(0x0640)));

    // Collapse double tatweels surrounding hamza (ـٔـ or ـَٔـ) to a single tatweel with hamza (ـٔ / ـَٔ)
    static const QRegularExpression hamzaTatweelRx(QStringLiteral("\\x{0640}([\\x{064B}-\\x{065F}]*\\x{0654}[\\x{064B}-\\x{065F}]*)\\x{0640}"));
    text.replace(hamzaTatweelRx, QStringLiteral("\\x{0640}\\1"));

    // Remove any trailing tatweel directly preceding a tag opening on an Alef
    static const QRegularExpression tatweelBeforeTagAlefRx(QStringLiteral("\\x{0640}(\\[[a-z][a-z0-9_:]*\\[[\\x{0627}\\x{0622}\\x{0623}\\x{0625}])"));
    text.replace(tatweelBeforeTagAlefRx, QStringLiteral("\\1"));

    // Fix: Normalize connective tatweel + hamza before non-final alef (as in مَآرِب, مَآب, فَآمَن, بِآيَات)
    // to seamless Alef Madda (آ), removing broken tatweels and floating hamzas
    static const QRegularExpression tajweedTatweelHamzaAlefRx(QStringLiteral("(?:[\\x{0640}\\x{E000}][\\x{064E}]?[\\x{0654}\\x{0655}]|[\\x{0640}\\x{E000}][\\x{0654}\\x{0655}][\\x{064E}]?|[\\x{0654}\\x{0655}][\\x{064E}]?[\\x{0640}\\x{E000}])[\\x{064E}]?\\x{0627}(?=[\\x{0621}-\\x{064A}])"));
    text.replace(tajweedTatweelHamzaAlefRx, QString::fromUtf8("\u0622"));

    // Fix: Normalize ma'ab (مَـَٔاب / مَـَٔاب / ٱلْمَـَٔابِ) to seamless ligature مَآب
    // removing intra-word tags and collapsing broken tatweel+hamza sequences before alef
    static const QRegularExpression maabTagRx(QStringLiteral("\\x{0645}[\\x{064E}]?(?:\\[[a-z0-9_:]*\\[)*[^\\s\\x{0627}\\x{0628}\\[\\]]*\\x{0654}(?:\\[[a-z0-9_:]*\\[|\\]|[^\\s\\x{0627}\\x{0628}\\[\\]])*\\x{0627}(?:\\])*(?:\\[[a-z0-9_:]*\\[)*(\\x{0628}[^\\s\\[\\]<>]*)"));
    text.replace(maabTagRx, QString::fromUtf8("\u0645\u064E\u0622\\1"));
    static const QRegularExpression maabCloseBracketRx(QStringLiteral("(\\x{0645}\\x{064E}\\x{0622}\\x{0628}[^\\s\\[\\]<>]*)\\]+"));
    text.replace(maabCloseBracketRx, QStringLiteral("\\1"));

    // Fix 4: Madd Tabii tags containing only a dagger alif (such as [n[َٰ], [n[ٰ], or [n[ـٰ])
    // should simply be unwrapped so the dagger alif remains naturally attached to its preceding
    // base consonant. In official Tajweed Mushafs (and Quranpedia), dagger alif is normal text color;
    // pulling the consonant into [n[...]] erroneously turns base letters (like ر in فِرَٰشًا and ٱلثَّمَرَٰتِ)
    // blue! Unwrapping preserves native OpenType HarfBuzz shaping with normal consonant coloring.
    static const QRegularExpression daggerTabiiUnwrapRx(QStringLiteral("\\[n[a-z0-9_:]*\\[[\\x{0640}]*([\\x{064E}]?[\\x{0670}][\\x{064B}-\\x{065F}]*)\\]"));
    text.replace(daggerTabiiUnwrapRx, QStringLiteral("\\1"));

    // Fallback: If any other combining-only tag has no preceding consonant, inject a carrier
    static const QRegularExpression markOnlyTagRx(QStringLiteral("\\[([a-z])[a-z0-9_:]*\\[([\\x{064B}-\\x{065F}\\x{0670}\\x{0653}]+)\\]"));
    text.replace(markOnlyTagRx, QStringLiteral("[\\1[") + QChar(0x0640) + QStringLiteral("\\2]"));


    // Step 1: Absorb trailing diacritics directly after ']' (including multiple closing brackets ']]') into the tag
    static const QRegularExpression orphanDiacriticRx(QStringLiteral("(\\]+)([\\x{064B}-\\x{065F}\\x{0670}\\x{0653}]+)"));
    text.replace(orphanDiacriticRx, QStringLiteral("\\2\\1"));

    // Step 2: Parse into contiguous runs of text with assigned rules
    struct TajweedRun {
        QString text;
        QChar rule;
    };
    QList<TajweedRun> runs;

    struct ActiveTajweedRule {
        QChar rule;
        int spaces;
    };
    QList<ActiveTajweedRule> stack;
    QString currentText;

    auto isCrossWord = [](QChar r) {
        char c = r.toLatin1();
        return (c == 'a' || c == 'u' || c == 'i' || c == 'f' || c == 'w' || c == 'c' || c == 'b' || c == 'd');
    };

    static const QRegularExpression openTagRx(QStringLiteral("^\\[([a-z])[a-z0-9_:]*\\["));

    int i = 0;
    const int len = text.length();
    while (i < len) {
        if (text.at(i) == QLatin1Char('[')) {
            QRegularExpressionMatch m = openTagRx.match(text.mid(i));
            if (m.hasMatch()) {
                if (!currentText.isEmpty()) {
                    TajweedRun r;
                    r.text = currentText;
                    r.rule = stack.isEmpty() ? QChar() : stack.last().rule;
                    runs.append(r);
                    currentText.clear();
                }
                ActiveTajweedRule ar;
                ar.rule = m.captured(1).at(0);
                ar.spaces = 0;
                stack.append(ar);
                i += m.capturedLength();
                continue;
            } else {
                i++;
                continue;
            }
        } else if (text.at(i) == QLatin1Char(']')) {
            if (!currentText.isEmpty()) {
                TajweedRun r;
                r.text = currentText;
                r.rule = stack.isEmpty() ? QChar() : stack.last().rule;
                runs.append(r);
                currentText.clear();
            }
            if (!stack.isEmpty()) {
                stack.removeLast();
            }
            i++;
            continue;
        } else if (text.at(i) == QLatin1Char(' ')) {
            // Defensive boundary check: Tajweed rules cannot span multiple words.
            // Intra-word rules cannot cross a space; cross-word rules can cross at most 1 space.
            if (!stack.isEmpty()) {
                ActiveTajweedRule &top = stack.last();
                if (!isCrossWord(top.rule) || top.spaces >= 1) {
                    if (!currentText.isEmpty()) {
                        TajweedRun r;
                        r.text = currentText;
                        r.rule = top.rule;
                        runs.append(r);
                        currentText.clear();
                    }
                    stack.removeLast();
                } else {
                    top.spaces++;
                }
            }
            currentText.append(QLatin1Char(' '));
            i++;
            continue;
        } else {
            currentText.append(text.at(i));
            i++;
        }
    }
    if (!currentText.isEmpty()) {
        TajweedRun r;
        r.text = currentText;
        r.rule = stack.isEmpty() ? QChar() : stack.last().rule;
        runs.append(r);
    }

    // Step 3: Merge adjacent runs having the exact same rule/color
    QList<TajweedRun> merged;
    for (const TajweedRun &r : runs) {
        if (r.text.isEmpty()) continue;
        if (!merged.isEmpty() && merged.last().rule == r.rule) {
            merged.last().text.append(r.text);
        } else {
            merged.append(r);
        }
    }

    // Step 4: Ligature Repair via Zero-Width Joiner (ZWJ U+200D)
    // Whenever an intra-word boundary connects from left to right, insert ZWJ
    static const QChar zwj(0x200D);
    for (int k = 0; k < merged.size() - 1; ++k) {
        TajweedRun &r1 = merged[k];
        TajweedRun &r2 = merged[k + 1];

        QChar cLast = lastBaseChar(r1.text);
        QChar cFirst = firstBaseChar(r2.text);

        if (connectsToNextArabic(cLast) && connectsToPrevArabic(cFirst)) {
            // Do not append ZWJ to r1 if it already ends with a tatweel baseline
            if (cLast != QChar(0x0640)) {
                r1.text.append(zwj);
            }
            r2.text.prepend(zwj);
        }
    }

    // Step 5: Format into final HTML spans
    QString result;
    result.reserve(text.length() * 2);
    for (const TajweedRun &r : merged) {
        QString col = r.rule.isNull() ? QString() : getColor(r.rule);
        if (!col.isEmpty()) {
            result.append(QStringLiteral("<span style=\"color:%1;\">%2</span>").arg(col, r.text));
        } else {
            result.append(r.text);
        }
    }

    return result;
}

int QuranManager::lastSurah() const
{
    return m_lastSurah;
}

int QuranManager::lastAyah() const
{
    return m_lastAyah;
}

int QuranManager::lastPage() const
{
    if (m_lastSurah > 0 && m_lastAyah > 0) {
        int p = getPageForAyah(m_lastSurah, m_lastAyah, m_riwayah);
        if (p >= 1 && p <= maxPages()) {
            return p;
        }
    }
    return m_lastPage;
}

QString QuranManager::selectedTafsirEditionId() const
{
    return m_selectedTafsirEditionId;
}

void QuranManager::setSelectedTafsirEditionId(const QString &editionId)
{
    if (editionId.isEmpty()) return;
    if (m_selectedTafsirEditionId != editionId) {
        m_selectedTafsirEditionId = editionId;
        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        s.setValue(QStringLiteral("quran/tafsirEdition"), m_selectedTafsirEditionId);
        s.sync();
        emit selectedTafsirEditionChanged();
    }
}

bool QuranManager::isPlaying() const
{
    return m_player && (m_player->state() == QMediaPlayer::PlayingState);
}

int QuranManager::playingSurah() const
{
    return m_playingSurah;
}

int QuranManager::playingAyah() const
{
    return m_playingAyah;
}

QString QuranManager::selectedReciterId() const
{
    return m_selectedReciterId;
}

QString QuranManager::selectedReciterName() const
{
    QVariantList reciters = const_cast<QuranManager*>(this)->getAvailableReciters();
    for (const QVariant &r : reciters) {
        QVariantMap m = r.toMap();
        if (m.value(QStringLiteral("id")).toString() == m_selectedReciterId) {
            return m.value(QStringLiteral("name_ar")).toString();
        }
    }
    if (!reciters.isEmpty()) {
        return reciters.first().toMap().value(QStringLiteral("name_ar")).toString();
    }
    return QString();
}

double QuranManager::audioProgress() const
{
    return m_audioProgress;
}

QVariantList QuranManager::getRiwayat()
{
    QVariantList list;
    if (!m_db.isOpen()) return list;

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT id, code, name_ar, name_en, description_ar, total_verses FROM riwayat ORDER BY id ASC"));
    if (q.exec()) {
        while (q.next()) {
            QVariantMap m;
            m[QStringLiteral("id")] = q.value(0).toInt();
            m[QStringLiteral("code")] = q.value(1).toString();
            m[QStringLiteral("name_ar")] = q.value(2).toString();
            m[QStringLiteral("name_en")] = q.value(3).toString();
            m[QStringLiteral("description_ar")] = q.value(4).toString();
            m[QStringLiteral("total_verses")] = q.value(5).toInt();
            list.append(m);
        }
    }
    return list;
}

QVariantList QuranManager::getSurahs()
{
    QVariantList list;
    if (!m_db.isOpen()) return list;

    // Riwayah-specific verse counts and start pages
    QMap<int, int> verseCounts;
    QMap<int, int> startPages;
    QSqlQuery qMeta(m_db);
    qMeta.prepare(QStringLiteral("SELECT surah_number, COUNT(*), MIN(page_number) FROM ayahs WHERE riwayah_id = ? GROUP BY surah_number"));
    qMeta.addBindValue(m_riwayah);
    if (qMeta.exec()) {
        while (qMeta.next()) {
            int sNum = qMeta.value(0).toInt();
            verseCounts[sNum] = qMeta.value(1).toInt();
            startPages[sNum] = qMeta.value(2).toInt();
        }
    }

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT number, name_ar, name_en, name_translation, revelation_type, total_verses, start_page FROM surahs ORDER BY number ASC"));
    if (q.exec()) {
        while (q.next()) {
            QVariantMap m;
            int sNum = q.value(0).toInt();
            m[QStringLiteral("number")] = sNum;
            m[QStringLiteral("name_ar")] = q.value(1).toString();
            m[QStringLiteral("name_en")] = q.value(2).toString();
            m[QStringLiteral("name_translation")] = q.value(3).toString();
            m[QStringLiteral("revelation_type")] = q.value(4).toString();
            m[QStringLiteral("total_verses")] = verseCounts.value(sNum, q.value(5).toInt());
            int stPage = getPageForAyah(sNum, 1, m_riwayah);
            if (stPage <= 0) {
                stPage = startPages.value(sNum, q.value(6).toInt());
            }
            m[QStringLiteral("start_page")] = stPage;
            list.append(m);
        }
    }
    return list;
}

QVariantMap QuranManager::getSurah(int surahNumber)
{
    QVariantMap m;
    if (!m_db.isOpen()) return m;

    int totalVerses = 0;
    int startPage = 0;
    QSqlQuery qMeta(m_db);
    qMeta.prepare(QStringLiteral("SELECT COUNT(*), MIN(page_number) FROM ayahs WHERE riwayah_id = ? AND surah_number = ?"));
    qMeta.addBindValue(m_riwayah);
    qMeta.addBindValue(surahNumber);
    if (qMeta.exec() && qMeta.next()) {
        totalVerses = qMeta.value(0).toInt();
        startPage = qMeta.value(1).toInt();
    }

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT number, name_ar, name_en, name_translation, revelation_type, total_verses, start_page FROM surahs WHERE number = ?"));
    q.addBindValue(surahNumber);
    if (q.exec() && q.next()) {
        m[QStringLiteral("number")] = q.value(0).toInt();
        m[QStringLiteral("name_ar")] = q.value(1).toString();
        m[QStringLiteral("name_en")] = q.value(2).toString();
        m[QStringLiteral("name_translation")] = q.value(3).toString();
        m[QStringLiteral("revelation_type")] = q.value(4).toString();
        m[QStringLiteral("total_verses")] = totalVerses > 0 ? totalVerses : q.value(5).toInt();
        int stPage = getPageForAyah(surahNumber, 1, m_riwayah);
        if (stPage <= 0) {
            stPage = startPage > 0 ? startPage : q.value(6).toInt();
        }
        m[QStringLiteral("start_page")] = stPage;
    }
    return m;
}

QVariantList QuranManager::getJuzs()
{
    QVariantList list;
    if (!m_db.isOpen()) return list;

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT j.number, j.name_ar, j.surah_number, j.ayah_number, j.start_page, s.name_ar, s.name_en FROM juzs j JOIN surahs s ON j.surah_number = s.number ORDER BY j.number ASC"));
    if (q.exec()) {
        while (q.next()) {
            QVariantMap m;
            int sNum = q.value(2).toInt();
            int aNum = q.value(3).toInt();
            int stPage = getPageForAyah(sNum, aNum, m_riwayah);
            if (stPage <= 0) stPage = q.value(4).toInt();

            m[QStringLiteral("number")] = q.value(0).toInt();
            m[QStringLiteral("name_ar")] = q.value(1).toString();
            m[QStringLiteral("surah_number")] = sNum;
            m[QStringLiteral("ayah_number")] = aNum;
            m[QStringLiteral("start_page")] = stPage;
            m[QStringLiteral("surah_name_ar")] = q.value(5).toString();
            m[QStringLiteral("surah_name_en")] = q.value(6).toString();
            list.append(m);
        }
    }
    return list;
}

QVariantList QuranManager::getHizbs()
{
    QVariantList list;
    if (!m_db.isOpen()) return list;

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT h.number, h.juz_number, h.surah_number, h.ayah_number, h.start_page, s.name_ar, s.name_en FROM hizbs h JOIN surahs s ON h.surah_number = s.number ORDER BY h.number ASC"));
    if (q.exec()) {
        while (q.next()) {
            QVariantMap m;
            int sNum = q.value(2).toInt();
            int aNum = q.value(3).toInt();
            int stPage = getPageForAyah(sNum, aNum, m_riwayah);
            if (stPage <= 0) stPage = q.value(4).toInt();

            m[QStringLiteral("number")] = q.value(0).toInt();
            m[QStringLiteral("juz_number")] = q.value(1).toInt();
            m[QStringLiteral("surah_number")] = sNum;
            m[QStringLiteral("ayah_number")] = aNum;
            m[QStringLiteral("start_page")] = stPage;
            m[QStringLiteral("surah_name_ar")] = q.value(5).toString();
            m[QStringLiteral("surah_name_en")] = q.value(6).toString();
            list.append(m);
        }
    }
    return list;
}

static QString cleanUthmaniText(const QString &text, int riwayah)
{
    if (text.isEmpty()) return text;
    QString result = text;

    if (riwayah != 2) {
        // Replace Urdu Yeh Barree (0x06D2 / 0x06D3) with standard Arabic Yeh (0x064A)
        result.replace(QChar(0x06D2), QChar(0x064A));
        result.replace(QChar(0x06D3), QChar(0x064A));

        // Normalize Iqlab low meem (0x06ED) to high meem (0x06E2) for standard Uthmanic fonts
        result.replace(QChar(0x06ED), QChar(0x06E2));

        // Remove Warsh Tashil / stop marks (0x06EC, 0x06EA, 0x06EB) that render as dotted circles in Arabic fonts
        result.remove(QChar(0x06EC));
        result.remove(QChar(0x06EA));
        result.remove(QChar(0x06EB));
    }

    // Normalize connective tatweel + hamza before non-final alef (ـَٔا / ـَٔا / ٔـَا as in مَآرِب, مَآب, فَآمَن, بِآيَات, سَآتِيكُم)
    // to standard Alef Madda (آ) to eliminate broken tatweel lines, blank gaps, and floating hamzas
    static const QRegularExpression tatweelHamzaAlefRx(QStringLiteral("(?:[\\x{0640}\\x{E000}][\\x{064E}]?[\\x{0654}\\x{0655}]|[\\x{0640}\\x{E000}][\\x{0654}\\x{0655}][\\x{064E}]?|[\\x{0654}\\x{0655}][\\x{064E}]?[\\x{0640}\\x{E000}])[\\x{064E}]?\\x{0627}(?=[\\x{0621}-\\x{064A}])"));
    result.replace(tatweelHamzaAlefRx, QString::fromUtf8("\u0622"));

    // Also specifically ensure any remaining ma'ab (مَـَٔاب / مَـَٔاب) forms with stop marks/tanween are normalized to مَآب
    static const QRegularExpression maabCleanRx(QStringLiteral("\\x{0645}[\\x{064E}]?[\\x{0640}\\x{064E}\\x{0654}\\x{E000}]*[\\x{0654}\\x{0655}][\\x{0640}\\x{064E}\\x{0654}\\x{E000}]*\\x{0627}(\\x{0628}[\\x{064B}-\\x{065F}\\x{06D6}-\\x{06ED}\\x{08F0}-\\x{08F2}\\x{200C}-\\x{200F}]*)"));
    result.replace(maabCleanRx, QString::fromUtf8("\u0645\u064E\u0622\\1"));

    // Protect tatweels in Uthmanic hamza ligatures (e.g. ـٔ, ـَٔ, ٔـ as in يَسْـَٔلُونَ, شَيْـًٔا)
    static const QRegularExpression hamzaTatweelProtRx(QStringLiteral("(\\x{0640}[\\x{064B}-\\x{065F}]*[\\x{0654}\\x{0655}]|[\\x{0654}\\x{0655}][\\x{064B}-\\x{065F}]*\\x{0640})"));
    int pos = 0;
    while (true) {
        QRegularExpressionMatch m = hamzaTatweelProtRx.match(result, pos);
        if (!m.hasMatch()) break;
        QString matched = m.captured(1);
        matched.replace(QChar(0x0640), QChar(0xE000));
        result.replace(m.capturedStart(1), m.capturedLength(1), matched);
        pos = m.capturedStart(1) + matched.length();
    }

    if (riwayah != 2) {
        // Fix broken yaa + tatweel + hamza sequences in raw text (e.g. Hafs: يُنَبِّيـُٔهُمُ -> يُنَبِّئُهُمُ, جِيـْٔتَ -> جِئْتَ)
        static const QRegularExpression yaaHamzaRx(QStringLiteral("\\x{064A}[\\x{0640}\\x{E000}]\\x{0654}"));
        result.replace(yaaHamzaRx, QString::fromUtf8("\u0626"));
        result.replace(QString::fromUtf8("\u064A\u0654"), QString::fromUtf8("\u0626"));
    }

    // Remove any leftover isolated tatweels that break word appearance into long stretched lines
    result.remove(QChar(0x0640));

    // Restore protected tatweels in hamza ligatures
    result.replace(QChar(0xE000), QChar(0x0640));

    return result;
}

QVariantList QuranManager::getAyahsForSurah(int surahNumber)
{
    QVariantList list;
    if (!m_db.isOpen()) return list;

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT ayah_number, text_uthmani, page_number, juz_number, hizb_number, rub_number, sajda, text_tajweed FROM ayahs WHERE riwayah_id = ? AND surah_number = ? ORDER BY ayah_number ASC"));
    q.addBindValue(m_riwayah);
    q.addBindValue(surahNumber);

    if (q.exec()) {
        while (q.next()) {
            QVariantMap m;
            int aNum = q.value(0).toInt();
            m[QStringLiteral("surah_number")] = surahNumber;
            m[QStringLiteral("ayah_number")] = aNum;
            m[QStringLiteral("text_uthmani")] = cleanUthmaniText(q.value(1).toString(), m_riwayah);
            int pNum = getPageForAyah(surahNumber, aNum, m_riwayah);
            if (pNum <= 0) pNum = q.value(2).toInt();
            m[QStringLiteral("page_number")] = pNum;
            m[QStringLiteral("juz_number")] = q.value(3).toInt();
            m[QStringLiteral("hizb_number")] = q.value(4).toInt();
            m[QStringLiteral("rub_number")] = q.value(5).toInt();
            m[QStringLiteral("sajda")] = q.value(6).toInt() == 1;
            m[QStringLiteral("text_tajweed")] = q.value(7).toString();
            m[QStringLiteral("isBookmarked")] = isBookmarked(surahNumber, aNum);
            list.append(m);
        }
    }
    return list;
}

QVariantList QuranManager::getAyahsForPage(int pageNumber)
{
    if (m_algeriaMode && m_riwayah == 2) {
        return getAyahsForAlgeriaPage(pageNumber);
    }

    QVariantList list;
    if (!m_db.isOpen()) return list;

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT a.surah_number, a.ayah_number, a.text_uthmani, a.juz_number, a.hizb_number, a.rub_number, a.sajda, s.name_ar, s.name_en, a.text_tajweed, t.start_line, t.end_line "
        "FROM ayahs a "
        "JOIN surahs s ON a.surah_number = s.number "
        "LEFT JOIN tajweed_ayah_lines t ON a.page_number = t.page_number AND a.surah_number = t.surah_number AND a.ayah_number = t.ayah_number "
        "WHERE a.riwayah_id = ? AND a.page_number = ? ORDER BY a.surah_number ASC, a.ayah_number ASC"
    ));
    q.addBindValue(m_riwayah);
    q.addBindValue(pageNumber);

    if (q.exec()) {
        while (q.next()) {
            QVariantMap m;
            int sNum = q.value(0).toInt();
            int aNum = q.value(1).toInt();
            m[QStringLiteral("surah_number")] = sNum;
            m[QStringLiteral("ayah_number")] = aNum;
            m[QStringLiteral("text_uthmani")] = cleanUthmaniText(q.value(2).toString(), m_riwayah);
            m[QStringLiteral("juz_number")] = q.value(3).toInt();
            m[QStringLiteral("hizb_number")] = q.value(4).toInt();
            m[QStringLiteral("rub_number")] = q.value(5).toInt();
            m[QStringLiteral("sajda")] = q.value(6).toInt() == 1;
            m[QStringLiteral("surah_name_ar")] = q.value(7).toString();
            m[QStringLiteral("surah_name_en")] = q.value(8).toString();
            m[QStringLiteral("text_tajweed")] = q.value(9).toString();
            m[QStringLiteral("page_number")] = pageNumber;
            m[QStringLiteral("isBookmarked")] = isBookmarked(sNum, aNum);
            if (!q.isNull(10)) {
                m[QStringLiteral("start_line")] = q.value(10).toDouble();
                m[QStringLiteral("end_line")] = q.value(11).toDouble();
            }
            list.append(m);
        }
    }
    return list;
}

int QuranManager::getPageForAyah(int surah, int ayah, int riwayahId) const
{
    if (!m_db.isOpen()) return 1;
    int rId = (riwayahId > 0) ? riwayahId : m_riwayah;
    int sNum = qBound(1, surah, 114);
    int aNum = qMax(1, ayah);

    if (m_algeriaMode && (rId == 2 || riwayahId == 0)) {
        return getAlgeriaPageForAyah(sNum, aNum);
    }

    if (rId == 2) {
        quint32 key = (static_cast<quint32>(sNum) << 16) | static_cast<quint32>(aNum);
        if (m_warshPageMap.contains(key)) {
            return m_warshPageMap.value(key);
        }
    }

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT page_number FROM ayahs WHERE riwayah_id = ? AND surah_number = ? AND ayah_number = ?"));
    q.addBindValue(rId);
    q.addBindValue(sNum);
    q.addBindValue(aNum);
    if (q.exec() && q.next()) {
        int p = q.value(0).toInt();
        if (p >= 1 && p <= 604) {
            return p;
        }
    }

    QSqlQuery qSurah(m_db);
    qSurah.prepare(QStringLiteral("SELECT start_page FROM surahs WHERE number = ?"));
    qSurah.addBindValue(sNum);
    if (qSurah.exec() && qSurah.next()) {
        int sp = qSurah.value(0).toInt();
        if (sp >= 1 && sp <= 604) {
            return sp;
        }
    }

    return 1;
}

QVariantMap QuranManager::getAyah(int surahNumber, int ayahNumber, int riwayahId)
{
    QVariantMap m;
    if (!m_db.isOpen()) return m;

    int rId = (riwayahId > 0) ? riwayahId : m_riwayah;
    int sNum = qBound(1, surahNumber, 114);

    // Surah metadata
    int totalVerses = 0;
    QSqlQuery qSurah(m_db);
    qSurah.prepare(QStringLiteral("SELECT name_ar, name_en, total_verses FROM surahs WHERE number = ?"));
    qSurah.addBindValue(sNum);
    if (qSurah.exec() && qSurah.next()) {
        m[QStringLiteral("surah_name_ar")] = qSurah.value(0).toString();
        m[QStringLiteral("surah_name_en")] = qSurah.value(1).toString();
        totalVerses = qSurah.value(2).toInt();
    }

    // Riwayah-specific verse count
    QSqlQuery qCount(m_db);
    qCount.prepare(QStringLiteral("SELECT COUNT(*) FROM ayahs WHERE riwayah_id = ? AND surah_number = ?"));
    qCount.addBindValue(rId);
    qCount.addBindValue(sNum);
    if (qCount.exec() && qCount.next()) {
        int cnt = qCount.value(0).toInt();
        if (cnt > 0) {
            totalVerses = cnt;
        }
    }
    m[QStringLiteral("total_verses")] = totalVerses;

    int effectiveAyah = (totalVerses > 0) ? qBound(1, ayahNumber, totalVerses) : qMax(1, ayahNumber);

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT a.ayah_number, a.text_uthmani, a.page_number, a.juz_number, a.hizb_number, a.rub_number, a.sajda, s.name_ar, s.name_en, a.text_tajweed FROM ayahs a JOIN surahs s ON a.surah_number = s.number WHERE a.riwayah_id = ? AND a.surah_number = ? AND a.ayah_number = ?"));
    q.addBindValue(rId);
    q.addBindValue(sNum);
    q.addBindValue(effectiveAyah);

    if (q.exec() && q.next()) {
        m[QStringLiteral("surah_number")] = sNum;
        m[QStringLiteral("ayah_number")] = q.value(0).toInt();
        m[QStringLiteral("text_uthmani")] = cleanUthmaniText(q.value(1).toString(), rId);
        int pNum = getPageForAyah(sNum, effectiveAyah, rId);
        if (pNum <= 0) pNum = q.value(2).toInt();
        m[QStringLiteral("page_number")] = pNum;
        m[QStringLiteral("juz_number")] = q.value(3).toInt();
        m[QStringLiteral("hizb_number")] = q.value(4).toInt();
        m[QStringLiteral("rub_number")] = q.value(5).toInt();
        m[QStringLiteral("sajda")] = q.value(6).toInt() == 1;
        m[QStringLiteral("surah_name_ar")] = q.value(7).toString();
        m[QStringLiteral("surah_name_en")] = q.value(8).toString();
        m[QStringLiteral("text_tajweed")] = q.value(9).toString();
        m[QStringLiteral("isBookmarked")] = isBookmarked(sNum, effectiveAyah);
    } else {
        m[QStringLiteral("surah_number")] = sNum;
        m[QStringLiteral("ayah_number")] = effectiveAyah;
    }
    return m;
}

QString QuranManager::normalizeArabic(const QString &input) const
{
    QString s = input;
    // Remove Tashkeel
    static const QRegularExpression tashkeelRx(QStringLiteral("[\\x{0617}-\\x{061A}\\x{064B}-\\x{065F}\\x{0670}\\x{06D6}-\\x{06ED}\\x{08D4}-\\x{08ED}\\x{06DF}\\x{06E0}\\x{06E2}\\x{06E3}\\x{06E5}\\x{06E6}\\x{06EA}-\\x{06EC}]"));
    s.remove(tashkeelRx);
    s.remove(QChar(0x0640)); // Tatweel
    // Normalize Alef
    static const QRegularExpression alefRx(QStringLiteral("[إأآٱ]"));
    s.replace(alefRx, QStringLiteral("ا"));
    s.replace(QStringLiteral("ءا"), QStringLiteral("ا"));
    s.replace(QChar(0x06D2), QStringLiteral("ي"));
    s.replace(QChar(0x06D3), QStringLiteral("ي"));
    s.replace(QStringLiteral("ة"), QStringLiteral("ه"));
    s.replace(QStringLiteral("ى"), QStringLiteral("ي"));

    bool startsWithSpace = s.startsWith(QLatin1Char(' '));
    bool endsWithSpace = s.endsWith(QLatin1Char(' '));
    s = s.simplified();
    if (s.isEmpty()) {
        return QString();
    }
    if (startsWithSpace) {
        s.prepend(QLatin1Char(' '));
    }
    if (endsWithSpace) {
        s.append(QLatin1Char(' '));
    }
    return s;
}

static QRegularExpression buildWordWithAffixesRegex(const QString &word, QStringList *outStems = nullptr)
{
    QString w = word.trimmed();
    QString stem = w;
    bool isSpecial = (w == QStringLiteral("الله") || w == QStringLiteral("اللهم") || w.startsWith(QStringLiteral("الذ")));
    if (!isSpecial && stem.startsWith(QStringLiteral("ال")) && stem.length() > 3) {
        stem = stem.mid(2);
    }

    QStringList stems;
    stems.append(stem);

    // Feminine taa marbuta / sound feminine plurals
    if (stem.endsWith(QStringLiteral("ه")) && stem.length() > 2) {
        stems.append(stem.left(stem.length() - 1) + QStringLiteral("ات"));
        stems.append(stem.left(stem.length() - 1) + QStringLiteral("ت"));
    } else if (stem.endsWith(QStringLiteral("ات")) && stem.length() > 3) {
        stems.append(stem.left(stem.length() - 2) + QStringLiteral("ه"));
    }

    // Common Quranic word forms (Dr. AbdulAzeez / QuranProgress)
    if (stem == QStringLiteral("كتاب")) {
        stems.append(QStringLiteral("كتب"));
    } else if (stem == QStringLiteral("رسول")) {
        stems.append(QStringLiteral("رسل"));
    } else if (stem == QStringLiteral("يوم")) {
        stems.append(QStringLiteral("ايام"));
    } else if (stem == QStringLiteral("ملك")) {
        stems.append(QStringLiteral("ملائكه"));
        stems.append(QStringLiteral("ملئكه"));
        stems.append(QStringLiteral("ملكين"));
    } else if (stem == QStringLiteral("من")) {
        stems.append(QStringLiteral("مما"));
        stems.append(QStringLiteral("ممن"));
    } else if (stem == QStringLiteral("سماء")) {
        stems.append(QStringLiteral("سموات"));
        stems.append(QStringLiteral("سماوات"));
    } else if (stem == QStringLiteral("نفس")) {
        stems.append(QStringLiteral("انفس"));
    } else if (stem == QStringLiteral("الله")) {
        stems.append(QStringLiteral("لله"));
        stems.append(QStringLiteral("اللهم"));
        stems.append(QStringLiteral("تالله"));
    } else if (stem == QStringLiteral("علم")) {
        stems.append(QStringLiteral("عالم"));
        stems.append(QStringLiteral("علوم"));
        stems.append(QStringLiteral("علماء"));
    }

    if (outStems) {
        for (const QString &s : stems) {
            if (!outStems->contains(s)) {
                outStems->append(s);
            }
        }
    }

    QStringList escaped;
    for (const QString &s : stems) {
        escaped.append(QRegularExpression::escape(s));
    }
    QString stemPat = escaped.join(QLatin1Char('|'));

    // Proclitics: و, ف, ب, ك, ل, ال and compounds (وال, فال, بال, كال, لل, ولل, فلل, ول, فل, وب, فب, وك, فك)
    // 'ت' is excluded to prevent matching verbs like 'تقوم'; swearing 'تالله' is handled in special stems.
    QString pref = QStringLiteral("(?:(?:[وف]?(?:[بلك]?ال|لل|[بلك]))|[وف])?");

    // Enclitics: pronouns, dual, plurals, tanween, verb inflections
    QString suff = QStringLiteral("(?:[هك]|ها|هم|هن|كم|كن|ي|نا|هما|كما|ون|ين|ان|ات|ه|ئذ|ا|ت|تم|تمو|تنا|وا|ني|ته|تها|تهم|تكم|ناه|ناها|ناهم)?");

    QString pattern = QStringLiteral("(?:^|\\s)%1(?:%2)%3(?=\\s|$)").arg(pref, stemPat, suff);
    return QRegularExpression(pattern);
}

static QRegularExpression getCachedAffixesRegex(const QString &word)
{
    static QHash<QString, QRegularExpression> cache;
    auto it = cache.constFind(word);
    if (it != cache.constEnd()) {
        return it.value();
    }
    QRegularExpression rx = buildWordWithAffixesRegex(word);
    if (cache.size() < 256) {
        cache.insert(word, rx);
    }
    return rx;
}

QString QuranManager::cleanTashkeelText(const QString &text) const
{
    if (text.isEmpty()) return text;
    QString s = cleanUthmaniText(text);

    // 1. Normalize Quranic sukoon \u06E1 to standard Arabic sukoon \u0652
    s.replace(QChar(0x06E1), QChar(0x0652));

    // 2. Normalize open / sequential tanweens \u08F0..\u08F2 to standard \u064B..\u064D
    s.replace(QChar(0x08F0), QChar(0x064B));
    s.replace(QChar(0x08F1), QChar(0x064C));
    s.replace(QChar(0x08F2), QChar(0x064D));

    // 3. Normalize Wasla to regular Alef
    s.replace(QChar(0x0671), QChar(0x0627));

    // 4. Remove Quranic recitation and stop marks, keep Harakat and Shaddah
    static const QRegularExpression marksRx(QStringLiteral("[\\x{06D6}-\\x{06DC}\\x{06DF}-\\x{06E0}\\x{06E2}-\\x{06E8}\\x{06EA}-\\x{06ED}\\x{08D4}-\\x{08ED}\\x{0640}]"));
    s.remove(marksRx);

    // 5. Canonicalize Shaddah + Vowel order: always Shaddah first (\u0651), then Vowel
    static const QRegularExpression vowelThenShaddahRx(QStringLiteral("([\\x{064B}-\\x{0650}\\x{0652}])\\x{0651}"));
    s.replace(vowelThenShaddahRx, QStringLiteral("\u0651\\1"));

    // 6. Normalize whitespace
    static const QRegularExpression wsRx(QStringLiteral("\\s+"));
    s.replace(wsRx, QStringLiteral(" "));

    return s.trimmed();
}

QString QuranManager::highlightSearchAyah(const QString &textUthmani, const QString &query, int searchMode, bool respectTashkeel, const QString &highlightColor, const QString &matchedWord) const
{
    if (textUthmani.isEmpty() || query.trimmed().isEmpty()) {
        return textUthmani;
    }

    QString color = highlightColor.isEmpty() ? QStringLiteral("#ffd700") : highlightColor;
    QString q = query.trimmed();
    QString normQ = normalizeArabic(q);

    QList<QRegularExpression> regexList;
    if (respectTashkeel) {
        QString cleanQ = cleanTashkeelText(q);
        if (searchMode == ExactLiteral) {
            regexList.append(QRegularExpression(QStringLiteral("(?:^|\\s)%1(?=\\s|$)").arg(QRegularExpression::escape(cleanQ))));
        } else {
            regexList.append(QRegularExpression(QRegularExpression::escape(cleanQ)));
        }
    } else {
        if (searchMode == WordWithAffixes) {
            QStringList qWords = normQ.split(QLatin1Char(' '), QString::SkipEmptyParts);
            for (const QString &qw : qWords) {
                regexList.append(getCachedAffixesRegex(qw));
            }
        } else if (searchMode == ExactLiteral) {
            regexList.append(QRegularExpression(QStringLiteral("(?:^|\\s)%1(?=\\s|$)").arg(QRegularExpression::escape(normQ))));
        } else if (searchMode == PartialMatch) {
            regexList.append(QRegularExpression(QRegularExpression::escape(normQ)));
        } else if (searchMode == RootSearch) {
            QString rootLetters;
            for (const QChar &ch : normQ) {
                if (ch.isLetter() && ch.unicode() >= 0x0600 && ch.unicode() <= 0x06FF) {
                    rootLetters.append(ch);
                }
            }
            if (rootLetters.length() >= 3) {
                if (rootLetters.length() > 4) rootLetters = rootLetters.left(4);
                if (rootLetters.length() == 3) {
                    regexList.append(QRegularExpression(QStringLiteral("(?:^|\\s)[والفبكتيمنسأإا]*?%1[اويتن]*?%2[اويتن]*?%3[هكماوناينتمةى]*(?=\\s|$)")
                                                        .arg(QString(rootLetters.at(0)), QString(rootLetters.at(1)), QString(rootLetters.at(2)))));
                } else {
                    regexList.append(QRegularExpression(QStringLiteral("(?:^|\\s)[والفبكتيمنسأإا]*?%1[اويتن]*?%2[اويتن]*?%3[اويتن]*?%4[هكماوناينتمةى]*(?=\\s|$)")
                                                        .arg(QString(rootLetters.at(0)), QString(rootLetters.at(1)), QString(rootLetters.at(2)), QString(rootLetters.at(3)))));
                }
            }
        } else if (searchMode == PhraseSearch) {
            regexList.append(QRegularExpression(QStringLiteral("(?:^|\\s)%1(?=\\s|$)").arg(QRegularExpression::escape(normQ))));
        }
    }

    QStringList words = textUthmani.split(QLatin1Char(' '), QString::SkipEmptyParts);
    const int totalWords = words.size();
    if (totalWords == 0) return textUthmani;

    // Helper lambda to check if a word matches
    auto wordMatches = [&](const QString &w) -> bool {
        if (respectTashkeel) {
            QString cleanW = cleanTashkeelText(w);
            for (const QRegularExpression &r : regexList) {
                if (r.match(cleanW).hasMatch()) return true;
            }
            return cleanW == cleanTashkeelText(q);
        } else {
            QString normW = normalizeArabic(w).trimmed();
            if (normW.isEmpty()) return false;
            if (!matchedWord.isEmpty() && normW == normalizeArabic(matchedWord).trimmed()) {
                return true;
            }
            for (const QRegularExpression &r : regexList) {
                if (r.match(normW).hasMatch()) return true;
            }
            if (searchMode == PartialMatch) {
                return normW.contains(normQ);
            }
            return normW == normQ;
        }
    };

    // Find all matching word indices
    QList<int> matchIndices;
    for (int i = 0; i < totalWords; ++i) {
        if (wordMatches(words[i])) {
            matchIndices.append(i);
        }
    }

    // Sequence check for multi-word PhraseSearch
    if (searchMode == PhraseSearch) {
        QStringList pWords = normQ.split(QLatin1Char(' '), QString::SkipEmptyParts);
        int pLen = pWords.size();
        if (pLen > 1) {
            for (int i = 0; i <= totalWords - pLen; ++i) {
                bool seqMatch = true;
                for (int j = 0; j < pLen; ++j) {
                    if (normalizeArabic(words[i + j]).trimmed() != pWords[j]) {
                        seqMatch = false;
                        break;
                    }
                }
                if (seqMatch) {
                    for (int j = 0; j < pLen; ++j) {
                        if (!matchIndices.contains(i + j)) matchIndices.append(i + j);
                    }
                }
            }
        }
    }

    const int maxWindowWords = 32;
    int startIdx = 0;
    int endIdx = totalWords;
    bool hasLeadEllipsis = false;
    bool hasTrailEllipsis = false;

    if (totalWords > maxWindowWords) {
        int firstMatch = matchIndices.isEmpty() ? 0 : matchIndices.first();
        if (firstMatch < 22) {
            startIdx = 0;
            endIdx = qMin(totalWords, maxWindowWords);
            hasLeadEllipsis = false;
            hasTrailEllipsis = (endIdx < totalWords);
        } else {
            startIdx = qMax(0, firstMatch - 8);
            endIdx = qMin(totalWords, startIdx + maxWindowWords);
            hasLeadEllipsis = (startIdx > 0);
            hasTrailEllipsis = (endIdx < totalWords);
        }
    }

    QStringList resultWords;
    if (hasLeadEllipsis) {
        resultWords.append(QStringLiteral("..."));
    }

    for (int i = startIdx; i < endIdx; ++i) {
        const QString &w = words[i];
        if (matchIndices.contains(i)) {
            resultWords.append(QStringLiteral("<font color='%1'><b>%2</b></font>").arg(color, w));
        } else {
            resultWords.append(w);
        }
    }

    if (hasTrailEllipsis) {
        resultWords.append(QStringLiteral("..."));
    }

    return resultWords.join(QLatin1Char(' '));
}

bool QuranManager::isAyahSearchTruncated(const QString &textUthmani, int maxWords) const
{
    if (textUthmani.isEmpty()) return false;
    QStringList words = textUthmani.split(QLatin1Char(' '), QString::SkipEmptyParts);
    return words.size() > maxWords;
}

QVariantList QuranManager::search(const QString &query, int surahFilter)
{
    return searchAdvanced(query, WordWithAffixes, surahFilter > 0 ? ScopeSurah : ScopeAll, surahFilter);
}

QVariantList QuranManager::searchAdvanced(const QString &query, int searchMode, int scopeType, int scopeValue, const QString &translationEdition, bool respectTashkeel)
{
    QVariantList list;
    if (!m_db.isOpen()) return list;

    // Translation search mode (Mode 5)
    if (searchMode == TranslationSearch) {
        QString clean = query.trimmed();
        if (clean.length() < 2) return list;

        // tafsir_translations rows are indexed by Hafs verse numbering (1..6236).
        // Using CROSS JOIN forces SQLite to filter tafsir_translations first via text LIKE,
        // and then look up ayahs/surahs using primary/indexed keys, avoiding a 194M comparison full join scan.
        QString sql = QStringLiteral(
            "SELECT a.surah_number, a.ayah_number, a.text_uthmani, a.page_number, "
            "s.name_ar, s.name_en, t.text, t.edition_id, t.edition_name_ar, t.edition_name_en, t.language "
            "FROM tafsir_translations t "
            "CROSS JOIN ayahs a ON a.riwayah_id = 1 AND a.surah_number = t.surah_number AND a.ayah_number = t.ayah_number "
            "JOIN surahs s ON s.number = t.surah_number "
            "WHERE 1=1 "
        );

        QVariantMap binds;

        if (scopeType == ScopeSurah && scopeValue > 0) {
            sql += QStringLiteral(" AND t.surah_number = :scopeSurah");
            binds[QStringLiteral(":scopeSurah")] = scopeValue;
        } else if (scopeType == ScopeJuz && scopeValue > 0) {
            sql += QStringLiteral(" AND a.juz_number = :scopeJuz");
            binds[QStringLiteral(":scopeJuz")] = scopeValue;
        } else if (scopeType == ScopePage && scopeValue > 0) {
            sql += QStringLiteral(" AND a.page_number = :scopePage");
            binds[QStringLiteral(":scopePage")] = scopeValue;
        }

        if (!translationEdition.isEmpty() && translationEdition != QStringLiteral("all")) {
            sql += QStringLiteral(" AND t.edition_id = :editionId");
            binds[QStringLiteral(":editionId")] = translationEdition;
        }

        // Support accent-insensitive search for Latin languages (e.g. moise matches Moïse, pelerinage matches pèlerinage)
        bool hasLatin = false;
        for (const QChar &ch : clean) {
            if ((ch >= QLatin1Char('a') && ch <= QLatin1Char('z')) || (ch >= QLatin1Char('A') && ch <= QLatin1Char('Z'))) {
                hasLatin = true;
                break;
            }
        }
        QString wild;
        if (hasLatin && clean.length() >= 3) {
            static const QRegularExpression accentVowels(QStringLiteral("[aáàâäeéèêëiíîïoóôöuúûücç]"), QRegularExpression::CaseInsensitiveOption);
            wild = clean;
            wild.replace(accentVowels, QStringLiteral("_"));
        }

        if (!wild.isEmpty() && wild != clean) {
            sql += QStringLiteral(" AND (t.text LIKE :pattern OR t.text LIKE :wildPattern) ");
            binds[QStringLiteral(":pattern")] = QStringLiteral("%%1%").arg(clean);
            binds[QStringLiteral(":wildPattern")] = QStringLiteral("%%1%").arg(wild);
        } else {
            sql += QStringLiteral(" AND t.text LIKE :pattern ");
            binds[QStringLiteral(":pattern")] = QStringLiteral("%%1%").arg(clean);
        }

        sql += QStringLiteral(" ORDER BY t.surah_number ASC, t.ayah_number ASC");

        QSqlQuery q(m_db);
        q.prepare(sql);
        for (auto it = binds.begin(); it != binds.end(); ++it) {
            q.bindValue(it.key(), it.value());
        }

        static auto stripDiacritics = [](const QString &str) -> QString {
            QString norm = str.normalized(QString::NormalizationForm_D);
            QString out;
            out.reserve(norm.size());
            for (const QChar &ch : norm) {
                if (ch.category() != QChar::Mark_NonSpacing) {
                    out.append(ch);
                }
            }
            return out;
        };

        QString normQuery = stripDiacritics(clean).toLower();

        if (q.exec()) {
            while (q.next()) {
                QString transText = q.value(6).toString();
                // Filter out false positives from single-char wildcards
                if (!wild.isEmpty() && wild != clean && !transText.contains(clean, Qt::CaseInsensitive)) {
                    QString normTrans = stripDiacritics(transText).toLower();
                    if (!normTrans.contains(normQuery)) {
                        continue;
                    }
                }

                int sNum = q.value(0).toInt();
                int hAyah = q.value(1).toInt();
                int effAyah = hAyah;
                int effPage = q.value(3).toInt();

                // If user is currently in Warsh, map verse number and page to Warsh instantly in memory
                if (m_riwayah == 2) {
                    effAyah = mapHafsToWarsh(sNum, hAyah);
                    quint32 wKey = (static_cast<quint32>(sNum) << 16) | static_cast<quint32>(effAyah);
                    effPage = m_warshPageMap.value(wKey, static_cast<quint16>(effPage));
                }

                QVariantMap m;
                m[QStringLiteral("surah_number")] = sNum;
                m[QStringLiteral("ayah_number")] = effAyah;
                m[QStringLiteral("hafs_ayah_number")] = hAyah;
                m[QStringLiteral("text_uthmani")] = cleanUthmaniText(q.value(2).toString(), m_riwayah);
                m[QStringLiteral("page_number")] = effPage;
                m[QStringLiteral("surah_name_ar")] = q.value(4).toString();
                m[QStringLiteral("surah_name_en")] = q.value(5).toString();
                m[QStringLiteral("translation_text")] = transText;
                m[QStringLiteral("edition_id")] = q.value(7).toString();
                QString edAr = q.value(8).toString();
                QString edEn = q.value(9).toString();
                m[QStringLiteral("edition_name_ar")] = edAr;
                m[QStringLiteral("edition_name_en")] = edEn;
                m[QStringLiteral("edition_name")] = !edEn.isEmpty() ? edEn : edAr;
                m[QStringLiteral("language")] = q.value(10).toString();
                m[QStringLiteral("occurrence_count")] = 1;
                list.append(m);
            }
        }
        return list;
    }

    // Arabic Root Search Mode (Mode 3)
    if (searchMode == RootSearch) {
        QString norm = normalizeArabic(query);
        QString rootLetters;
        for (const QChar &ch : norm) {
            if (ch.isLetter() && ch.unicode() >= 0x0600 && ch.unicode() <= 0x06FF) {
                rootLetters.append(ch);
            }
        }
        if (rootLetters.length() < 3) return list;
        if (rootLetters.length() > 4) rootLetters = rootLetters.left(4);

        QString sql = QStringLiteral(
            "SELECT a.surah_number, a.ayah_number, a.text_uthmani, a.page_number, "
            "s.name_ar, s.name_en, a.text_search "
            "FROM ayahs a "
            "JOIN surahs s ON a.surah_number = s.number "
            "WHERE a.riwayah_id = :riwayah "
        );

        QVariantMap binds;
        binds[QStringLiteral(":riwayah")] = m_riwayah;

        if (scopeType == ScopeSurah && scopeValue > 0) {
            sql += QStringLiteral(" AND a.surah_number = :scopeSurah");
            binds[QStringLiteral(":scopeSurah")] = scopeValue;
        } else if (scopeType == ScopeJuz && scopeValue > 0) {
            sql += QStringLiteral(" AND a.juz_number = :scopeJuz");
            binds[QStringLiteral(":scopeJuz")] = scopeValue;
        } else if (scopeType == ScopePage && scopeValue > 0) {
            sql += QStringLiteral(" AND a.page_number = :scopePage");
            binds[QStringLiteral(":scopePage")] = scopeValue;
        }

        QRegularExpression rx;
        if (rootLetters.length() == 3) {
            QChar r1 = rootLetters[0];
            QChar r2 = rootLetters[1];
            QChar r3 = rootLetters[2];
            sql += QStringLiteral(" AND a.text_search LIKE :likePrefilter");
            binds[QStringLiteral(":likePrefilter")] = QStringLiteral("%%1%%2%%3%").arg(r1).arg(r2).arg(r3);

            QString pattern = QStringLiteral("(?:^|\\s)[والفبكتيمنسأإا]*?%1[اويتن]*?%2[اويتن]*?%3[هكماوناينتمةى]*(?=\\s|$)")
                              .arg(r1).arg(r2).arg(r3);
            rx.setPattern(pattern);
        } else {
            QChar r1 = rootLetters[0];
            QChar r2 = rootLetters[1];
            QChar r3 = rootLetters[2];
            QChar r4 = rootLetters[3];
            sql += QStringLiteral(" AND a.text_search LIKE :likePrefilter");
            binds[QStringLiteral(":likePrefilter")] = QStringLiteral("%%1%%2%%3%%4%").arg(r1).arg(r2).arg(r3).arg(r4);

            QString pattern = QStringLiteral("(?:^|\\s)[والفبكتيمنسأإا]*?%1[اويتن]*?%2[اويتن]*?%3[اويتن]*?%4[هكماوناينتمةى]*(?=\\s|$)")
                              .arg(r1).arg(r2).arg(r3).arg(r4);
            rx.setPattern(pattern);
        }

        sql += QStringLiteral(" ORDER BY a.surah_number ASC, a.ayah_number ASC");

        QSqlQuery q(m_db);
        q.prepare(sql);
        for (auto it = binds.begin(); it != binds.end(); ++it) {
            q.bindValue(it.key(), it.value());
        }

        if (q.exec()) {
            while (q.next()) {
                QString textSearch = q.value(6).toString();
                QRegularExpressionMatchIterator it = rx.globalMatch(textSearch);
                int occCount = 0;
                QString matchedWord;
                while (it.hasNext()) {
                    QRegularExpressionMatch m = it.next();
                    occCount++;
                    if (matchedWord.isEmpty()) {
                        matchedWord = m.captured(0).trimmed();
                    }
                }

                if (occCount > 0) {
                    QVariantMap m;
                    m[QStringLiteral("surah_number")] = q.value(0).toInt();
                    m[QStringLiteral("ayah_number")] = q.value(1).toInt();
                    m[QStringLiteral("text_uthmani")] = cleanUthmaniText(q.value(2).toString(), m_riwayah);
                    m[QStringLiteral("page_number")] = getPageForAyah(q.value(0).toInt(), q.value(1).toInt(), m_riwayah);
                    m[QStringLiteral("surah_name_ar")] = q.value(4).toString();
                    m[QStringLiteral("surah_name_en")] = q.value(5).toString();
                    m[QStringLiteral("matched_word")] = matchedWord;
                    m[QStringLiteral("occurrence_count")] = occCount;
                    list.append(m);
                }
            }
        }
        return list;
    }

    // Word With Affixes Mode (Mode 0 - standard Qur'anic word search matching QuranProgress / Dr. AbdulAzeez)
    if (searchMode == WordWithAffixes) {
        QString norm = normalizeArabic(query).trimmed();
        if (norm.length() < 2) return list;

        QStringList words = norm.split(QLatin1Char(' '), QString::SkipEmptyParts);
        if (words.isEmpty()) return list;

        QList<QRegularExpression> regexList;
        QStringList allStems;
        for (const QString &w : words) {
            regexList.append(buildWordWithAffixesRegex(w, &allStems));
        }

        QString sql = QStringLiteral(
            "SELECT a.surah_number, a.ayah_number, a.text_uthmani, a.page_number, "
            "s.name_ar, s.name_en, a.text_search "
            "FROM ayahs a "
            "JOIN surahs s ON a.surah_number = s.number "
            "WHERE a.riwayah_id = :riwayah "
        );

        QVariantMap binds;
        binds[QStringLiteral(":riwayah")] = m_riwayah;

        if (scopeType == ScopeSurah && scopeValue > 0) {
            sql += QStringLiteral(" AND a.surah_number = :scopeSurah");
            binds[QStringLiteral(":scopeSurah")] = scopeValue;
        } else if (scopeType == ScopeJuz && scopeValue > 0) {
            sql += QStringLiteral(" AND a.juz_number = :scopeJuz");
            binds[QStringLiteral(":scopeJuz")] = scopeValue;
        } else if (scopeType == ScopePage && scopeValue > 0) {
            sql += QStringLiteral(" AND a.page_number = :scopePage");
            binds[QStringLiteral(":scopePage")] = scopeValue;
        }

        if (!allStems.isEmpty()) {
            QStringList stemLikes;
            for (int i = 0; i < allStems.size(); ++i) {
                QString pName = QStringLiteral(":stem%1").arg(i);
                stemLikes.append(QStringLiteral("a.text_search LIKE %1").arg(pName));
                binds[pName] = QStringLiteral("%%1%").arg(allStems[i]);
            }
            sql += QStringLiteral(" AND (%1)").arg(stemLikes.join(QStringLiteral(" OR ")));
        }

        sql += QStringLiteral(" ORDER BY a.surah_number ASC, a.ayah_number ASC");

        QSqlQuery q(m_db);
        q.prepare(sql);
        for (auto it = binds.begin(); it != binds.end(); ++it) {
            q.bindValue(it.key(), it.value());
        }

        if (q.exec()) {
            while (q.next()) {
                QString textSearch = q.value(6).toString();
                bool allMatched = true;
                QString firstMatchedWord;
                int totalOccInAyah = 0;

                for (const QRegularExpression &rx : regexList) {
                    QRegularExpressionMatchIterator it = rx.globalMatch(textSearch);
                    int countForThisWord = 0;
                    while (it.hasNext()) {
                        QRegularExpressionMatch m = it.next();
                        countForThisWord++;
                        if (firstMatchedWord.isEmpty()) {
                            firstMatchedWord = m.captured(0).trimmed();
                        }
                    }
                    if (countForThisWord == 0) {
                        allMatched = false;
                        break;
                    }
                    totalOccInAyah += countForThisWord;
                }

                if (allMatched) {
                    int occCount = totalOccInAyah > 0 ? totalOccInAyah : 1;
                    QString matchedWord = firstMatchedWord;

                    if (respectTashkeel) {
                        QString cleanVerse = cleanTashkeelText(q.value(2).toString());
                        QString cleanQuery = cleanTashkeelText(query);
                        if (!cleanQuery.isEmpty()) {
                            int occ = 0;
                            int pos = 0;
                            while ((pos = cleanVerse.indexOf(cleanQuery, pos)) != -1) {
                                occ++;
                                pos += cleanQuery.length();
                            }
                            if (occ == 0) {
                                continue;
                            }
                            occCount = occ;
                            matchedWord = cleanQuery;
                        }
                    }

                    QVariantMap m;
                    m[QStringLiteral("surah_number")] = q.value(0).toInt();
                    m[QStringLiteral("ayah_number")] = q.value(1).toInt();
                    m[QStringLiteral("text_uthmani")] = cleanUthmaniText(q.value(2).toString(), m_riwayah);
                    m[QStringLiteral("page_number")] = getPageForAyah(q.value(0).toInt(), q.value(1).toInt(), m_riwayah);
                    m[QStringLiteral("surah_name_ar")] = q.value(4).toString();
                    m[QStringLiteral("surah_name_en")] = q.value(5).toString();
                    m[QStringLiteral("matched_word")] = matchedWord;
                    m[QStringLiteral("occurrence_count")] = occCount;
                    list.append(m);
                }
            }
        }
        return list;
    }

    // ExactLiteral (1), PartialMatch (2), PhraseSearch (4)
    QString norm = normalizeArabic(query).trimmed();
    if (norm.length() < 2) return list;

    QString sql = QStringLiteral(
        "SELECT a.surah_number, a.ayah_number, a.text_uthmani, a.page_number, "
        "s.name_ar, s.name_en, a.text_search "
        "FROM ayahs a "
        "JOIN surahs s ON a.surah_number = s.number "
        "WHERE a.riwayah_id = :riwayah "
    );

    QVariantMap binds;
    binds[QStringLiteral(":riwayah")] = m_riwayah;

    if (scopeType == ScopeSurah && scopeValue > 0) {
        sql += QStringLiteral(" AND a.surah_number = :scopeSurah");
        binds[QStringLiteral(":scopeSurah")] = scopeValue;
    } else if (scopeType == ScopeJuz && scopeValue > 0) {
        sql += QStringLiteral(" AND a.juz_number = :scopeJuz");
        binds[QStringLiteral(":scopeJuz")] = scopeValue;
    } else if (scopeType == ScopePage && scopeValue > 0) {
        sql += QStringLiteral(" AND a.page_number = :scopePage");
        binds[QStringLiteral(":scopePage")] = scopeValue;
    }

    if (searchMode == ExactLiteral) {
        QStringList words = norm.split(QLatin1Char(' '), QString::SkipEmptyParts);
        for (int i = 0; i < words.size(); ++i) {
            QString paramName = QStringLiteral(":w%1").arg(i);
            sql += QStringLiteral(" AND (' ' || a.text_search || ' ') LIKE %1").arg(paramName);
            binds[paramName] = QStringLiteral("%%1%").arg(QStringLiteral(" %1 ").arg(words[i]));
        }
    } else if (searchMode == PhraseSearch) {
        sql += QStringLiteral(" AND (' ' || a.text_search || ' ') LIKE :phrase");
        binds[QStringLiteral(":phrase")] = QStringLiteral("%%1%").arg(QStringLiteral(" %1 ").arg(norm));
    } else { // PartialMatch
        sql += QStringLiteral(" AND a.text_search LIKE :partial");
        binds[QStringLiteral(":partial")] = QStringLiteral("%%1%").arg(norm);
    }

    sql += QStringLiteral(" ORDER BY a.surah_number ASC, a.ayah_number ASC");

    QSqlQuery q(m_db);
    q.prepare(sql);
    for (auto it = binds.begin(); it != binds.end(); ++it) {
        q.bindValue(it.key(), it.value());
    }

    if (q.exec()) {
        while (q.next()) {
            QVariantMap m;
            m[QStringLiteral("surah_number")] = q.value(0).toInt();
            m[QStringLiteral("ayah_number")] = q.value(1).toInt();
            m[QStringLiteral("text_uthmani")] = cleanUthmaniText(q.value(2).toString(), m_riwayah);
            m[QStringLiteral("page_number")] = getPageForAyah(q.value(0).toInt(), q.value(1).toInt(), m_riwayah);
            m[QStringLiteral("surah_name_ar")] = q.value(4).toString();
            m[QStringLiteral("surah_name_en")] = q.value(5).toString();

            if (respectTashkeel) {
                QString cleanVerse = cleanTashkeelText(q.value(2).toString());
                QString cleanQuery = cleanTashkeelText(query);
                int countInAyah = 0;

                if (searchMode == ExactLiteral) {
                    QRegularExpression exactRx(QStringLiteral("(?:^|\\s)%1(?=\\s|$)").arg(QRegularExpression::escape(cleanQuery)));
                    QRegularExpressionMatchIterator it = exactRx.globalMatch(cleanVerse);
                    while (it.hasNext()) {
                        it.next();
                        countInAyah++;
                    }
                } else {
                    int pos = 0;
                    while ((pos = cleanVerse.indexOf(cleanQuery, pos)) != -1) {
                        countInAyah++;
                        pos += cleanQuery.length();
                    }
                }

                if (countInAyah == 0) {
                    continue;
                }
                m[QStringLiteral("occurrence_count")] = countInAyah;
                list.append(m);
                continue;
            }

            // Calculate occurrence count in ayah (non-tashkeel mode)
            QString textSearch = q.value(6).toString();
            int countInAyah = 0;
            int pos = 0;
            while ((pos = textSearch.indexOf(norm, pos)) != -1) {
                countInAyah++;
                pos += norm.length();
            }
            m[QStringLiteral("occurrence_count")] = countInAyah > 0 ? countInAyah : 1;
            list.append(m);
        }
    }

    return list;
}

QVariantMap QuranManager::getSearchStats(const QString &query, int searchMode, bool respectTashkeel, const QString &translationEdition)
{
    QVariantMap res;
    if (!m_db.isOpen()) return res;

    // Retrieve full matching set
    QVariantList matches = searchAdvanced(query, searchMode, ScopeAll, 0, translationEdition, respectTashkeel);
    if (matches.isEmpty()) {
        res[QStringLiteral("query")] = query;
        res[QStringLiteral("totalOccurrences")] = 0;
        res[QStringLiteral("totalVerses")] = 0;
        res[QStringLiteral("surahsCount")] = 0;
        res[QStringLiteral("surahs")] = QVariantList();
        return res;
    }

    struct SurahStat {
        int surahNumber;
        QString nameAr;
        QString nameEn;
        QString revelationType;
        int startPage;
        int totalVerses;
        int ayahCount = 0;
        int occurrenceCount = 0;
    };

    QMap<int, SurahStat> statsMap;
    int totalOccurrences = 0;
    int totalVerses = 0;
    int makkiOccurrences = 0;
    int madaniOccurrences = 0;

    for (const QVariant &itemVar : matches) {
        QVariantMap item = itemVar.toMap();
        int sNum = item.value(QStringLiteral("surah_number")).toInt();
        int occInAyah = item.value(QStringLiteral("occurrence_count"), 1).toInt();
        if (occInAyah <= 0) occInAyah = 1;

        if (!statsMap.contains(sNum)) {
            QVariantMap sInfo = getSurah(sNum);
            SurahStat st;
            st.surahNumber = sNum;
            st.nameAr = sInfo.value(QStringLiteral("name_ar")).toString();
            st.nameEn = sInfo.value(QStringLiteral("name_en")).toString();
            st.revelationType = sInfo.value(QStringLiteral("revelation_type")).toString();
            st.startPage = sInfo.value(QStringLiteral("start_page")).toInt();
            st.totalVerses = sInfo.value(QStringLiteral("total_verses")).toInt();
            statsMap.insert(sNum, st);
        }

        statsMap[sNum].ayahCount += 1;
        statsMap[sNum].occurrenceCount += occInAyah;
        totalOccurrences += occInAyah;
        totalVerses += 1;

        if (statsMap[sNum].revelationType == QStringLiteral("Meccan")) {
            makkiOccurrences += occInAyah;
        } else {
            madaniOccurrences += occInAyah;
        }
    }

    QList<SurahStat> list = statsMap.values();
    std::sort(list.begin(), list.end(), [](const SurahStat &a, const SurahStat &b) {
        if (a.occurrenceCount != b.occurrenceCount) {
            return a.occurrenceCount > b.occurrenceCount;
        }
        return a.surahNumber < b.surahNumber;
    });

    int maxSurahOccurrences = list.isEmpty() ? 0 : list.first().occurrenceCount;
    QString topSurahName = list.isEmpty() ? QString() : list.first().nameAr;

    QVariantList surahsList;
    for (const SurahStat &st : list) {
        QVariantMap sm;
        sm[QStringLiteral("surah_number")] = st.surahNumber;
        sm[QStringLiteral("name_ar")] = st.nameAr;
        sm[QStringLiteral("name_en")] = st.nameEn;
        sm[QStringLiteral("revelation_type")] = st.revelationType;
        sm[QStringLiteral("start_page")] = st.startPage;
        sm[QStringLiteral("total_verses")] = st.totalVerses;
        sm[QStringLiteral("ayah_count")] = st.ayahCount;
        sm[QStringLiteral("occurrence_count")] = st.occurrenceCount;

        double pct = (totalOccurrences > 0) ? ((double)st.occurrenceCount * 100.0 / totalOccurrences) : 0.0;
        sm[QStringLiteral("percentage")] = pct;
        sm[QStringLiteral("percentage_str")] = QString::number(pct, 'f', 1);
        sm[QStringLiteral("bar_ratio")] = (maxSurahOccurrences > 0) ? ((double)st.occurrenceCount / (double)maxSurahOccurrences) : 0.0;
        surahsList.append(sm);
    }

    res[QStringLiteral("query")] = query;
    res[QStringLiteral("totalOccurrences")] = totalOccurrences;
    res[QStringLiteral("totalVerses")] = totalVerses;
    res[QStringLiteral("surahsCount")] = list.size();
    res[QStringLiteral("makkiOccurrences")] = makkiOccurrences;
    res[QStringLiteral("madaniOccurrences")] = madaniOccurrences;
    double makkiPct = (totalOccurrences > 0) ? ((double)makkiOccurrences * 100.0 / totalOccurrences) : 0.0;
    double madaniPct = (totalOccurrences > 0) ? ((double)madaniOccurrences * 100.0 / totalOccurrences) : 0.0;
    res[QStringLiteral("makkiPercentage")] = QString::number(makkiPct, 'f', 1);
    res[QStringLiteral("madaniPercentage")] = QString::number(madaniPct, 'f', 1);
    res[QStringLiteral("maxSurahOccurrences")] = maxSurahOccurrences;
    res[QStringLiteral("topSurahName")] = topSurahName;
    res[QStringLiteral("surahs")] = surahsList;
    res[QStringLiteral("respectTashkeel")] = respectTashkeel;

    return res;
}


QVariantList QuranManager::getAvailableTafsirEditions() const
{
    QVariantList list;
    if (!m_db.isOpen()) return list;

    QSqlQuery q(QStringLiteral("SELECT DISTINCT edition_id, edition_name_ar, edition_name_en, edition_type, language FROM tafsir_translations ORDER BY CASE WHEN language = 'ar' THEN 0 ELSE 1 END, id ASC"), m_db);
    while (q.next()) {
        QVariantMap m;
        m[QStringLiteral("id")] = q.value(0).toString();
        m[QStringLiteral("name_ar")] = q.value(1).toString();
        m[QStringLiteral("name_en")] = q.value(2).toString();
        m[QStringLiteral("type")] = q.value(3).toString();
        m[QStringLiteral("language")] = q.value(4).toString();
        list.append(m);
    }
    return list;
}

QString QuranManager::getAyahTafsir(int surah, int ayah, const QString &editionId, int riwayahId) const
{
    if (!m_db.isOpen()) return QString();

    QString edId = editionId.isEmpty() ? m_selectedTafsirEditionId : editionId;
    if (edId.isEmpty()) edId = QStringLiteral("ar.muyassar");

    int rId = (riwayahId > 0) ? riwayahId : m_riwayah;
    int sNum = qBound(1, surah, 114);

    // Get max verses in this surah for this riwayah
    int maxVerses = 0;
    QSqlQuery qCount(m_db);
    qCount.prepare(QStringLiteral("SELECT COUNT(*) FROM ayahs WHERE riwayah_id = ? AND surah_number = ?"));
    qCount.addBindValue(rId);
    qCount.addBindValue(sNum);
    if (qCount.exec() && qCount.next()) {
        maxVerses = qCount.value(0).toInt();
    }
    int effAyah = (maxVerses > 0) ? qBound(1, ayah, maxVerses) : qMax(1, ayah);

    int startAyah = effAyah;
    int endAyah = effAyah;

    if (rId == 2) { // Warsh
        quint32 key = (static_cast<quint32>(sNum) << 16) | static_cast<quint32>(effAyah);
        if (m_warshToHafsMap.contains(key)) {
            const HafsRange &r = m_warshToHafsMap.value(key);
            startAyah = r.start;
            endAyah = r.end;
        }
    }

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT text FROM tafsir_translations WHERE edition_id = ? AND surah_number = ? AND ayah_number >= ? AND ayah_number <= ? ORDER BY ayah_number ASC"));
    q.addBindValue(edId);
    q.addBindValue(sNum);
    q.addBindValue(startAyah);
    q.addBindValue(endAyah);

    QStringList parts;
    if (q.exec()) {
        while (q.next()) {
            QString t = q.value(0).toString().trimmed();
            if (!t.isEmpty()) {
                parts.append(t);
            }
        }
    }
    return parts.join(QStringLiteral("\n\n"));
}

QVariantList QuranManager::getTafsirAndTranslations(int surah, int ayah, int riwayahId) const
{
    QVariantList list;
    if (!m_db.isOpen()) return list;

    int rId = (riwayahId > 0) ? riwayahId : m_riwayah;
    int sNum = qBound(1, surah, 114);

    // Get max verses in this surah for this riwayah
    int maxVerses = 0;
    QSqlQuery qCount(m_db);
    qCount.prepare(QStringLiteral("SELECT COUNT(*) FROM ayahs WHERE riwayah_id = ? AND surah_number = ?"));
    qCount.addBindValue(rId);
    qCount.addBindValue(sNum);
    if (qCount.exec() && qCount.next()) {
        maxVerses = qCount.value(0).toInt();
    }
    int effAyah = (maxVerses > 0) ? qBound(1, ayah, maxVerses) : qMax(1, ayah);

    int startAyah = effAyah;
    int endAyah = effAyah;

    if (rId == 2) { // Warsh
        quint32 key = (static_cast<quint32>(sNum) << 16) | static_cast<quint32>(effAyah);
        if (m_warshToHafsMap.contains(key)) {
            const HafsRange &r = m_warshToHafsMap.value(key);
            startAyah = r.start;
            endAyah = r.end;
        }
    }

    QVariantList editions = getAvailableTafsirEditions();
    for (const QVariant &edVar : editions) {
        QVariantMap edMap = edVar.toMap();
        QString edId = edMap.value(QStringLiteral("id")).toString();

        QSqlQuery q(m_db);
        q.prepare(QStringLiteral("SELECT text FROM tafsir_translations WHERE edition_id = ? AND surah_number = ? AND ayah_number >= ? AND ayah_number <= ? ORDER BY ayah_number ASC"));
        q.addBindValue(edId);
        q.addBindValue(sNum);
        q.addBindValue(startAyah);
        q.addBindValue(endAyah);

        QStringList parts;
        if (q.exec()) {
            while (q.next()) {
                QString t = q.value(0).toString().trimmed();
                if (!t.isEmpty()) {
                    parts.append(t);
                }
            }
        }
        edMap[QStringLiteral("text")] = parts.join(QStringLiteral("\n\n"));
        list.append(edMap);
    }
    return list;
}

QString QuranManager::createTextShareFile(const QString &title, const QString &content) const
{
    Q_UNUSED(title);
    QString baseDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    if (baseDir.isEmpty()) {
        baseDir = QDir::tempPath();
    }
    QDir d(baseDir);
    d.mkpath(QStringLiteral("."));

    // Clean up any stale share files
    QStringList oldFiles = d.entryList(QStringList() << QStringLiteral("ayah_share_*.txt"), QDir::Files);
    for (const QString &old : oldFiles) {
        d.remove(old);
    }

    QString fileName = QStringLiteral("ayah_share_%1.txt").arg(QDateTime::currentMSecsSinceEpoch());
    QString filePath = d.filePath(fileName);

    QFile file(filePath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        out.setCodec("UTF-8");
        out << content;
        file.close();
    }
    return filePath;
}

QString QuranManager::getCacheDirectory(int riwayahId) const
{
    QString baseDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (baseDir.isEmpty()) {
        baseDir = QDir::homePath() + QStringLiteral("/.local/share/org.hafsoftdz/harbour-thakir");
    }
    QString rCode = (riwayahId == 2) ? QStringLiteral("warsh") : QStringLiteral("hafs");
    QString path = QStringLiteral("%1/quran_svg/%2").arg(baseDir, rCode);
    QDir().mkpath(path);
    return path;
}

QString QuranManager::getRenderedPagesCacheDir() const
{
    QString baseDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (baseDir.isEmpty()) {
        baseDir = QDir::homePath() + QStringLiteral("/.local/share/org.hafsoftdz/harbour-thakir");
    }
    QString path = QStringLiteral("%1/rendered_pages").arg(baseDir);
    QDir().mkpath(path);
    return path;
}

QString QuranManager::getLocalPagePath(int riwayahId, int pageNumber) const
{
    QString cacheDir = getCacheDirectory(riwayahId);
    QString userPath = QStringLiteral("%1/raw_%2.svg").arg(cacheDir, QString::number(pageNumber));
    if (QFile::exists(userPath)) {
        return userPath;
    }

    QString rCode = (riwayahId == 2) ? QStringLiteral("warsh") : QStringLiteral("hafs");

    // Check SailfishApp::pathTo
    QString appPath = SailfishApp::pathTo(QStringLiteral("quran_svg/%1/raw_%2.svg").arg(rCode, QString::number(pageNumber))).toLocalFile();
    if (QFile::exists(appPath)) {
        return appPath;
    }

    // Check standard /usr/share path
    QString bundled = QStringLiteral("/usr/share/harbour-thakir/quran_svg/%1/raw_%2.svg").arg(rCode, QString::number(pageNumber));
    if (QFile::exists(bundled)) {
        return bundled;
    }

    return userPath;
}

QString QuranManager::getRemotePageUrl(int riwayahId, int pageNumber) const
{
    QString rCode = (riwayahId == 2) ? QStringLiteral("warsh") : QStringLiteral("hafs");
    return QStringLiteral("https://quranpedia.net/api/page/%1/%2").arg(rCode).arg(pageNumber);
}

QString QuranManager::getTajweedPagesCacheDir(int riwayahId) const
{
    QString rCode = (riwayahId == 2) ? QStringLiteral("warsh") : QStringLiteral("hafs");
    QString baseDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (baseDir.isEmpty()) {
        baseDir = QDir::homePath() + QStringLiteral("/.local/share/org.hafsoftdz/harbour-thakir");
    }
    QString path = QStringLiteral("%1/quran_tajweed_pages/%2").arg(baseDir, rCode);
    QDir().mkpath(path);
    return path;
}

QString QuranManager::getLocalTajweedPagePath(int riwayahId, int pageNumber, bool hd) const
{
    QString rCode = (riwayahId == 2) ? QStringLiteral("warsh") : QStringLiteral("hafs");
    QString cacheDir = getTajweedPagesCacheDir(riwayahId);
    QString exactName = hd ? QStringLiteral("page_%1_hd.jpg").arg(QString::number(pageNumber))
                           : QStringLiteral("page_%1.jpg").arg(QString::number(pageNumber));
    QString userPath = QStringLiteral("%1/%2").arg(cacheDir, exactName);
    if (QFile::exists(userPath)) {
        return userPath;
    }

    // Check SailfishApp::pathTo
    QString bundledExact = hd ? QStringLiteral("data/quran_tajweed/%1/page_%2_hd.jpg").arg(rCode, QString::number(pageNumber))
                              : QStringLiteral("data/quran_tajweed/%1/page_%2.jpg").arg(rCode, QString::number(pageNumber));
    QString appPath = SailfishApp::pathTo(bundledExact).toLocalFile();
    if (QFile::exists(appPath)) {
        return appPath;
    }

    // Check standard /usr/share path
    QString bundledPath = QStringLiteral("/usr/share/harbour-thakir/%1").arg(bundledExact);
    if (QFile::exists(bundledPath)) {
        return bundledPath;
    }

    // Fallback: if requested resolution is missing, check alternative resolution
    QString altName = hd ? QStringLiteral("page_%1.jpg").arg(QString::number(pageNumber))
                         : QStringLiteral("page_%1_hd.jpg").arg(QString::number(pageNumber));
    QString altUserPath = QStringLiteral("%1/%2").arg(cacheDir, altName);
    if (QFile::exists(altUserPath)) {
        return altUserPath;
    }

    return userPath;
}

QString QuranManager::getRemoteTajweedPageUrl(int riwayahId, int pageNumber, bool hd) const
{
    if (riwayahId == 2) {
        if (hd) {
            return QStringLiteral("https://archive.org/download/moshaf-tajwed-warash/page/n%1_large.jpg").arg(pageNumber);
        } else {
            return QStringLiteral("https://archive.org/download/moshaf-tajwed-warash/page/n%1_medium.jpg").arg(pageNumber);
        }
    }
    return QString();
}

QString QuranManager::getAlgeriaPagesCacheDir() const
{
    QString baseDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (baseDir.isEmpty()) {
        baseDir = QDir::homePath() + QStringLiteral("/.local/share/org.hafsoftdz/harbour-thakir");
    }
    QString path = QStringLiteral("%1/quran_algeria_pages").arg(baseDir);
    QDir().mkpath(path);
    return path;
}

QString QuranManager::getLocalAlgeriaPagePath(int pageNumber) const
{
    QString cacheDir = getAlgeriaPagesCacheDir();
    QString exactName = QStringLiteral("page_%1.jpg").arg(QString::number(pageNumber));
    QString userPath = QStringLiteral("%1/%2").arg(cacheDir, exactName);
    if (QFile::exists(userPath)) {
        return userPath;
    }

    // Check bundled path if ever provided
    QString bundledExact = QStringLiteral("data/quran_algeria/page_%1.jpg").arg(QString::number(pageNumber));
    QString appPath = SailfishApp::pathTo(bundledExact).toLocalFile();
    if (QFile::exists(appPath)) {
        return appPath;
    }

    QString bundledPath = QStringLiteral("/usr/share/harbour-thakir/%1").arg(bundledExact);
    if (QFile::exists(bundledPath)) {
        return bundledPath;
    }

    return userPath;
}

QString QuranManager::getRemoteAlgeriaPageUrl(int pageNumber) const
{
    if (pageNumber < 1 || pageNumber > 706) return QString();
    return QStringLiteral("https://archive.org/download/QuranWarshFromNafi/page/n%1_large.jpg").arg(pageNumber);
}

bool QuranManager::isAlgeriaMushafAvailable(int riwayahId) const
{
    if (riwayahId <= 0) riwayahId = m_riwayah;
    return (riwayahId == 2);
}

bool QuranManager::isAlgeriaPageCached(int pageNumber) const
{
    if (pageNumber < 1 || pageNumber > 706) return false;
    QString exactPath = QStringLiteral("%1/page_%2.jpg").arg(getAlgeriaPagesCacheDir(), QString::number(pageNumber));
    if (QFile::exists(exactPath)) return true;
    return QFile::exists(getLocalAlgeriaPagePath(pageNumber));
}

bool QuranManager::isTajweedMushafAvailable(int riwayahId) const
{
    if (riwayahId <= 0) riwayahId = m_riwayah;
    return (riwayahId == 2);
}

bool QuranManager::isTajweedPageCached(int pageNumber, int riwayahId, bool hd) const
{
    if (pageNumber < 1 || pageNumber > 604) return false;
    if (riwayahId != 1 && riwayahId != 2) riwayahId = m_riwayah;
    QString exactName = hd ? QStringLiteral("page_%1_hd.jpg").arg(QString::number(pageNumber))
                           : QStringLiteral("page_%1.jpg").arg(QString::number(pageNumber));
    QString exactPath = QStringLiteral("%1/%2").arg(getTajweedPagesCacheDir(riwayahId), exactName);
    if (QFile::exists(exactPath)) return true;
    return QFile::exists(getLocalTajweedPagePath(riwayahId, pageNumber, hd));
}

bool QuranManager::isPageCached(int pageNumber)
{
    if (pageNumber < 1 || pageNumber > maxPages()) return false;
    if (m_algeriaMode && isAlgeriaMushafAvailable(m_riwayah)) {
        return isAlgeriaPageCached(pageNumber);
    }
    if (m_tajweedMode && isTajweedMushafAvailable(m_riwayah)) {
        return isTajweedPageCached(pageNumber, m_riwayah, m_tajweedHdMode);
    }
    return QFile::exists(getLocalPagePath(m_riwayah, pageNumber));
}

bool QuranManager::isPageDownloading(int pageNumber) const
{
    return m_activeDownloads.values().contains(pageNumber);
}

QString QuranManager::getPageImageUrl(int pageNumber)
{
    return getRenderedPageUrl(pageNumber, m_playingSurah, m_playingAyah, m_darkMode);
}

QString QuranManager::getRenderedPageUrl(int pageNumber, int highlightSurah, int highlightAyah, bool darkMode)
{
    if (pageNumber < 1 || pageNumber > 604) pageNumber = 1;

    QString rawPath = getLocalPagePath(m_riwayah, pageNumber);
    if (!QFile::exists(rawPath)) {
        preloadPage(pageNumber);
        if (pageNumber < 604) preloadPage(pageNumber + 1);
        if (pageNumber > 1) preloadPage(pageNumber - 1);
        return QString(); // Return empty string so QML displays loading indicator while downloading
    }

    // Dynamic rendering of Quranpedia SVG with verse highlight and Dark/Light palette
    QString cacheDir = getCacheDirectory(m_riwayah);
    QString renderedFileName = QStringLiteral("active_%1_%2_%3_%4.svg")
            .arg(pageNumber)
            .arg(highlightSurah)
            .arg(highlightAyah)
            .arg(darkMode ? 1 : 0);
    QString renderedPath = cacheDir + QLatin1Char('/') + renderedFileName;

    if (!QFile::exists(renderedPath)) {
        QFile inFile(rawPath);
        if (inFile.open(QIODevice::ReadOnly)) {
            QString content = QString::fromUtf8(inFile.readAll());
            inFile.close();

            // Background rect
            QString bgColor = darkMode ? QStringLiteral("#12151b") : QStringLiteral("#fffdf5");
            int svgIdx = content.indexOf(QStringLiteral("<svg"));
            int svgTagEnd = (svgIdx != -1) ? content.indexOf(QLatin1Char('>'), svgIdx) : -1;
            if (svgTagEnd != -1) {
                QString bgRect = QStringLiteral("\n<rect width=\"100%\" height=\"100%\" fill=\"%1\" />\n").arg(bgColor);
                content.insert(svgTagEnd + 1, bgRect);
            }

            // Dark mode text coloring (pure Quranpedia dark palette)
            if (darkMode) {
                content.replace(QStringLiteral("fill=\"#231f20\""), QStringLiteral("fill=\"#ede4ce\""));
                content.replace(QStringLiteral("fill=\"#000000\""), QStringLiteral("fill=\"#ede4ce\""));
                content.replace(QStringLiteral("fill=\"#1a1a1a\""), QStringLiteral("fill=\"#ede4ce\""));
            }

            // Ayah Polygon highlighting (Quranpedia signature style)
            if (highlightSurah > 0 && highlightAyah > 0) {
                QString fillColor = darkMode ? QStringLiteral("#ffd700") : QStringLiteral("#007c89");
                QString fillOp = darkMode ? QStringLiteral("0.36") : QStringLiteral("0.24");
                QString strokeColor = darkMode ? QStringLiteral("#ffe066") : QStringLiteral("#007c89");
                QString strokeWidth = darkMode ? QStringLiteral("2") : QStringLiteral("1.5");

                // Target: class="ayahPolygon" ... surah="X" ayah="Y"
                QRegExp rx(QStringLiteral("(<path[^>]*class=\"ayahPolygon\"[^>]*surah=\"%1\"[^>]*ayah=\"%2\"[^>]*>)").arg(highlightSurah).arg(highlightAyah));
                if (rx.indexIn(content) != -1) {
                    QString tag = rx.cap(1);
                    QString replacement = tag;
                    replacement.remove(QRegExp(QStringLiteral("fill-opacity=\"[^\"]*\"")));
                    replacement.remove(QRegExp(QStringLiteral("fill=\"[^\"]*\"")));
                    if (replacement.endsWith(QStringLiteral("/>"))) {
                        replacement.chop(2);
                    } else if (replacement.endsWith(QStringLiteral(">"))) {
                        replacement.chop(1);
                    }
                    replacement += QStringLiteral(" fill=\"%1\" fill-opacity=\"%2\" stroke=\"%3\" stroke-width=\"%4\" stroke-opacity=\"0.85\" />")
                            .arg(fillColor, fillOp, strokeColor, strokeWidth);
                    content.replace(tag, replacement);
                }

                // Also check reverse attribute order: ayah="Y" ... surah="X"
                QRegExp rxRev(QStringLiteral("(<path[^>]*class=\"ayahPolygon\"[^>]*ayah=\"%1\"[^>]*surah=\"%2\"[^>]*>)").arg(highlightAyah).arg(highlightSurah));
                if (rxRev.indexIn(content) != -1) {
                    QString tag = rxRev.cap(1);
                    QString replacement = tag;
                    replacement.remove(QRegExp(QStringLiteral("fill-opacity=\"[^\"]*\"")));
                    replacement.remove(QRegExp(QStringLiteral("fill=\"[^\"]*\"")));
                    if (replacement.endsWith(QStringLiteral("/>"))) {
                        replacement.chop(2);
                    } else if (replacement.endsWith(QStringLiteral(">"))) {
                        replacement.chop(1);
                    }
                    replacement += QStringLiteral(" fill=\"%1\" fill-opacity=\"%2\" stroke=\"%3\" stroke-width=\"%4\" stroke-opacity=\"0.85\" />")
                            .arg(fillColor, fillOp, strokeColor, strokeWidth);
                    content.replace(tag, replacement);
                }
            }

            QFile outFile(renderedPath);
            if (outFile.open(QIODevice::WriteOnly)) {
                outFile.write(content.toUtf8());
                outFile.close();
            }
        }
    }

    return QUrl::fromLocalFile(renderedPath).toString();
}

static int calculateBaseWeight(const QString &txt)
{
    int w = 0;
    for (const QChar &ch : txt) {
        ushort u = ch.unicode();
        // Skip Tashkeel, Quranic recitation marks, Wasla, Tatweel
        if ((u >= 0x064B && u <= 0x065F) || u == 0x0670 || (u >= 0x06D6 && u <= 0x06ED) ||
            (u >= 0x08D4 && u <= 0x08ED) || u == 0x0640) {
            continue;
        }
        w++;
    }
    return qMax(1, w);
}

static QRect detectMushafPageFrame(const QImage &img)
{
    int w = img.width();
    int h = img.height();
    if (w < 100 || h < 100) return QRect(0, 0, w, h);

    // Scanner margin paper is bright white (lum >= 225).
    // The decorative frame has dark lines or colored border (green in Tajweed, peach/brown in Algeria).
    auto isFrameOrContent = [](QRgb p) -> bool {
        int r = qRed(p);
        int g = qGreen(p);
        int b = qBlue(p);
        int lum = (299 * r + 587 * g + 114 * b) / 1000;
        // Tajweed green decorative frame
        bool isGreen = (g > 50 && (g - r) > 15 && (g - b) > 15);
        // Dark ink, decorative color, or inner page paper (lum < 215)
        return isGreen || (lum < 215);
    };

    int yStart = (int)(h * 0.15);
    int yEnd = (int)(h * 0.85);
    int yStep = 4;
    int ySamples = (yEnd - yStart) / yStep;
    int hitThresholdY = qMax(3, (int)(ySamples * 0.10));

    // 1. Left border: scan x from 2 up to w * 0.45 (robust to large binding gutter on odd pages)
    int left = 0;
    for (int x = 2; x < (int)(w * 0.45); ++x) {
        int hits = 0;
        for (int y = yStart; y < yEnd; y += yStep) {
            if (isFrameOrContent(img.pixel(x, y))) {
                hits++;
            }
        }
        if (hits >= hitThresholdY) {
            left = qMax(0, x - 2);
            break;
        }
    }

    // 2. Right border: scan x from w - 3 down to w * 0.55 (robust to large binding gutter on even pages)
    int right = w - 1;
    for (int x = w - 3; x > (int)(w * 0.55); --x) {
        int hits = 0;
        for (int y = yStart; y < yEnd; y += yStep) {
            if (isFrameOrContent(img.pixel(x, y))) {
                hits++;
            }
        }
        if (hits >= hitThresholdY) {
            right = qMin(w - 1, x + 2);
            break;
        }
    }

    int xStart = (int)(w * 0.20);
    int xEnd = (int)(w * 0.80);
    int xStep = 4;
    int xSamples = (xEnd - xStart) / xStep;
    int hitThresholdX = qMax(3, (int)(xSamples * 0.10));

    // 3. Top border: scan y from 2 up to h * 0.30
    int top = 0;
    for (int y = 2; y < (int)(h * 0.30); ++y) {
        int hits = 0;
        for (int x = xStart; x < xEnd; x += xStep) {
            if (isFrameOrContent(img.pixel(x, y))) {
                hits++;
            }
        }
        if (hits >= hitThresholdX) {
            top = qMax(0, y - 2);
            break;
        }
    }

    // 4. Bottom border: scan y from h - 3 down to h * 0.70
    int bottom = h - 1;
    for (int y = h - 3; y > (int)(h * 0.70); --y) {
        int hits = 0;
        for (int x = xStart; x < xEnd; x += xStep) {
            if (isFrameOrContent(img.pixel(x, y))) {
                hits++;
            }
        }
        if (hits >= hitThresholdX) {
            bottom = qMin(h - 1, y + 2);
            break;
        }
    }

    int cropW = right - left + 1;
    int cropH = bottom - top + 1;
    if (cropW < w / 3 || cropH < h / 3) {
        return QRect(0, 0, w, h);
    }
    return QRect(left, top, cropW, cropH);
}

static QRect detectTajweedMushafPageFrame(const QImage &img, int pageNumber)
{
    int w = img.width();
    int h = img.height();
    if (w < 100 || h < 100) return QRect(0, 0, w, h);

    int yStart = (int)(h * 0.25);
    int yEnd = (int)(h * 0.75);
    int yStep = 4;
    int samples = (yEnd - yStart) / yStep;
    int hitThresh = qMax(4, (int)(samples * 0.15));

    QVector<int> greenProfile(w, 0);
    for (int x = 0; x < w; ++x) {
        int count = 0;
        for (int y = yStart; y < yEnd; y += yStep) {
            QRgb p = img.pixel(x, y);
            int r = qRed(p);
            int g = qGreen(p);
            int b = qBlue(p);
            // Green check
            if (g > 45 && (g - r) > 15 && (g - b) > 15) {
                count++;
            }
        }
        greenProfile[x] = count;
    }

    struct Band { int start; int end; };
    QVector<Band> bands;
    bool inBand = false;
    int bStart = 0;
    for (int x = 0; x < w; ++x) {
        if (greenProfile[x] >= hitThresh && !inBand) {
            inBand = true;
            bStart = x;
        } else if (greenProfile[x] < hitThresh && inBand) {
            inBand = false;
            if (x - bStart >= 4) {
                bands.append({bStart, x});
            }
        }
    }
    if (inBand && (w - bStart >= 4)) {
        bands.append({bStart, w - 1});
    }

    double expectedDist = w * 0.825;
    int bestLeft = 0;
    int bestRight = w - 1;
    double bestScore = 999999.0;

    if (bands.size() >= 2) {
        for (int i = 0; i < bands.size(); ++i) {
            for (int j = i + 1; j < bands.size(); ++j) {
                int dist = bands[j].end - bands[i].start;
                double score = qAbs(dist - expectedDist);
                if (score < bestScore) {
                    bestScore = score;
                    bestLeft = bands[i].start;
                    bestRight = bands[j].end;
                }
            }
        }
    } else {
        bool isOdd = (pageNumber % 2 == 1);
        if (isOdd) {
            bestLeft = (int)(w * 0.020);
            bestRight = (int)(w * 0.845);
        } else {
            bestLeft = (int)(w * 0.155);
            bestRight = (int)(w * 0.985);
        }
    }

    // Top & Bottom detection
    int xMidStart = bestLeft + (int)((bestRight - bestLeft) * 0.25);
    int xMidEnd = bestLeft + (int)((bestRight - bestLeft) * 0.75);

    int top = 0;
    for (int y = 2; y < (int)(h * 0.20); ++y) {
        int count = 0;
        for (int x = xMidStart; x < xMidEnd; x += 4) {
            QRgb p = img.pixel(x, y);
            int lum = (299 * qRed(p) + 587 * qGreen(p) + 114 * qBlue(p)) / 1000;
            if (lum < 210) count++;
        }
        if (count > 5) {
            top = qMax(0, y - 2);
            break;
        }
    }

    int bottom = h - 1;
    for (int y = h - 3; y > (int)(h * 0.75); --y) {
        int count = 0;
        for (int x = xMidStart; x < xMidEnd; x += 4) {
            QRgb p = img.pixel(x, y);
            int lum = (299 * qRed(p) + 587 * qGreen(p) + 114 * qBlue(p)) / 1000;
            if (lum < 210) count++;
        }
        if (count > 5) {
            bottom = qMin(h - 1, y + 2);
            break;
        }
    }

    int cropW = qMax(10, bestRight - bestLeft);
    int cropH = qMax(10, bottom - top);
    return QRect(bestLeft, top, cropW, cropH);
}

QImage QuranManager::renderPageImage(int pageNumber, int highlightSurah, int highlightAyah, bool darkMode, int riwayahId, bool tajweedMode, bool algeriaMode, const QSize &requestedSize, QSize *size)
{
    if (riwayahId != 1 && riwayahId != 2) riwayahId = m_riwayah;
    int maxP = (algeriaMode && riwayahId == 2) ? 706 : 604;
    if (pageNumber < 1 || pageNumber > maxP) pageNumber = 1;

    // Mutex lock to ensure thread safety across concurrent background render requests
    QMutexLocker locker(&m_renderMutex);

    QString ramCacheKey = QStringLiteral("%1_%2_%3_%4_%5_%6_%7_%8_%9x%10")
            .arg(riwayahId)
            .arg(pageNumber)
            .arg(highlightSurah)
            .arg(highlightAyah)
            .arg(darkMode ? 1 : 0)
            .arg(tajweedMode ? 1 : 0)
            .arg(m_tajweedHdMode ? 1 : 0)
            .arg(algeriaMode ? 1 : 0)
            .arg(requestedSize.width())
            .arg(requestedSize.height());

    // 1. Check in-memory RAM cache (instant response < 1 ms)
    if (m_pageImageCache.contains(ramCacheKey)) {
        QImage *cached = m_pageImageCache.object(ramCacheKey);
        if (cached && !cached->isNull()) {
            if (size) *size = cached->size();
            return *cached;
        }
    }

    // 2. Algerian Mushaf Mode
    if (algeriaMode && riwayahId == 2) {
        QString algeriaPath = getLocalAlgeriaPagePath(pageNumber);
        if (!QFile::exists(algeriaPath)) {
            preloadAlgeriaPage(pageNumber);
            return QImage();
        }

        QString baseCachedPath = QStringLiteral("%1/page_%2_%3_v3_crop.png")
                .arg(getAlgeriaPagesCacheDir())
                .arg(pageNumber)
                .arg(darkMode ? QStringLiteral("dark") : QStringLiteral("light"));

        // Remove obsolete legacy crop cache from previous flawed detector if present
        QString oldCropPath = QStringLiteral("%1/page_%2_%3_v2_crop.png")
                .arg(getAlgeriaPagesCacheDir())
                .arg(pageNumber)
                .arg(darkMode ? QStringLiteral("dark") : QStringLiteral("light"));
        if (QFile::exists(oldCropPath)) {
            QFile::remove(oldCropPath);
        }

        QImage baseImg;
        if (QFile::exists(baseCachedPath)) {
            baseImg.load(baseCachedPath);
        }

        if (baseImg.isNull()) {
            QImage origImg(algeriaPath);
            if (origImg.isNull()) {
                return QImage();
            }

            QRect frameRect = detectMushafPageFrame(origImg);
            QImage croppedImg = origImg.copy(frameRect);

            if (darkMode) {
                QImage darkImg = croppedImg.convertToFormat(QImage::Format_ARGB32);
                int h = darkImg.height();
                int w = darkImg.width();
                for (int y = 0; y < h; ++y) {
                    QRgb *scanLine = reinterpret_cast<QRgb*>(darkImg.scanLine(y));
                    for (int x = 0; x < w; ++x) {
                        QRgb pixel = scanLine[x];
                        int r = qRed(pixel);
                        int g = qGreen(pixel);
                        int b = qBlue(pixel);

                        int maxVal = qMax(r, qMax(g, b));
                        int minVal = qMin(r, qMin(g, b));
                        int chroma = maxVal - minVal;
                        int lum = (299 * r + 587 * g + 114 * b) / 1000;

                        // Algerian scan paper background threshold:
                        // Pure scanner margins (lum > 200) or aged cream/peach paper (lum > 115)
                        bool isPaper = (lum > 200) || (lum > 115 && r >= g && g >= (b - 25));
                        if (isPaper) {
                            scanLine[x] = qRgb(0, 0, 0);
                        } else if (lum < 100 && chroma < 40) {
                            // Dark calligraphy text -> pure white
                            scanLine[x] = qRgb(255, 255, 255);
                        } else if (chroma < 30) {
                            // Anti-aliased text edges
                            int inv = qBound(0, (int)((255 - lum) * 1.3), 255);
                            scanLine[x] = qRgb(inv, inv, inv);
                        } else {
                            // Surah header ornaments and gold/red circles
                            int denom = qMax(30, maxVal);
                            int newR = qBound(0, (r * 240) / denom, 255);
                            int newG = qBound(0, (g * 240) / denom, 255);
                            int newB = qBound(0, (b * 240) / denom, 255);
                            scanLine[x] = qRgb(newR, newG, newB);
                        }
                    }
                }

                darkImg.save(baseCachedPath, "PNG");
                baseImg = darkImg;
            } else {
                croppedImg.save(baseCachedPath, "PNG");
                baseImg = croppedImg;
            }
        }

        // If ayah highlight is requested, draw golden line highlight over Algerian 13-line layout
        // Highlight strictly aligns with the ayah currently selected or read by the reciter
        if (highlightSurah > 0 && highlightAyah > 0) {
            QVariantList pageAyahs = getAyahsForAlgeriaPage(pageNumber);
            if (!pageAyahs.isEmpty()) {
                double totalLines = (pageNumber <= 2) ? 8.0 : 13.0;
                double targetStartLine = 0.0;
                double targetEndLine = 0.0;
                bool found = false;

                for (int i = 0; i < pageAyahs.size(); ++i) {
                    QVariantMap a = pageAyahs[i].toMap();
                    int s = a.value(QStringLiteral("surah_number")).toInt();
                    int ay = a.value(QStringLiteral("ayah_number")).toInt();
                    if (s == highlightSurah && ay == highlightAyah) {
                        targetStartLine = a.value(QStringLiteral("start_line")).toDouble();
                        targetEndLine = a.value(QStringLiteral("end_line")).toDouble();
                        found = true;
                        break;
                    }
                }

                if (found) {
                    if (targetEndLine <= targetStartLine) {
                        targetEndLine = qMin(targetStartLine + 1.0, totalLines);
                    }
                    QImage resultImg = baseImg.copy();
                    int imgW = resultImg.width();
                    int imgH = resultImg.height();

                    double innerX = (pageNumber <= 2) ? imgW * 0.12 : imgW * 0.030;
                    double innerW = (pageNumber <= 2) ? imgW * 0.76 : imgW * 0.940;
                    double innerY = (pageNumber <= 2) ? imgH * 0.10 : imgH * 0.032;
                    double innerH = (pageNumber <= 2) ? imgH * 0.80 : imgH * 0.940;
                    double lineHeight = innerH / totalLines;

                    int startLineIdx = qBound(0, (int)targetStartLine, (int)(totalLines - 1));
                    int endLineIdx = qBound(0, (int)targetEndLine, (int)(totalLines - 1));

                    QPainter painter(&resultImg);
                    painter.setRenderHint(QPainter::Antialiasing, true);
                    if (darkMode) {
                        painter.setCompositionMode(QPainter::CompositionMode_Screen);
                        QColor hlColor(235, 185, 45, 110);
                        painter.setBrush(hlColor);
                        painter.setPen(Qt::NoPen);
                    } else {
                        painter.setCompositionMode(QPainter::CompositionMode_Multiply);
                        QColor hlColor(218, 165, 32, 70);
                        painter.setBrush(hlColor);
                        painter.setPen(Qt::NoPen);
                    }

                    for (int line = startLineIdx; line <= endLineIdx; ++line) {
                        double fStartInLine = 0.0;
                        double fEndInLine = 1.0;

                        if (line == startLineIdx) {
                            fStartInLine = qBound(0.0, targetStartLine - (double)line, 1.0);
                        }
                        if (line == endLineIdx) {
                            fEndInLine = qBound(0.0, targetEndLine - (double)line, 1.0);
                        }

                        if (fEndInLine <= fStartInLine) continue;

                        // In Arabic RTL: 0.0 is right margin, 1.0 is left margin
                        double xRight = innerX + innerW * (1.0 - fStartInLine);
                        double xLeft = innerX + innerW * (1.0 - fEndInLine);
                        double rectX = xLeft;
                        double rectW = xRight - xLeft;
                        double rectY = innerY + line * lineHeight;

                        QRectF lineRect(rectX, rectY, rectW, lineHeight);
                        painter.drawRoundedRect(lineRect.adjusted(2, 2, -2, -2), 5, 5);
                    }
                    painter.end();

                    if (size) *size = resultImg.size();
                    m_pageImageCache.insert(ramCacheKey, new QImage(resultImg));
                    return resultImg;
                }
            }
        }

        if (size) *size = baseImg.size();
        m_pageImageCache.insert(ramCacheKey, new QImage(baseImg));
        return baseImg;
    }

    // 3. If Tajweed mode is requested and available for this riwayah, serve authentic colored Tajweed page
    if (tajweedMode && isTajweedMushafAvailable(riwayahId)) {
        bool hd = m_tajweedHdMode;
        QString tajweedPath = getLocalTajweedPagePath(riwayahId, pageNumber, hd);
        if (!QFile::exists(tajweedPath)) {
            preloadPage(pageNumber);
            return QImage();
        }

        QString baseCachedPath = QStringLiteral("%1/page_%2_%3_%4_v2_crop.png")
                .arg(getTajweedPagesCacheDir(riwayahId))
                .arg(pageNumber)
                .arg(hd ? QStringLiteral("hd") : QStringLiteral("sd"))
                .arg(darkMode ? QStringLiteral("dark") : QStringLiteral("light"));

        // Invalidate old uncropped/margin-included cache if present
        QString oldCachedPath = QStringLiteral("%1/page_%2_%3_%4_crop.png")
                .arg(getTajweedPagesCacheDir(riwayahId))
                .arg(pageNumber)
                .arg(hd ? QStringLiteral("hd") : QStringLiteral("sd"))
                .arg(darkMode ? QStringLiteral("dark") : QStringLiteral("light"));
        if (QFile::exists(oldCachedPath)) {
            QFile::remove(oldCachedPath);
        }

        QImage baseImg;
        if (QFile::exists(baseCachedPath)) {
            baseImg.load(baseCachedPath);
        }

        if (baseImg.isNull()) {
            QImage origImg(tajweedPath);
            if (origImg.isNull()) {
                return QImage();
            }

            // Auto-detect outer green frame and crop out vocabulary/commentary side margins
            QRect frameRect = detectTajweedMushafPageFrame(origImg, pageNumber);
            QImage croppedImg = origImg.copy(frameRect);

            if (darkMode) {
                // High-performance integer transformation for Tajweed night mode
                QImage darkImg = croppedImg.convertToFormat(QImage::Format_ARGB32);
                int h = darkImg.height();
                int w = darkImg.width();
                for (int y = 0; y < h; ++y) {
                    QRgb *scanLine = reinterpret_cast<QRgb*>(darkImg.scanLine(y));
                    for (int x = 0; x < w; ++x) {
                        QRgb pixel = scanLine[x];
                        int r = qRed(pixel);
                        int g = qGreen(pixel);
                        int b = qBlue(pixel);

                        int maxVal = qMax(r, qMax(g, b));
                        int minVal = qMin(r, qMin(g, b));
                        int chroma = maxVal - minVal;
                        int lum = (299 * r + 587 * g + 114 * b) / 1000;

                        // Paper background: scanned paper is bright (lum > 175) and not intensely saturated (chroma < 65)
                        bool isPaper = (lum > 175 && chroma < 65) || (lum > 220);
                        if (isPaper) {
                            scanLine[x] = qRgb(0, 0, 0);
                        } else if (chroma < 30) {
                            // Black / dark grey ink or neutral symbols -> invert to white/light grey
                            if (lum < 70) {
                                scanLine[x] = qRgb(255, 255, 255);
                            } else {
                                int inv = qBound(0, (int)((255 - lum) * 1.3), 255);
                                scanLine[x] = qRgb(inv, inv, inv);
                            }
                        } else {
                            // Genuine colored letters / rules (red, green, blue, cyan, orange, pink) or green decorative frame
                            int denom = qMax(30, maxVal);
                            int newR = qBound(0, (r * 235) / denom, 255);
                            int newG = qBound(0, (g * 235) / denom, 255);
                            int newB = qBound(0, (b * 235) / denom, 255);
                            scanLine[x] = qRgb(newR, newG, newB);
                        }
                    }
                }

                darkImg.save(baseCachedPath, "PNG");
                baseImg = darkImg;
            } else {
                croppedImg.save(baseCachedPath, "PNG");
                baseImg = croppedImg;
            }
        }

        // If no ayah is highlighted, return base page immediately
        if (highlightSurah <= 0 || highlightAyah <= 0) {
            if (size) *size = baseImg.size();
            m_pageImageCache.insert(ramCacheKey, new QImage(baseImg));
            return baseImg;
        }

        // Draw ayah highlight over the base image
        // Highlight strictly begins after previous ayah marker and ends at current ayah marker
        QImage resultImg = baseImg.copy();

        double totalLines = (pageNumber <= 2) ? 8.0 : 15.0;
        double targetStartLine = 0.0;
        double targetEndLine = 0.0;
        bool found = false;

        // 1. First look up exact sub-millimeter bounding boxes from verified tajweed_ayah_boxes
        if (m_db.isOpen()) {
            QSqlQuery bQ(m_db);
            bQ.prepare(QStringLiteral("SELECT x1, y1, x2, y2 FROM tajweed_ayah_boxes WHERE riwayah_id = ? AND page_number = ? AND surah_number = ? AND ayah_number = ? ORDER BY box_index ASC"));
            bQ.addBindValue(riwayahId);
            bQ.addBindValue(pageNumber);
            bQ.addBindValue(highlightSurah);
            bQ.addBindValue(highlightAyah);
            if (bQ.exec() && bQ.next()) {
                int imgW = resultImg.width();
                int imgH = resultImg.height();
                double innerX, innerW, innerY, innerH;
                if (pageNumber <= 2) {
                    innerX = imgW * 0.16;
                    innerW = imgW * 0.68;
                    innerY = imgH * 0.18;
                    innerH = imgH * 0.64;
                } else {
                    innerX = imgW * 0.055;
                    innerW = imgW * 0.890;
                    innerY = imgH * 0.050;
                    innerH = imgH * 0.875;
                }

                QPainter painter(&resultImg);
                painter.setRenderHint(QPainter::Antialiasing, true);
                if (darkMode) {
                    painter.setCompositionMode(QPainter::CompositionMode_Screen);
                    QColor hlColor(235, 185, 45, 110);
                    painter.setBrush(hlColor);
                    painter.setPen(Qt::NoPen);
                } else {
                    painter.setCompositionMode(QPainter::CompositionMode_Multiply);
                    QColor hlColor(218, 165, 32, 75);
                    painter.setBrush(hlColor);
                    painter.setPen(Qt::NoPen);
                }

                do {
                    double nx1 = bQ.value(0).toDouble();
                    double ny1 = bQ.value(1).toDouble();
                    double nx2 = bQ.value(2).toDouble();
                    double ny2 = bQ.value(3).toDouble();

                    double rx1 = innerX + nx1 * innerW;
                    double ry1 = innerY + ny1 * innerH;
                    double rx2 = innerX + nx2 * innerW;
                    double ry2 = innerY + ny2 * innerH;

                    QRectF r(rx1, ry1, rx2 - rx1, ry2 - ry1);
                    painter.drawRoundedRect(r.adjusted(2, 2, -2, -2), 5, 5);
                } while (bQ.next());
                painter.end();

                if (size) *size = resultImg.size();
                m_pageImageCache.insert(ramCacheKey, new QImage(resultImg));
                return resultImg;
            }

            QSqlQuery tlQ(m_db);
            tlQ.prepare(QStringLiteral("SELECT start_line, end_line FROM tajweed_ayah_lines WHERE page_number = ? AND surah_number = ? AND ayah_number = ?"));
            tlQ.addBindValue(pageNumber);
            tlQ.addBindValue(highlightSurah);
            tlQ.addBindValue(highlightAyah);
            if (tlQ.exec() && tlQ.next()) {
                targetStartLine = tlQ.value(0).toDouble();
                targetEndLine = tlQ.value(1).toDouble();
                found = true;
            }
        }

        // 2. Fallback to proportional calculation if database row is not present
        if (!found) {
            QVariantList pageAyahs = getAyahsForPage(pageNumber);
            if (!pageAyahs.isEmpty()) {
                const double markerWeight = 6.0;
                QVector<double> textWeights;
                textWeights.reserve(pageAyahs.size());
                double totalWeight = 0.0;
                for (const QVariant &v : pageAyahs) {
                    QVariantMap a = v.toMap();
                    QString txt = a.value(QStringLiteral("text_uthmani")).toString();
                    double w = calculateBaseWeight(txt);
                    textWeights.append(w);
                    totalWeight += w + markerWeight;
                }
                if (totalWeight <= 0.0) totalWeight = 1.0;

                double headerLines = 0.0;
                for (int i = 0; i < pageAyahs.size(); ++i) {
                    QVariantMap a = pageAyahs[i].toMap();
                    int ay = a.value(QStringLiteral("ayah_number")).toInt();
                    int s = a.value(QStringLiteral("surah_number")).toInt();
                    if (ay == 1 && pageNumber > 2) {
                        headerLines += (s == 9) ? 2.0 : 3.0;
                    }
                }

                double totalTextLines = (pageNumber <= 2) ? ((pageNumber == 1) ? 8.0 : 6.0)
                                                          : qMax(1.0, 15.0 - headerLines);

                QVector<double> lineDurations;
                QVector<double> textDurations;
                lineDurations.reserve(pageAyahs.size());
                textDurations.reserve(pageAyahs.size());
                for (int i = 0; i < pageAyahs.size(); ++i) {
                    lineDurations.append(((textWeights[i] + markerWeight) / totalWeight) * totalTextLines);
                    textDurations.append((textWeights[i] / totalWeight) * totalTextLines);
                }

                double currStart = (pageNumber == 2) ? 2.0 : 0.0;

                for (int i = 0; i < pageAyahs.size(); ++i) {
                    QVariantMap a = pageAyahs[i].toMap();
                    int s = a.value(QStringLiteral("surah_number")).toInt();
                    int ay = a.value(QStringLiteral("ayah_number")).toInt();

                    if (ay == 1 && pageNumber > 2) {
                        currStart += (s == 9) ? 2.0 : 3.0;
                    }

                    double txtEnd = currStart + textDurations[i];
                    double fullEnd = currStart + lineDurations[i];

                    // Boundary snapping:
                    if (i < pageAyahs.size() - 1) {
                        if (lineDurations[i] >= 0.8) {
                            double roundEnd = qRound(fullEnd);
                            if (qAbs(fullEnd - roundEnd) < 0.18 && roundEnd > 0 && roundEnd < totalLines) {
                                double diff = roundEnd - fullEnd;
                                fullEnd = roundEnd;
                                txtEnd += diff * 0.85;
                            }
                        }
                    } else {
                        if (pageNumber > 2) {
                            fullEnd = totalLines;
                            txtEnd = qMax(currStart + 0.05, totalLines - (lineDurations[i] - textDurations[i]));
                        }
                    }

                    if (s == highlightSurah && ay == highlightAyah) {
                        targetStartLine = currStart;
                        targetEndLine = txtEnd;
                        found = true;
                        break;
                    }

                    currStart = fullEnd;
                }
            }
        }

            if (found) {
                int imgW = resultImg.width();
                int imgH = resultImg.height();
                double innerX, innerW, innerY, innerH;
                if (pageNumber <= 2) {
                    innerX = imgW * 0.16;
                    innerW = imgW * 0.68;
                    innerY = imgH * 0.18;
                    innerH = imgH * 0.64;
                } else {
                    innerX = imgW * 0.055;
                    innerW = imgW * 0.890;
                    innerY = imgH * 0.050;
                    innerH = imgH * 0.875;
                }
                double lineHeight = innerH / totalLines;

                int startLineIdx = qBound(0, (int)targetStartLine, (int)(totalLines - 1));
                int endLineIdx = qBound(0, (int)targetEndLine, (int)(totalLines - 1));

                QPainter painter(&resultImg);
                painter.setRenderHint(QPainter::Antialiasing, true);
                if (darkMode) {
                    painter.setCompositionMode(QPainter::CompositionMode_Screen);
                    QColor hlColor(235, 185, 45, 95);
                    painter.setBrush(hlColor);
                    painter.setPen(Qt::NoPen);
                } else {
                    painter.setCompositionMode(QPainter::CompositionMode_Multiply);
                    QColor hlColor(218, 165, 32, 65);
                    painter.setBrush(hlColor);
                    painter.setPen(Qt::NoPen);
                }

                for (int line = startLineIdx; line <= endLineIdx; ++line) {
                    double fStartInLine = 0.0;
                    double fEndInLine = 1.0;

                    if (line == startLineIdx) {
                        fStartInLine = qBound(0.0, targetStartLine - (double)line, 1.0);
                    }
                    if (line == endLineIdx) {
                        fEndInLine = qBound(0.0, targetEndLine - (double)line, 1.0);
                    }

                    if (fEndInLine <= fStartInLine) continue;

                    // In Arabic RTL: 0.0 is right margin, 1.0 is left margin
                    double xRight = innerX + innerW * (1.0 - fStartInLine);
                    double xLeft = innerX + innerW * (1.0 - fEndInLine);
                    double rectX = xLeft;
                    double rectW = xRight - xLeft;
                    double rectY = innerY + line * lineHeight;

                    QRectF lineRect(rectX, rectY, rectW, lineHeight);
                    painter.drawRoundedRect(lineRect.adjusted(2, 2, -2, -2), 5, 5);
                }
                painter.end();
            }

        if (size) *size = resultImg.size();
        m_pageImageCache.insert(ramCacheKey, new QImage(resultImg));
        return resultImg;
    }

    bool isBasePage = (highlightSurah <= 0 || highlightAyah <= 0);
    QString diskCachedPath = QStringLiteral("%1/base_r%2_p%3_d%4.png")
            .arg(getRenderedPagesCacheDir())
            .arg(riwayahId)
            .arg(pageNumber)
            .arg(darkMode ? 1 : 0);

    // 2. Check on-disk lossless PNG cache for base pages (loads in ~10 ms instead of 2000 ms SVG rasterization)
    if (isBasePage && (requestedSize.width() <= 0 || requestedSize.width() == 1080) && QFile::exists(diskCachedPath)) {
        QImage diskImg(diskCachedPath);
        if (!diskImg.isNull()) {
            m_pageImageCache.insert(ramCacheKey, new QImage(diskImg));
            if (size) *size = diskImg.size();
            return diskImg;
        }
    }

    // 3. Load SVG source
    QString content;
    if (m_memCachedPageNumber == pageNumber && m_memCachedRiwayah == riwayahId && !m_memCachedSvgContent.isEmpty()) {
        content = m_memCachedSvgContent;
    } else {
        QString rawPath = getLocalPagePath(riwayahId, pageNumber);
        if (!QFile::exists(rawPath)) {
            preloadPage(pageNumber);
            return QImage();
        }

        QFile inFile(rawPath);
        if (!inFile.open(QIODevice::ReadOnly)) {
            return QImage();
        }
        content = QString::fromUtf8(inFile.readAll());
        inFile.close();

        m_memCachedPageNumber = pageNumber;
        m_memCachedRiwayah = riwayahId;
        m_memCachedSvgContent = content;
    }

    // Background color
    QString bgColor = darkMode ? QStringLiteral("#12151b") : QStringLiteral("#fffdf5");

    // Dark mode font colors
    if (darkMode) {
        content.replace(QStringLiteral("fill=\"#231f20\""), QStringLiteral("fill=\"#ede4ce\""));
        content.replace(QStringLiteral("fill=\"#000000\""), QStringLiteral("fill=\"#ede4ce\""));
        content.replace(QStringLiteral("fill=\"#1a1a1a\""), QStringLiteral("fill=\"#ede4ce\""));
    }

    // Ayah Polygon highlighting (rendered BEHIND text for crisp readability)
    if (highlightSurah > 0 && highlightAyah > 0) {
        QString fillColor = darkMode ? QStringLiteral("#d4a017") : QStringLiteral("#c8961e");
        QString fillOp = darkMode ? QStringLiteral("0.30") : QStringLiteral("0.22");

        // Fast string search instead of slow regex loop across 250 KB
        QString needleS1 = QStringLiteral("surah=\"%1\"").arg(highlightSurah);
        QString needleS2 = QStringLiteral("surah='%1'").arg(highlightSurah);
        QString needleA1 = QStringLiteral("ayah=\"%1\"").arg(highlightAyah);
        QString needleA2 = QStringLiteral("ayah='%1'").arg(highlightAyah);

        QString targetPathTag;
        int sSearchPos = 0;
        while (sSearchPos < content.length()) {
            int idx1 = content.indexOf(needleS1, sSearchPos);
            int idx2 = content.indexOf(needleS2, sSearchPos);
            int idx = -1;
            if (idx1 != -1 && idx2 != -1) idx = qMin(idx1, idx2);
            else if (idx1 != -1) idx = idx1;
            else if (idx2 != -1) idx = idx2;

            if (idx == -1) break;

            int tagStart = content.lastIndexOf(QStringLiteral("<path"), idx);
            if (tagStart != -1) {
                int tagEnd = content.indexOf(QLatin1Char('>'), idx);
                if (tagEnd != -1) {
                    QString tag = content.mid(tagStart, tagEnd - tagStart + 1);
                    if (tag.contains(QStringLiteral("ayahPolygon")) &&
                        (tag.contains(needleA1) || tag.contains(needleA2))) {
                        targetPathTag = tag;
                        break;
                    }
                }
            }
            sSearchPos = idx + needleS1.length();
        }

        if (!targetPathTag.isEmpty()) {
            content.remove(targetPathTag);

            QString highlightTag = targetPathTag;
            highlightTag.remove(QRegExp(QStringLiteral("fill-opacity=[\"'][^\"']*[\"']")));
            highlightTag.remove(QRegExp(QStringLiteral("fill=[\"'][^\"']*[\"']")));
            highlightTag.remove(QRegExp(QStringLiteral("stroke=[\"'][^\"']*[\"']")));
            highlightTag.remove(QRegExp(QStringLiteral("stroke-width=[\"'][^\"']*[\"']")));
            highlightTag.remove(QRegExp(QStringLiteral("stroke-opacity=[\"'][^\"']*[\"']")));
            if (highlightTag.endsWith(QStringLiteral("/>"))) highlightTag.chop(2);
            else if (highlightTag.endsWith(QStringLiteral(">"))) highlightTag.chop(1);
            highlightTag += QStringLiteral(" fill=\"%1\" fill-opacity=\"%2\" stroke=\"none\" />")
                    .arg(fillColor, fillOp);

            int svgTagStart = content.indexOf(QStringLiteral("<svg"));
            if (svgTagStart != -1) {
                int svgTagEnd = content.indexOf(QLatin1Char('>'), svgTagStart);
                if (svgTagEnd != -1) {
                    content.insert(svgTagEnd + 1, highlightTag);
                }
            }
        }
    }

    QSvgRenderer renderer(content.toUtf8());
    if (!renderer.isValid()) {
        qWarning() << "[QuranManager] QSvgRenderer failed to parse SVG for page" << pageNumber;
        return QImage();
    }

    QRectF vb = renderer.viewBoxF();
    qreal aspect = (vb.width() > 0) ? (vb.height() / vb.width()) : 1.5942;

    int targetW = 1080; // Sony Xperia X native display width (1080x1920)
    int targetH = qRound(targetW * aspect);

    if (requestedSize.width() > 0 && requestedSize.height() > 0) {
        qreal reqAspect = (qreal)requestedSize.height() / (qreal)requestedSize.width();
        if (reqAspect > aspect) {
            targetW = requestedSize.width();
            targetH = qRound(targetW * aspect);
        } else {
            targetH = requestedSize.height();
            targetW = qRound(targetH / aspect);
        }
    } else if (requestedSize.width() > 0) {
        targetW = requestedSize.width();
        targetH = qRound(targetW * aspect);
    } else if (requestedSize.height() > 0) {
        targetH = requestedSize.height();
        targetW = qRound(targetH / aspect);
    }

    targetW = qBound(320, targetW, 2160);
    targetH = qBound(480, targetH, 3840);

    QImage img(targetW, targetH, QImage::Format_ARGB32_Premultiplied);
    img.fill(QColor(bgColor));

    QPainter painter(&img);
    painter.setRenderHint(QPainter::Antialiasing, true);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
    renderer.render(&painter, QRectF(0, 0, targetW, targetH));
    painter.end();

    // Cache rendered base page as lossless PNG on disk for instant future loads
    if (isBasePage && targetW == 1080) {
        img.save(diskCachedPath, "PNG");
    }

    // Store in RAM cache
    m_pageImageCache.insert(ramCacheKey, new QImage(img));

    if (size) *size = img.size();
    return img;
}

QVariantMap QuranManager::getAyahAtCoordinate(int pageNumber, double normalizedX, double normalizedY, int riwayahId)
{
    QVariantMap res;
    if (riwayahId != 1 && riwayahId != 2) riwayahId = m_riwayah;
    int maxP = (m_algeriaMode && riwayahId == 2) ? 706 : 604;
    if (pageNumber < 1 || pageNumber > maxP) return res;

    // Algerian Mushaf Mode: precise line + RTL coordinate lookup
    if (m_algeriaMode && riwayahId == 2) {
        QVariantList ayahs = getAyahsForAlgeriaPage(pageNumber);
        if (!ayahs.isEmpty()) {
            double totalLines = (pageNumber <= 2) ? 8.0 : 13.0;
            double innerY = (pageNumber <= 2) ? 0.10 : 0.032;
            double innerH = (pageNumber <= 2) ? 0.80 : 0.940;
            double innerX = (pageNumber <= 2) ? 0.12 : 0.030;
            double innerW = (pageNumber <= 2) ? 0.76 : 0.940;

            double clickedLine = ((normalizedY - innerY) / innerH) * totalLines;
            clickedLine = qBound(0.0, clickedLine, totalLines - 0.01);
            int lineIdx = (int)clickedLine;

            // In RTL: fraction 0.0 is right margin, 1.0 is left margin
            double fX = ((innerX + innerW) - normalizedX) / innerW;
            fX = qBound(0.0, fX, 0.999);
            double touchContinuousLine = (double)lineIdx + fX;

            for (int i = 0; i < ayahs.size(); ++i) {
                QVariantMap a = ayahs[i].toMap();
                double sL = a.value(QStringLiteral("start_line")).toDouble();
                double eL = a.value(QStringLiteral("end_line")).toDouble();
                double nextSL = (i + 1 < ayahs.size()) ? ayahs[i + 1].toMap().value(QStringLiteral("start_line")).toDouble() : (eL + 0.3);
                if (touchContinuousLine >= sL && touchContinuousLine < nextSL) {
                    res[QStringLiteral("surah")] = a.value(QStringLiteral("surah_number")).toInt();
                    res[QStringLiteral("ayah")] = a.value(QStringLiteral("ayah_number")).toInt();
                    return res;
                }
            }

            // Fallback: closest ayah by line distance
            double bestDist = 9999.0;
            for (const QVariant &v : ayahs) {
                QVariantMap a = v.toMap();
                double sL = a.value(QStringLiteral("start_line")).toDouble();
                double eL = a.value(QStringLiteral("end_line")).toDouble();
                double mid = (sL + eL) * 0.5;
                double dist = qAbs(touchContinuousLine - mid);
                if (dist < bestDist) {
                    bestDist = dist;
                    res[QStringLiteral("surah")] = a.value(QStringLiteral("surah_number")).toInt();
                    res[QStringLiteral("ayah")] = a.value(QStringLiteral("ayah_number")).toInt();
                }
            }
            return res;
        }
    }

    // Tajweed Mushaf Mode: precise box hit-test or line lookup
    if (m_tajweedMode) {
        if (m_db.isOpen()) {
            double innerY = (pageNumber <= 2) ? 0.18 : 0.050;
            double innerH = (pageNumber <= 2) ? 0.64 : 0.875;
            double innerX = (pageNumber <= 2) ? 0.16 : 0.055;
            double innerW = (pageNumber <= 2) ? 0.68 : 0.890;
            double nx = (normalizedX - innerX) / innerW;
            double ny = (normalizedY - innerY) / innerH;

            QSqlQuery bQ(m_db);
            bQ.prepare(QStringLiteral("SELECT surah_number, ayah_number, x1, y1, x2, y2 FROM tajweed_ayah_boxes WHERE riwayah_id = ? AND page_number = ? ORDER BY box_index ASC"));
            bQ.addBindValue(riwayahId);
            bQ.addBindValue(pageNumber);
            if (bQ.exec()) {
                while (bQ.next()) {
                    double x1 = bQ.value(2).toDouble();
                    double y1 = bQ.value(3).toDouble();
                    double x2 = bQ.value(4).toDouble();
                    double y2 = bQ.value(5).toDouble();
                    if (nx >= x1 && nx <= x2 && ny >= y1 && ny <= y2) {
                        res[QStringLiteral("surah")] = bQ.value(0).toInt();
                        res[QStringLiteral("ayah")] = bQ.value(1).toInt();
                        return res;
                    }
                }
            }
        }

        QVariantList ayahs = getAyahsForPage(pageNumber);
        if (!ayahs.isEmpty() && ayahs.first().toMap().contains(QStringLiteral("start_line"))) {
            double totalLines = (pageNumber <= 2) ? 8.0 : 15.0;
            double innerY = (pageNumber <= 2) ? 0.18 : 0.050;
            double innerH = (pageNumber <= 2) ? 0.64 : 0.875;
            double innerX = (pageNumber <= 2) ? 0.16 : 0.055;
            double innerW = (pageNumber <= 2) ? 0.68 : 0.890;

            double clickedLine = ((normalizedY - innerY) / innerH) * totalLines;
            clickedLine = qBound(0.0, clickedLine, totalLines - 0.01);
            int lineIdx = (int)clickedLine;

            // In RTL: fraction 0.0 is right margin, 1.0 is left margin
            double fX = ((innerX + innerW) - normalizedX) / innerW;
            fX = qBound(0.0, fX, 0.999);
            double touchContinuousLine = (double)lineIdx + fX;

            for (int i = 0; i < ayahs.size(); ++i) {
                QVariantMap a = ayahs[i].toMap();
                double sL = a.value(QStringLiteral("start_line")).toDouble();
                double eL = a.value(QStringLiteral("end_line")).toDouble();
                double nextSL = (i + 1 < ayahs.size()) ? ayahs[i + 1].toMap().value(QStringLiteral("start_line")).toDouble() : (eL + 0.3);
                if (touchContinuousLine >= sL && touchContinuousLine < nextSL) {
                    res[QStringLiteral("surah")] = a.value(QStringLiteral("surah_number")).toInt();
                    res[QStringLiteral("ayah")] = a.value(QStringLiteral("ayah_number")).toInt();
                    return res;
                }
            }

            // Fallback: closest ayah by line distance
            double bestDist = 9999.0;
            for (const QVariant &v : ayahs) {
                QVariantMap a = v.toMap();
                double sL = a.value(QStringLiteral("start_line")).toDouble();
                double eL = a.value(QStringLiteral("end_line")).toDouble();
                double mid = (sL + eL) * 0.5;
                double dist = qAbs(touchContinuousLine - mid);
                if (dist < bestDist) {
                    bestDist = dist;
                    res[QStringLiteral("surah")] = a.value(QStringLiteral("surah_number")).toInt();
                    res[QStringLiteral("ayah")] = a.value(QStringLiteral("ayah_number")).toInt();
                }
            }
            if (res.contains(QStringLiteral("surah"))) {
                return res;
            }
        }
    }

    // Load SVG content (uses m_memCachedSvgContent if already in RAM)
    QString content;
    if (m_memCachedPageNumber == pageNumber && m_memCachedRiwayah == riwayahId && !m_memCachedSvgContent.isEmpty()) {
        content = m_memCachedSvgContent;
    } else {
        QString rawPath = getLocalPagePath(riwayahId, pageNumber);
        if (QFile::exists(rawPath)) {
            QFile inFile(rawPath);
            if (inFile.open(QIODevice::ReadOnly)) {
                content = QString::fromUtf8(inFile.readAll());
                inFile.close();
            }
        }
    }

    if (content.isEmpty()) {
        QVariantList ayahs = getAyahsForPage(pageNumber);
        if (!ayahs.isEmpty()) {
            int idx = qBound(0, (int)(normalizedY * ayahs.size()), ayahs.size() - 1);
            QVariantMap a = ayahs.at(idx).toMap();
            res[QStringLiteral("surah")] = a.value(QStringLiteral("surah_number")).toInt();
            res[QStringLiteral("ayah")] = a.value(QStringLiteral("ayah_number")).toInt();
        }
        return res;
    }

    struct AyahPoly {
        int surah;
        int ayah;
        QVector<QPolygonF> subPolys;
    };
    QVector<AyahPoly> polys;

    double minX = 999999.0, maxX = -999999.0;
    double minY = 999999.0, maxY = -999999.0;

    static const QRegularExpression pathTagRx(QStringLiteral("<path[^>]*class=[\"']ayahPolygon[\"'][^>]*>"));
    static const QRegularExpression surahRx(QStringLiteral("surah=[\"'](\\d+)[\"']"));
    static const QRegularExpression ayahRx(QStringLiteral("ayah=[\"'](\\d+)[\"']"));
    static const QRegularExpression dRx(QStringLiteral("\\bd=[\"']([^\"']+)[\"']"));
    static const QRegularExpression numRx(QStringLiteral("[-+]?\\d*\\.?\\d+"));

    auto it = pathTagRx.globalMatch(content);
    while (it.hasNext()) {
        QString tag = it.next().captured(0);
        auto mS = surahRx.match(tag);
        auto mA = ayahRx.match(tag);
        auto mD = dRx.match(tag);
        if (!mS.hasMatch() || !mA.hasMatch() || !mD.hasMatch()) continue;

        AyahPoly ap;
        ap.surah = mS.captured(1).toInt();
        ap.ayah = mA.captured(1).toInt();

        QString d = mD.captured(1);
        QStringList chunks = d.split(QRegularExpression(QStringLiteral("[ZM]")), QString::SkipEmptyParts);
        for (const QString &chunk : chunks) {
            auto numIt = numRx.globalMatch(chunk);
            QVector<double> vals;
            while (numIt.hasNext()) {
                vals.append(numIt.next().captured(0).toDouble());
            }
            if (vals.size() >= 4) {
                QPolygonF poly;
                for (int i = 0; i + 1 < vals.size(); i += 2) {
                    double x = vals[i];
                    double y = vals[i + 1];
                    poly << QPointF(x, y);
                    if (x < minX) minX = x;
                    if (x > maxX) maxX = x;
                    if (y < minY) minY = y;
                    if (y > maxY) maxY = y;
                }
                if (!poly.isEmpty()) {
                    ap.subPolys.append(poly);
                }
            }
        }
        if (!ap.subPolys.isEmpty()) {
            polys.append(ap);
        }
    }

    if (polys.isEmpty() || minX >= maxX || minY >= maxY) {
        return res;
    }

    // Top/bottom margins of the page frame (~6%)
    const double marginSide = 0.05;
    const double marginTop = 0.06;
    const double marginBottom = 0.06;

    double relX = (normalizedX - marginSide) / (1.0 - 2.0 * marginSide);
    double relY = (normalizedY - marginTop) / (1.0 - marginTop - marginBottom);
    relX = qBound(0.0, relX, 1.0);
    relY = qBound(0.0, relY, 1.0);

    double targetX = minX + relX * (maxX - minX);
    double targetY = minY + relY * (maxY - minY);
    QPointF pt(targetX, targetY);

    // 1. Direct point-in-polygon test
    for (const AyahPoly &ap : polys) {
        for (const QPolygonF &poly : ap.subPolys) {
            if (poly.containsPoint(pt, Qt::OddEvenFill)) {
                res[QStringLiteral("surah")] = ap.surah;
                res[QStringLiteral("ayah")] = ap.ayah;
                return res;
            }
        }
    }

    // 2. Closest vertical distance fallback
    double bestDist = 1e9;
    int bestSurah = 0;
    int bestAyah = 0;
    for (const AyahPoly &ap : polys) {
        for (const QPolygonF &poly : ap.subPolys) {
            QRectF r = poly.boundingRect();
            double dist = 0.0;
            if (targetY < r.top()) dist = r.top() - targetY;
            else if (targetY > r.bottom()) dist = targetY - r.bottom();
            else dist = 0.0;

            if (dist < bestDist) {
                bestDist = dist;
                bestSurah = ap.surah;
                bestAyah = ap.ayah;
            }
        }
    }

    if (bestSurah > 0 && bestAyah > 0) {
        res[QStringLiteral("surah")] = bestSurah;
        res[QStringLiteral("ayah")] = bestAyah;
    }
    return res;
}

void QuranManager::preloadPage(int pageNumber)
{
    if (pageNumber < 1 || pageNumber > maxPages()) return;
    if (m_algeriaMode && isAlgeriaMushafAvailable(m_riwayah)) {
        preloadAlgeriaPage(pageNumber);
        return;
    }
    bool tajweed = (m_tajweedMode && isTajweedMushafAvailable(m_riwayah));
    bool hd = m_tajweedHdMode;

    if (tajweed) {
        preloadSvgPage(pageNumber, m_riwayah);
    }

    QString localPath = tajweed
            ? getLocalTajweedPagePath(m_riwayah, pageNumber, hd)
            : getLocalPagePath(m_riwayah, pageNumber);
    if (QFile::exists(localPath)) return;

    // Ensure network accessibility
    m_netManager->setNetworkAccessible(QNetworkAccessManager::Accessible);

    // Check if download is already in progress for this page, riwayah, and mode
    for (auto it = m_activeDownloads.begin(); it != m_activeDownloads.end(); ++it) {
        if (it.value() == pageNumber &&
            it.key()->property("riwayah").toInt() == m_riwayah &&
            it.key()->property("isTajweed").toBool() == tajweed &&
            it.key()->property("isTajweedHd").toBool() == hd &&
            !it.key()->property("isAlgeria").toBool()) {
            return;
        }
    }

    QUrl url = tajweed
            ? QUrl(getRemoteTajweedPageUrl(m_riwayah, pageNumber, hd))
            : QUrl(getRemotePageUrl(m_riwayah, pageNumber));
    if (!url.isValid() || url.isEmpty()) return;

    qDebug() << "[QuranManager] Preloading page" << pageNumber << "for riwayah" << m_riwayah
             << "(tajweed:" << tajweed << "hd:" << hd << ") from" << url.toString();

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36"));
    request.setRawHeader("Accept", tajweed ? "image/jpeg,image/*,*/*;q=0.8" : "image/svg+xml,image/*,*/*;q=0.8");
    request.setRawHeader("Accept-Language", "ar,en-US;q=0.9,en;q=0.8");
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);

    QNetworkReply *reply = m_netManager->get(request);
    reply->setProperty("pageNumber", pageNumber);
    reply->setProperty("riwayah", m_riwayah);
    reply->setProperty("isTajweed", tajweed);
    reply->setProperty("isTajweedHd", hd);
    reply->setProperty("isAlgeria", false);
    reply->ignoreSslErrors();
    m_activeDownloads[reply] = pageNumber;
    connect(reply, &QNetworkReply::finished, this, &QuranManager::onPageDownloaded);
    connect(reply, static_cast<void(QNetworkReply::*)(const QList<QSslError>&)>(&QNetworkReply::sslErrors),
            reply, static_cast<void(QNetworkReply::*)()>(&QNetworkReply::ignoreSslErrors));
    connect(reply, static_cast<void(QNetworkReply::*)(QNetworkReply::NetworkError)>(&QNetworkReply::error),
            this, [reply, pageNumber](QNetworkReply::NetworkError err) {
        qWarning() << "[QuranManager] Network error downloading page" << pageNumber << ":" << err << reply->errorString();
    });
}

void QuranManager::preloadAlgeriaPage(int pageNumber)
{
    if (pageNumber < 1 || pageNumber > 706) return;
    QString localPath = getLocalAlgeriaPagePath(pageNumber);
    if (QFile::exists(localPath)) return;

    m_netManager->setNetworkAccessible(QNetworkAccessManager::Accessible);

    for (auto it = m_activeDownloads.begin(); it != m_activeDownloads.end(); ++it) {
        if (it.value() == pageNumber && it.key()->property("isAlgeria").toBool()) {
            return;
        }
    }

    QUrl url(getRemoteAlgeriaPageUrl(pageNumber));
    if (!url.isValid() || url.isEmpty()) return;

    qDebug() << "[QuranManager] Preloading Algerian page" << pageNumber << "from" << url.toString();

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36"));
    request.setRawHeader("Accept", "image/jpeg,image/*,*/*;q=0.8");
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);

    QNetworkReply *reply = m_netManager->get(request);
    reply->setProperty("pageNumber", pageNumber);
    reply->setProperty("riwayah", 2);
    reply->setProperty("isTajweed", false);
    reply->setProperty("isAlgeria", true);
    reply->ignoreSslErrors();
    m_activeDownloads[reply] = pageNumber;
    connect(reply, &QNetworkReply::finished, this, &QuranManager::onPageDownloaded);
    connect(reply, static_cast<void(QNetworkReply::*)(const QList<QSslError>&)>(&QNetworkReply::sslErrors),
            reply, static_cast<void(QNetworkReply::*)()>(&QNetworkReply::ignoreSslErrors));
    connect(reply, static_cast<void(QNetworkReply::*)(QNetworkReply::NetworkError)>(&QNetworkReply::error),
            this, [reply, pageNumber](QNetworkReply::NetworkError err) {
        qWarning() << "[QuranManager] Network error downloading Algerian page" << pageNumber << ":" << err << reply->errorString();
    });
}

void QuranManager::preloadSvgPage(int pageNumber, int riwayahId)
{
    if (pageNumber < 1 || pageNumber > 604) return;
    if (riwayahId != 1 && riwayahId != 2) riwayahId = m_riwayah;

    QString rawPath = getLocalPagePath(riwayahId, pageNumber);
    if (QFile::exists(rawPath)) return;

    m_netManager->setNetworkAccessible(QNetworkAccessManager::Accessible);

    for (auto it = m_activeDownloads.begin(); it != m_activeDownloads.end(); ++it) {
        if (it.value() == pageNumber &&
            it.key()->property("riwayah").toInt() == riwayahId &&
            it.key()->property("isTajweed").toBool() == false) {
            return;
        }
    }

    QUrl url(getRemotePageUrl(riwayahId, pageNumber));
    if (!url.isValid() || url.isEmpty()) return;

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36"));
    request.setRawHeader("Accept", "image/svg+xml,image/*,*/*;q=0.8");
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);

    QNetworkReply *reply = m_netManager->get(request);
    reply->setProperty("pageNumber", pageNumber);
    reply->setProperty("riwayah", riwayahId);
    reply->setProperty("isTajweed", false);
    reply->ignoreSslErrors();
    m_activeDownloads[reply] = pageNumber;
    connect(reply, &QNetworkReply::finished, this, &QuranManager::onPageDownloaded);
    connect(reply, static_cast<void(QNetworkReply::*)(const QList<QSslError>&)>(&QNetworkReply::sslErrors),
            reply, static_cast<void(QNetworkReply::*)()>(&QNetworkReply::ignoreSslErrors));
}

void QuranManager::onPageDownloaded()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;

    int pageNumber = reply->property("pageNumber").toInt();
    if (pageNumber <= 0) pageNumber = m_activeDownloads.value(reply, 0);
    int riwayah = reply->property("riwayah").toInt();
    if (riwayah != 1 && riwayah != 2) riwayah = m_riwayah;
    bool isTajweed = reply->property("isTajweed").toBool();
    bool isTajweedHd = reply->property("isTajweedHd").toBool();
    bool isAlgeria = reply->property("isAlgeria").toBool();
    m_activeDownloads.remove(reply);

    int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    qDebug() << "[QuranManager] Page" << pageNumber << "riwayah" << riwayah
             << "(tajweed:" << isTajweed << "hd:" << isTajweedHd << "algeria:" << isAlgeria << ") download completed. Status:" << statusCode << "Error:" << reply->error();

    if (reply->error() == QNetworkReply::NoError && pageNumber > 0) {
        QByteArray data = reply->readAll();
        qDebug() << "[QuranManager] Page" << pageNumber << "received bytes:" << data.size();
        if (isAlgeria) {
            if (data.size() > 5000) {
                QString localPath = getLocalAlgeriaPagePath(pageNumber);
                QFile file(localPath);
                if (file.open(QIODevice::WriteOnly)) {
                    file.write(data);
                    file.close();
                    qDebug() << "[QuranManager] Successfully cached Algerian page" << pageNumber << "to" << localPath;
                    emit pageCached(pageNumber);
                } else {
                    qWarning() << "[QuranManager] Could not open file for writing:" << localPath << file.errorString();
                    emit pageDownloadFailed(pageNumber);
                }
            } else {
                qWarning() << "[QuranManager] Algerian page" << pageNumber << "content too small! Size:" << data.size();
                emit pageDownloadFailed(pageNumber);
            }
        } else if (isTajweed) {
            if (data.size() > 5000) {
                QString fileName = isTajweedHd
                        ? QStringLiteral("page_%1_hd.jpg").arg(QString::number(pageNumber))
                        : QStringLiteral("page_%1.jpg").arg(QString::number(pageNumber));
                QString localPath = QStringLiteral("%1/%2").arg(getTajweedPagesCacheDir(riwayah), fileName);
                QFile file(localPath);
                if (file.open(QIODevice::WriteOnly)) {
                    file.write(data);
                    file.close();
                    qDebug() << "[QuranManager] Successfully cached Tajweed page" << pageNumber << "to" << localPath;
                    emit pageCached(pageNumber);
                } else {
                    qWarning() << "[QuranManager] Could not open file for writing:" << localPath << file.errorString();
                    emit pageDownloadFailed(pageNumber);
                }
            } else {
                qWarning() << "[QuranManager] Tajweed page" << pageNumber << "content too small! Size:" << data.size();
                emit pageDownloadFailed(pageNumber);
            }
        } else {
            if (data.size() > 500 && data.contains("<svg")) {
                QString cacheDir = getCacheDirectory(riwayah);
                QString localPath = QStringLiteral("%1/raw_%2.svg").arg(cacheDir, QString::number(pageNumber));
                QFile file(localPath);
                if (file.open(QIODevice::WriteOnly)) {
                    file.write(data);
                    file.close();
                    qDebug() << "[QuranManager] Successfully cached page" << pageNumber << "to" << localPath;
                    emit pageCached(pageNumber);
                } else {
                    qWarning() << "[QuranManager] Could not open file for writing:" << localPath << file.errorString();
                    emit pageDownloadFailed(pageNumber);
                }
            } else {
                qWarning() << "[QuranManager] Page" << pageNumber << "content is not valid SVG! Size:" << data.size();
                emit pageDownloadFailed(pageNumber);
            }
        }
    } else {
        qWarning() << "[QuranManager] Page" << pageNumber << "download failed with error:" << reply->errorString();
        emit pageDownloadFailed(pageNumber);
    }
    reply->deleteLater();
}

QVariantList QuranManager::getAvailableReciters()
{
    QVariantList list;
    if (m_db.isOpen()) {
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral("SELECT reciters_json FROM riwayat WHERE id = ?"));
        q.addBindValue(m_riwayah);
        if (q.exec() && q.next()) {
            QByteArray jsonBytes = q.value(0).toByteArray();
            QJsonDocument doc = QJsonDocument::fromJson(jsonBytes);
            if (doc.isArray()) {
                QJsonArray arr = doc.array();
                for (const QJsonValue &v : arr) {
                    list.append(v.toObject().toVariantMap());
                }
            }
        }
    }

    if (list.isEmpty()) {
        if (m_riwayah == 2) {
            QVariantMap r1;
            r1[QStringLiteral("id")] = QStringLiteral("abdulbasit_warsh");
            r1[QStringLiteral("name_ar")] = QString::fromUtf8("عبد الباسط عبد الصمد (ورش)");
            r1[QStringLiteral("name_en")] = QStringLiteral("Abdul Basit (Warsh)");
            r1[QStringLiteral("url_template")] = QStringLiteral("https://everyayah.com/data/warsh/warsh_Abdul_Basit_128kbps/{surah:03d}{ayah:03d}.mp3");
            list.append(r1);

            QVariantMap r2;
            r2[QStringLiteral("id")] = QStringLiteral("yassin_al_jazaery");
            r2[QStringLiteral("name_ar")] = QString::fromUtf8("ياسين الجزائري (ورش)");
            r2[QStringLiteral("name_en")] = QStringLiteral("Yassin Al-Jazaery (Warsh)");
            r2[QStringLiteral("url_template")] = QStringLiteral("https://everyayah.com/data/warsh/warsh_yassin_al_jazaery_64kbps/{surah:03d}{ayah:03d}.mp3");
            list.append(r2);

            QVariantMap r3;
            r3[QStringLiteral("id")] = QStringLiteral("ibrahim_aldosary");
            r3[QStringLiteral("name_ar")] = QString::fromUtf8("إبراهيم الدوسري (ورش)");
            r3[QStringLiteral("name_en")] = QStringLiteral("Ibrahim Al-Dosary (Warsh)");
            r3[QStringLiteral("url_template")] = QStringLiteral("https://everyayah.com/data/warsh/warsh_ibrahim_aldosary_128kbps/{surah:03d}{ayah:03d}.mp3");
            list.append(r3);
        } else {
            QVariantMap r1;
            r1[QStringLiteral("id")] = QStringLiteral("alafasy");
            r1[QStringLiteral("name_ar")] = QString::fromUtf8("مشاري راشد العفاسي");
            r1[QStringLiteral("name_en")] = QStringLiteral("Mishary Rashid Alafasy");
            r1[QStringLiteral("url_template")] = QStringLiteral("https://everyayah.com/data/Alafasy_128kbps/{surah:03d}{ayah:03d}.mp3");
            list.append(r1);

            QVariantMap r2;
            r2[QStringLiteral("id")] = QStringLiteral("minshawi");
            r2[QStringLiteral("name_ar")] = QString::fromUtf8("محمد صديق المنشاوي (مرتل)");
            r2[QStringLiteral("name_en")] = QStringLiteral("Mohamed Siddiq Al-Minshawi");
            r2[QStringLiteral("url_template")] = QStringLiteral("https://everyayah.com/data/Minshawy_Murattal_128kbps/{surah:03d}{ayah:03d}.mp3");
            list.append(r2);

            QVariantMap r3;
            r3[QStringLiteral("id")] = QStringLiteral("husary");
            r3[QStringLiteral("name_ar")] = QString::fromUtf8("محمود خليل الحصري (مرتل)");
            r3[QStringLiteral("name_en")] = QStringLiteral("Mahmoud Khalil Al-Husary");
            r3[QStringLiteral("url_template")] = QStringLiteral("https://everyayah.com/data/Husary_128kbps/{surah:03d}{ayah:03d}.mp3");
            list.append(r3);

            QVariantMap r4;
            r4[QStringLiteral("id")] = QStringLiteral("abdulbasit");
            r4[QStringLiteral("name_ar")] = QString::fromUtf8("عبد الباسط عبد الصمد (مرتل)");
            r4[QStringLiteral("name_en")] = QStringLiteral("Abdul Basit (Murattal)");
            r4[QStringLiteral("url_template")] = QStringLiteral("https://everyayah.com/data/Abdul_Basit_Murattal_192kbps/{surah:03d}{ayah:03d}.mp3");
            list.append(r4);
        }
    }
    return list;
}

void QuranManager::setReciter(const QString &reciterId)
{
    if (m_selectedReciterId != reciterId) {
        m_selectedReciterId = reciterId;
        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        s.setValue(QStringLiteral("quran/reciterId"), m_selectedReciterId);
        s.sync();
        emit reciterChanged();
    }
}

QStringList QuranManager::favoriteReciters() const
{
    return m_favoriteReciters;
}

bool QuranManager::isReciterFavorite(const QString &reciterId) const
{
    return m_favoriteReciters.contains(reciterId);
}

void QuranManager::toggleReciterFavorite(const QString &reciterId)
{
    if (reciterId.isEmpty()) return;
    if (m_favoriteReciters.contains(reciterId)) {
        m_favoriteReciters.removeAll(reciterId);
    } else {
        m_favoriteReciters.append(reciterId);
    }
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    s.setValue(QStringLiteral("quran/favoriteReciters"), m_favoriteReciters);
    s.sync();
    emit favoriteRecitersChanged();
}

void QuranManager::setReciterFavorite(const QString &reciterId, bool favorite)
{
    if (reciterId.isEmpty()) return;
    bool changed = false;
    if (favorite && !m_favoriteReciters.contains(reciterId)) {
        m_favoriteReciters.append(reciterId);
        changed = true;
    } else if (!favorite && m_favoriteReciters.contains(reciterId)) {
        m_favoriteReciters.removeAll(reciterId);
        changed = true;
    }
    if (changed) {
        QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
        s.setValue(QStringLiteral("quran/favoriteReciters"), m_favoriteReciters);
        s.sync();
        emit favoriteRecitersChanged();
    }
}

QString QuranManager::getAudioCacheDirectory(const QString &reciterId) const
{
    QString baseDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (baseDir.isEmpty()) {
        baseDir = QDir::homePath() + QStringLiteral("/.local/share/org.hafsoftdz/harbour-thakir");
    }
    QString rId = reciterId.isEmpty() ? m_selectedReciterId : reciterId;
    if (rId.isEmpty()) rId = QStringLiteral("default");
    QString path = QStringLiteral("%1/quran_audio/%2").arg(baseDir, rId);
    QDir().mkpath(path);
    return path;
}

QString QuranManager::getLocalAudioPath(const QString &reciterId, int surah, int ayah) const
{
    int effAyah = getEffectiveAudioAyah(reciterId, surah, ayah);
    return getLocalAudioPathByAudioAyah(reciterId, surah, effAyah);
}

QString QuranManager::getLocalAudioPathByAudioAyah(const QString &reciterId, int surah, int audioAyah) const
{
    QString dir = getAudioCacheDirectory(reciterId);
    return QStringLiteral("%1/%2%3.mp3")
            .arg(dir)
            .arg(surah, 3, 10, QLatin1Char('0'))
            .arg(audioAyah, 3, 10, QLatin1Char('0'));
}

QString QuranManager::getBundledAudioFix(const QString &reciterId, int surah, int audioAyah) const
{
    QString rId = reciterId.isEmpty() ? m_selectedReciterId : reciterId;
    QString subPath = QStringLiteral("data/audio_fixes/%1/%2%3.mp3")
            .arg(rId)
            .arg(surah, 3, 10, QLatin1Char('0'))
            .arg(audioAyah, 3, 10, QLatin1Char('0'));

    QString bundled = SailfishApp::pathTo(subPath).toLocalFile();
    if (QFile::exists(bundled) && QFile(bundled).size() > 1000) {
        return bundled;
    }
    if (QFile::exists(subPath) && QFile(subPath).size() > 1000) {
        return QFileInfo(subPath).absoluteFilePath();
    }
    return QString();
}

QString QuranManager::getAyahAudioUrl(const QString &reciterId, int surah, int ayah) const
{
    int effAyah = getEffectiveAudioAyah(reciterId, surah, ayah);
    return getAyahAudioUrlByAudioAyah(reciterId, surah, effAyah);
}

QString QuranManager::getAyahAudioUrlByAudioAyah(const QString &reciterId, int surah, int audioAyah) const
{
    QString rId = reciterId.isEmpty() ? m_selectedReciterId : reciterId;
    QString urlTemplate;
    QVariantList reciters = const_cast<QuranManager*>(this)->getAvailableReciters();
    for (const QVariant &r : reciters) {
        QVariantMap m = r.toMap();
        if (m.value(QStringLiteral("id")).toString() == rId) {
            urlTemplate = m.value(QStringLiteral("url_template")).toString();
            break;
        }
    }
    if (urlTemplate.isEmpty() && !reciters.isEmpty()) {
        urlTemplate = reciters.first().toMap().value(QStringLiteral("url_template")).toString();
    }
    if (urlTemplate.isEmpty()) return QString();

    QString audioUrl = urlTemplate;
    audioUrl.replace(QStringLiteral("{surah:03d}"), QStringLiteral("%1").arg(surah, 3, 10, QLatin1Char('0')));
    audioUrl.replace(QStringLiteral("{ayah:03d}"), QStringLiteral("%1").arg(audioAyah, 3, 10, QLatin1Char('0')));
    return audioUrl;
}

void QuranManager::cacheAyahAudioInBackground(const QString &reciterId, int surah, int ayah)
{
    int effAyah = getEffectiveAudioAyah(reciterId, surah, ayah);
    cacheAyahAudioInBackgroundByAudioAyah(reciterId, surah, effAyah);
}

void QuranManager::cacheAyahAudioInBackgroundByAudioAyah(const QString &reciterId, int surah, int audioAyah)
{
    QString bundledFix = getBundledAudioFix(reciterId, surah, audioAyah);
    QString localPath = getLocalAudioPathByAudioAyah(reciterId, surah, audioAyah);
    if (!bundledFix.isEmpty()) {
        if (!QFile::exists(localPath) || QFile(localPath).size() != QFile(bundledFix).size()) {
            QFile::remove(localPath);
            QFile::copy(bundledFix, localPath);
        }
        return;
    }

    if (QFile::exists(localPath) && QFile(localPath).size() > 1000) return;

    QString urlStr = getAyahAudioUrlByAudioAyah(reciterId, surah, audioAyah);
    if (urlStr.isEmpty()) return;

    QUrl url(urlStr);
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Mozilla/5.0"));
    req.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);

    QNetworkReply *reply = m_netManager->get(req);
    reply->setProperty("savePath", localPath);
    connect(reply, &QNetworkReply::finished, this, [reply]() {
        if (reply->error() == QNetworkReply::NoError) {
            QByteArray data = reply->readAll();
            if (data.size() > 1000) {
                QString path = reply->property("savePath").toString();
                QFile f(path);
                if (f.open(QIODevice::WriteOnly)) {
                    f.write(data);
                    f.close();
                }
            }
        }
        reply->deleteLater();
    });
}

void QuranManager::playCurrentAudioSubPart()
{
    if (m_currentAyahAudioFiles.isEmpty() || m_currentAudioFileIndex >= m_currentAyahAudioFiles.size()) {
        return;
    }

    int audioAyah = m_currentAyahAudioFiles.at(m_currentAudioFileIndex);
    QString bundledFix = getBundledAudioFix(m_selectedReciterId, m_playingSurah, audioAyah);
    QString localPath = getLocalAudioPathByAudioAyah(m_selectedReciterId, m_playingSurah, audioAyah);
    if (!bundledFix.isEmpty()) {
        if (!QFile::exists(localPath) || QFile(localPath).size() != QFile(bundledFix).size()) {
            QFile::remove(localPath);
            QFile::copy(bundledFix, localPath);
        }
        qDebug() << "[QuranManager] Playing bundled fixed audio:" << bundledFix;
        m_player->setMedia(QUrl::fromLocalFile(bundledFix));
    } else if (QFile::exists(localPath) && QFile(localPath).size() > 1000) {
        qDebug() << "[QuranManager] Playing offline local audio:" << localPath;
        m_player->setMedia(QUrl::fromLocalFile(localPath));
    } else {
        QString audioUrl = getAyahAudioUrlByAudioAyah(m_selectedReciterId, m_playingSurah, audioAyah);
        if (audioUrl.isEmpty()) return;
        qDebug() << "[QuranManager] Streaming audio from internet:" << audioUrl;
        emit audioStreamingNotice(m_playingSurah, audioAyah);
        m_player->setMedia(QUrl(audioUrl));
        cacheAyahAudioInBackgroundByAudioAyah(m_selectedReciterId, m_playingSurah, audioAyah);
    }
    m_player->play();
}

void QuranManager::playAyah(int surah, int ayah)
{
    m_playingSurah = surah;
    m_playingAyah = ayah;

    recordAyahListened(surah, ayah);

    QVariantMap sInfo = getSurah(surah);
    m_maxAyahInPlayingSurah = sInfo.value(QStringLiteral("total_verses"), 7).toInt();

    m_currentAyahAudioFiles = getAudioFilesForAyah(m_selectedReciterId, surah, ayah);
    m_currentAudioFileIndex = 0;

    playCurrentAudioSubPart();

    // Check if this ayah starts with an offset in the audio file (e.g. Warsh 2 in Surah 5)
    int seekMs = getAudioStartOffsetMs(m_selectedReciterId, surah, ayah);
    if (seekMs > 0 && m_player) {
        m_player->setPosition(seekMs);
    }

    emit audioStateChanged();
    emit playingAyahChanged();

    // Proactively pre-render the next ayah into RAM cache so transition between verses is instant and never blanks
    preloadNextAyahPage(surah, ayah);
}

void QuranManager::preloadNextAyahPage(int surah, int ayah)
{
    if (surah <= 0 || ayah <= 0 || !m_db.isOpen()) return;

    int nextSurah = surah;
    int nextAyah = ayah + 1;
    if (nextAyah > m_maxAyahInPlayingSurah) {
        if (surah < 114) {
            nextSurah = surah + 1;
            nextAyah = 1;
        } else {
            return;
        }
    }

    int rId = m_riwayah;
    bool dark = m_darkMode;

    int nextPage = 0;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT page_number FROM ayahs WHERE riwayah_id = ? AND surah_number = ? AND ayah_number = ?"));
    q.addBindValue(rId);
    q.addBindValue(nextSurah);
    q.addBindValue(nextAyah);
    if (q.exec() && q.next()) {
        nextPage = q.value(0).toInt();
    }

    if (nextPage > 0) {
        // Ensure raw SVG or Tajweed image is downloaded if needed
        preloadPage(nextPage);

        // Pre-render into RAM cache on background worker thread
        bool tajweed = (m_tajweedMode && isTajweedMushafAvailable(rId));
        QThreadPool::globalInstance()->start(new PreloadNextAyahRunnable(this, nextPage, nextSurah, nextAyah, rId, dark, tajweed));
    }
}

void QuranManager::playSurah(int surah, int startAyah)
{
    playAyah(surah, startAyah);
}

void QuranManager::pauseAudio()
{
    if (m_player) {
        m_player->pause();
        emit audioStateChanged();
    }
}

void QuranManager::resumeAudio()
{
    if (m_player) {
        m_player->play();
        emit audioStateChanged();
    }
}

void QuranManager::stopAudio()
{
    if (m_player) {
        m_player->stop();
        m_playingSurah = 0;
        m_playingAyah = 0;
        m_currentAyahAudioFiles.clear();
        m_currentAudioFileIndex = 0;
        m_pendingSeekMs = 0;
        m_audioProgress = 0.0;
        emit audioStateChanged();
        emit playingAyahChanged();
        emit audioProgressChanged();
    }
}

void QuranManager::onMediaStatusChanged(QMediaPlayer::MediaStatus status)
{
    emit audioStateChanged();

    // If media has buffered or loaded and we have a pending seek offset (e.g. Warsh 2 in Surah 5)
    if (m_pendingSeekMs > 0 && (status == QMediaPlayer::BufferedMedia || status == QMediaPlayer::LoadedMedia)) {
        if (m_player) {
            m_player->setPosition(m_pendingSeekMs);
        }
        m_pendingSeekMs = 0;
    }

    // Auto-advance to next sub-part or next ayah when current finishes
    if (status == QMediaPlayer::EndOfMedia) {
        // If current ayah spans multiple audio files (e.g. Warsh 1 spanning Hafs 1 + 2),
        // play the next sub-part while keeping m_playingAyah and the highlight intact!
        m_currentAudioFileIndex++;
        if (m_currentAudioFileIndex < m_currentAyahAudioFiles.size()) {
            qDebug() << "[QuranManager] Playing next sub-part" << m_currentAudioFileIndex
                     << "for Surah" << m_playingSurah << "Ayah" << m_playingAyah;
            playCurrentAudioSubPart();
            return;
        }

        // All audio sub-parts for this ayah finished. Advance to next distinct ayah
        int curLastAudioAyah = m_currentAyahAudioFiles.isEmpty() ? m_playingAyah : m_currentAyahAudioFiles.last();
        int nextAyah = m_playingAyah + 1;

        // Skip any subsequent Warsh ayahs whose audio files were already fully covered (if no startMs offset)
        while (nextAyah <= m_maxAyahInPlayingSurah) {
            QList<int> nextFiles = getAudioFilesForAyah(m_selectedReciterId, m_playingSurah, nextAyah);
            int nextStartOffset = getAudioStartOffsetMs(m_selectedReciterId, m_playingSurah, nextAyah);
            if (!nextFiles.isEmpty() && nextFiles.first() <= curLastAudioAyah && nextFiles.last() <= curLastAudioAyah && nextStartOffset == 0) {
                nextAyah++;
            } else {
                break;
            }
        }

        if (nextAyah <= m_maxAyahInPlayingSurah) {
            playAyah(m_playingSurah, nextAyah);
        } else {
            // Surah finished: proceed to next surah if valid
            if (m_playingSurah < 114) {
                playAyah(m_playingSurah + 1, 1);
            } else {
                stopAudio();
            }
        }
    }
}

void QuranManager::onPositionChanged(qint64 position)
{
    if (m_currentDuration > 0) {
        m_audioProgress = qBound(0.0, static_cast<double>(position) / static_cast<double>(m_currentDuration), 1.0);
        emit audioProgressChanged();
    }

    // Check intra-file ayah transitions (e.g. Surah 5 Ayah 1 -> Ayah 2 at 4800ms)
    if (m_riwayah == 2 && reciterNeedsHafsMapping(m_selectedReciterId) && m_playingAyah > 0) {
        quint32 key = (static_cast<quint32>(m_playingSurah) << 16) | static_cast<quint32>(m_playingAyah);
        if (m_warshToHafsMap.contains(key)) {
            HafsRange range = m_warshToHafsMap.value(key);
            if (range.endMs > 0 && position >= range.endMs) {
                int nextAyah = m_playingAyah + 1;
                if (nextAyah <= m_maxAyahInPlayingSurah) {
                    quint32 nextKey = (static_cast<quint32>(m_playingSurah) << 16) | static_cast<quint32>(nextAyah);
                    if (m_warshToHafsMap.contains(nextKey)) {
                        HafsRange nextRange = m_warshToHafsMap.value(nextKey);
                        if (nextRange.start == range.end) {
                            m_playingAyah = nextAyah;
                            emit playingAyahChanged();
                        }
                    }
                }
            }
        }
    }
}

void QuranManager::onDurationChanged(qint64 duration)
{
    m_currentDuration = duration;
}

bool QuranManager::isBookmarked(int surah, int ayah)
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    QStringList bmarks = s.value(QStringLiteral("quran/bookmarks")).toStringList();
    QString key = QStringLiteral("%1:%2").arg(surah).arg(ayah);
    return bmarks.contains(key);
}

bool QuranManager::toggleBookmark(int surah, int ayah)
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    QStringList bmarks = s.value(QStringLiteral("quran/bookmarks")).toStringList();
    QString key = QStringLiteral("%1:%2").arg(surah).arg(ayah);

    bool added = false;
    if (bmarks.contains(key)) {
        bmarks.removeAll(key);
        added = false;
    } else {
        bmarks.append(key);
        added = true;
    }

    s.setValue(QStringLiteral("quran/bookmarks"), bmarks);
    s.sync();
    emit bookmarksChanged();
    return added;
}

void QuranManager::removeBookmark(int surah, int ayah)
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    QStringList bmarks = s.value(QStringLiteral("quran/bookmarks")).toStringList();
    QString key = QStringLiteral("%1:%2").arg(surah).arg(ayah);

    if (bmarks.contains(key)) {
        bmarks.removeAll(key);
        s.setValue(QStringLiteral("quran/bookmarks"), bmarks);
        s.sync();
        emit bookmarksChanged();
    }
}

void QuranManager::clearAllBookmarks()
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    s.remove(QStringLiteral("quran/bookmarks"));
    s.sync();
    emit bookmarksChanged();
}

QVariantList QuranManager::getBookmarks()
{
    QVariantList list;
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    QStringList bmarks = s.value(QStringLiteral("quran/bookmarks")).toStringList();

    for (const QString &b : bmarks) {
        QStringList parts = b.split(QLatin1Char(':'));
        if (parts.size() == 2) {
            int sNum = parts[0].toInt();
            int aNum = parts[1].toInt();

            QVariantMap m;
            m[QStringLiteral("surah_number")] = sNum;
            m[QStringLiteral("ayah_number")] = aNum;

            // Fetch ayah text and surah name
            if (m_db.isOpen()) {
                QSqlQuery q(m_db);
                q.prepare(QStringLiteral("SELECT a.text_uthmani, a.page_number, s.name_ar, s.name_en FROM ayahs a JOIN surahs s ON a.surah_number = s.number WHERE a.riwayah_id = ? AND a.surah_number = ? AND a.ayah_number = ?"));
                q.addBindValue(m_riwayah);
                q.addBindValue(sNum);
                q.addBindValue(aNum);
                if (q.exec() && q.next()) {
                    m[QStringLiteral("text_uthmani")] = cleanUthmaniText(q.value(0).toString(), m_riwayah);
                    m[QStringLiteral("page_number")] = getPageForAyah(sNum, aNum, m_riwayah);
                    m[QStringLiteral("surah_name_ar")] = q.value(2).toString();
                    m[QStringLiteral("surah_name_en")] = q.value(3).toString();
                }
            }
            list.append(m);
        }
    }
    return list;
}

void QuranManager::saveLastPosition(int surah, int ayah, int page)
{
    if (!m_db.isOpen()) return;

    int sNum = qBound(1, surah, 114);

    int maxVerses = 0;
    QSqlQuery qCount(m_db);
    qCount.prepare(QStringLiteral("SELECT COUNT(*) FROM ayahs WHERE riwayah_id = ? AND surah_number = ?"));
    qCount.addBindValue(m_riwayah);
    qCount.addBindValue(sNum);
    if (qCount.exec() && qCount.next()) {
        maxVerses = qCount.value(0).toInt();
    }
    int aNum = (maxVerses > 0) ? qBound(1, ayah, maxVerses) : qMax(1, ayah);

    // Look up the true page number for this (surah, ayah) in the current riwayah
    int pNum = getPageForAyah(sNum, aNum, m_riwayah);
    if (pNum < 1 || pNum > maxPages()) {
        pNum = qBound(1, page, maxPages());
    }

    m_lastSurah = sNum;
    m_lastAyah = aNum;
    m_lastPage = pNum;

    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    s.setValue(QStringLiteral("quran/lastSurah"), m_lastSurah);
    s.setValue(QStringLiteral("quran/lastAyah"), m_lastAyah);
    s.setValue(QStringLiteral("quran/lastPage"), m_lastPage);
    s.sync();

    emit lastPositionChanged();
}

int QuranManager::downloadedPagesCount() const
{
    return getDownloadedPagesCount(m_isDownloadingPages ? m_bulkPagesRiwayah : m_riwayah);
}

double QuranManager::pagesDownloadProgress() const
{
    if (m_bulkPagesTotalInBatch <= 0) return 0.0;
    return qBound(0.0, (double)m_bulkPagesDownloadedInBatch / (double)m_bulkPagesTotalInBatch, 1.0);
}

int QuranManager::getDownloadedPagesCount(int riwayahId) const
{
    if (riwayahId != 1 && riwayahId != 2) riwayahId = m_riwayah;
    int count = 0;
    for (int p = 1; p <= 604; ++p) {
        if (QFile::exists(getLocalPagePath(riwayahId, p))) count++;
    }
    return count;
}

qint64 QuranManager::getPagesCacheSize(int riwayahId) const
{
    if (riwayahId != 1 && riwayahId != 2) riwayahId = m_riwayah;
    QString dir = getCacheDirectory(riwayahId);
    QDir d(dir);
    qint64 total = 0;
    const QFileInfoList list = d.entryInfoList(QDir::Files);
    for (const QFileInfo &fi : list) {
        total += fi.size();
    }

    QString renderedDir = getRenderedPagesCacheDir();
    QDir rd(renderedDir);
    const QFileInfoList rList = rd.entryInfoList(QDir::Files);
    for (const QFileInfo &fi : rList) {
        total += fi.size();
    }

    return total;
}

void QuranManager::clearPagesCache(int riwayahId)
{
    cancelBulkPagesDownload();
    if (riwayahId != 1 && riwayahId != 2) riwayahId = m_riwayah;
    QString dir = getCacheDirectory(riwayahId);
    QDir d(dir);
    const QFileInfoList list = d.entryInfoList(QDir::Files);
    for (const QFileInfo &fi : list) {
        QFile::remove(fi.absoluteFilePath());
    }

    QString renderedDir = getRenderedPagesCacheDir();
    QDir rd(renderedDir);
    const QFileInfoList rList = rd.entryInfoList(QDir::Files);
    for (const QFileInfo &fi : rList) {
        QFile::remove(fi.absoluteFilePath());
    }

    QMutexLocker locker(&m_renderMutex);
    m_pageImageCache.clear();
    m_memCachedPageNumber = -1;
    m_memCachedSvgContent.clear();
    emit bulkPagesProgressChanged();
    emit pageCached(1);
}

bool QuranManager::isOnline() const
{
    if (m_netManager && m_netManager->networkAccessible() == QNetworkAccessManager::NotAccessible) {
        return false;
    }
    return m_ncm.isOnline();
}

void QuranManager::startBulkPagesDownload(int riwayahId)
{
    if (riwayahId != 1 && riwayahId != 2) riwayahId = m_riwayah;
    if (!isOnline()) return;
    if (m_isDownloadingPages) return;

    m_bulkPagesRiwayah = riwayahId;
    m_bulkPagesQueue.clear();
    for (int p = 1; p <= 604; ++p) {
        if (!QFile::exists(getLocalPagePath(riwayahId, p))) {
            m_bulkPagesQueue.append(p);
        }
    }

    if (m_bulkPagesQueue.isEmpty()) {
        emit bulkPagesProgressChanged();
        return;
    }

    m_bulkPagesTotalInBatch = m_bulkPagesQueue.size();
    m_bulkPagesDownloadedInBatch = 0;
    m_bulkPagesActiveCount = 0;
    m_isDownloadingPages = true;
    emit bulkPagesProgressChanged();

    fetchNextBulkPage();
    fetchNextBulkPage();
}

void QuranManager::fetchNextBulkPage()
{
    if (!m_isDownloadingPages) return;

    if (m_bulkPagesQueue.isEmpty()) {
        if (m_bulkPagesActiveCount <= 0) {
            m_isDownloadingPages = false;
            emit bulkPagesProgressChanged();
        }
        return;
    }

    int pageNumber = m_bulkPagesQueue.takeFirst();
    m_bulkPagesActiveCount++;

    QUrl url(getRemotePageUrl(m_bulkPagesRiwayah, pageNumber));

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36"));
    req.setRawHeader("Accept", "image/svg+xml,image/*,*/*;q=0.8");
    req.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);

    QNetworkReply *reply = m_netManager->get(req);
    reply->setProperty("bulkPage", true);
    reply->setProperty("pageNumber", pageNumber);
    reply->setProperty("riwayah", m_bulkPagesRiwayah);
    reply->ignoreSslErrors();

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        int page = reply->property("pageNumber").toInt();
        int rId = reply->property("riwayah").toInt();
        m_bulkPagesActiveCount--;

        if (reply->error() == QNetworkReply::NoError) {
            QByteArray data = reply->readAll();
            if (data.size() > 500 && data.contains("<svg")) {
                QString localPath = QStringLiteral("%1/raw_%2.svg").arg(getCacheDirectory(rId), QString::number(page));
                QFile f(localPath);
                if (f.open(QIODevice::WriteOnly)) {
                    f.write(data);
                    f.close();
                    emit pageCached(page);
                }
            }
        }
        reply->deleteLater();

        if (m_isDownloadingPages) {
            m_bulkPagesDownloadedInBatch++;
            emit bulkPagesProgressChanged();
            fetchNextBulkPage();
        }
    });
}

void QuranManager::cancelBulkPagesDownload()
{
    m_isDownloadingPages = false;
    m_bulkPagesQueue.clear();
    emit bulkPagesProgressChanged();
}

int QuranManager::downloadedTajweedPagesCount() const
{
    return getDownloadedTajweedPagesCount(m_isDownloadingTajweedPages ? m_bulkTajweedPagesRiwayah : m_riwayah,
                                          m_isDownloadingTajweedPages ? m_bulkTajweedPagesHd : m_tajweedHdMode);
}

double QuranManager::tajweedPagesDownloadProgress() const
{
    if (m_bulkTajweedPagesTotalInBatch <= 0) return 0.0;
    return qBound(0.0, (double)m_bulkTajweedPagesDownloadedInBatch / (double)m_bulkTajweedPagesTotalInBatch, 1.0);
}

int QuranManager::getDownloadedTajweedPagesCount(int riwayahId, bool hd) const
{
    if (riwayahId != 1 && riwayahId != 2) riwayahId = m_riwayah;
    QString dir = getTajweedPagesCacheDir(riwayahId);
    QString exactName = hd ? QStringLiteral("page_%1_hd.jpg") : QStringLiteral("page_%1.jpg");
    int count = 0;
    for (int p = 1; p <= 604; ++p) {
        if (QFile::exists(QStringLiteral("%1/%2").arg(dir, exactName.arg(QString::number(p))))) count++;
    }
    return count;
}

qint64 QuranManager::getTajweedPagesCacheSize(int riwayahId, bool hd) const
{
    if (riwayahId != 1 && riwayahId != 2) riwayahId = m_riwayah;
    QString dir = getTajweedPagesCacheDir(riwayahId);
    QDir d(dir);
    qint64 total = 0;
    QStringList filters;
    if (hd) {
        filters << QStringLiteral("page_*_hd.jpg") << QStringLiteral("page_*_hd_*.png") << QStringLiteral("page_*_hd_*crop.png");
    } else {
        filters << QStringLiteral("page_*.jpg") << QStringLiteral("page_*_sd_*.png") << QStringLiteral("page_*_sd_*crop.png") << QStringLiteral("page_*_crop.png");
    }
    const QFileInfoList list = d.entryInfoList(filters, QDir::Files);
    for (const QFileInfo &fi : list) {
        if (!hd && fi.fileName().contains(QStringLiteral("_hd"))) continue;
        total += fi.size();
    }
    return total;
}

void QuranManager::clearTajweedPagesCache(int riwayahId, bool hd)
{
    if (m_isDownloadingTajweedPages && m_bulkTajweedPagesHd == hd) {
        cancelBulkTajweedPagesDownload();
    }
    if (riwayahId != 1 && riwayahId != 2) riwayahId = m_riwayah;
    QString dir = getTajweedPagesCacheDir(riwayahId);
    QDir d(dir);
    QStringList filters;
    if (hd) {
        filters << QStringLiteral("page_*_hd.jpg") << QStringLiteral("page_*_hd_*.png") << QStringLiteral("page_*_hd_*crop.png");
    } else {
        filters << QStringLiteral("page_*.jpg") << QStringLiteral("page_*_sd_*.png") << QStringLiteral("page_*_sd_*crop.png") << QStringLiteral("page_*_crop.png");
    }
    const QFileInfoList list = d.entryInfoList(filters, QDir::Files);
    for (const QFileInfo &fi : list) {
        if (!hd && fi.fileName().contains(QStringLiteral("_hd"))) continue;
        QFile::remove(fi.absoluteFilePath());
    }

    QMutexLocker locker(&m_renderMutex);
    m_pageImageCache.clear();
    emit bulkTajweedPagesProgressChanged();
    emit pageCached(1);
}

void QuranManager::startBulkTajweedPagesDownload(int riwayahId, bool hd)
{
    if (!isOnline()) return;
    if (riwayahId != 1 && riwayahId != 2) riwayahId = m_riwayah;
    if (!isTajweedMushafAvailable(riwayahId)) return;
    if (m_isDownloadingTajweedPages) return;

    m_bulkTajweedPagesRiwayah = riwayahId;
    m_bulkTajweedPagesHd = hd;
    m_bulkTajweedPagesQueue.clear();

    QString dir = getTajweedPagesCacheDir(riwayahId);
    QString exactName = hd ? QStringLiteral("page_%1_hd.jpg") : QStringLiteral("page_%1.jpg");

    for (int p = 1; p <= 604; ++p) {
        QString local = QStringLiteral("%1/%2").arg(dir, exactName.arg(QString::number(p)));
        if (!QFile::exists(local)) {
            m_bulkTajweedPagesQueue.append(p);
        }
    }

    if (m_bulkTajweedPagesQueue.isEmpty()) {
        emit bulkTajweedPagesProgressChanged();
        return;
    }

    m_bulkTajweedPagesTotalInBatch = m_bulkTajweedPagesQueue.size();
    m_bulkTajweedPagesDownloadedInBatch = 0;
    m_bulkTajweedPagesActiveCount = 0;
    m_isDownloadingTajweedPages = true;
    emit bulkTajweedPagesProgressChanged();

    fetchNextBulkTajweedPage();
    fetchNextBulkTajweedPage();
}

void QuranManager::cancelBulkTajweedPagesDownload()
{
    m_isDownloadingTajweedPages = false;
    m_bulkTajweedPagesQueue.clear();
    m_bulkTajweedPagesActiveCount = 0;
    emit bulkTajweedPagesProgressChanged();
}

void QuranManager::fetchNextBulkTajweedPage()
{
    if (!m_isDownloadingTajweedPages) return;

    if (m_bulkTajweedPagesQueue.isEmpty()) {
        if (m_bulkTajweedPagesActiveCount <= 0) {
            m_isDownloadingTajweedPages = false;
            emit bulkTajweedPagesProgressChanged();
        }
        return;
    }

    int pageNumber = m_bulkTajweedPagesQueue.takeFirst();
    m_bulkTajweedPagesActiveCount++;

    bool hd = m_bulkTajweedPagesHd;
    QUrl url(getRemoteTajweedPageUrl(m_bulkTajweedPagesRiwayah, pageNumber, hd));
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36"));
    req.setRawHeader("Accept", "image/jpeg,image/*,*/*;q=0.8");
    req.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);

    QNetworkReply *reply = m_netManager->get(req);
    reply->setProperty("bulkTajweedPage", true);
    reply->setProperty("pageNumber", pageNumber);
    reply->setProperty("riwayah", m_bulkTajweedPagesRiwayah);
    reply->setProperty("isHd", hd);
    reply->ignoreSslErrors();

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        int page = reply->property("pageNumber").toInt();
        int rId = reply->property("riwayah").toInt();
        bool isHd = reply->property("isHd").toBool();
        m_bulkTajweedPagesActiveCount--;

        if (reply->error() == QNetworkReply::NoError) {
            QByteArray data = reply->readAll();
            if (data.size() > 5000) {
                QString exactName = isHd ? QStringLiteral("page_%1_hd.jpg") : QStringLiteral("page_%1.jpg");
                QString localPath = QStringLiteral("%1/%2").arg(getTajweedPagesCacheDir(rId), exactName.arg(QString::number(page)));
                QFile f(localPath);
                if (f.open(QIODevice::WriteOnly)) {
                    f.write(data);
                    f.close();
                    emit pageCached(page);
                }
            }
        }
        reply->deleteLater();

        if (m_isDownloadingTajweedPages) {
            m_bulkTajweedPagesDownloadedInBatch++;
            emit bulkTajweedPagesProgressChanged();
            fetchNextBulkTajweedPage();
        }
    });
}

int QuranManager::downloadedAlgeriaPagesCount() const
{
    return getDownloadedAlgeriaPagesCount();
}

double QuranManager::algeriaPagesDownloadProgress() const
{
    if (m_bulkAlgeriaPagesTotalInBatch <= 0) return 0.0;
    return qBound(0.0, (double)m_bulkAlgeriaPagesDownloadedInBatch / (double)m_bulkAlgeriaPagesTotalInBatch, 1.0);
}

int QuranManager::getDownloadedAlgeriaPagesCount() const
{
    QString dir = getAlgeriaPagesCacheDir();
    int count = 0;
    for (int p = 1; p <= 706; ++p) {
        if (QFile::exists(QStringLiteral("%1/page_%2.jpg").arg(dir, QString::number(p)))) {
            count++;
        }
    }
    return count;
}

qint64 QuranManager::getAlgeriaPagesCacheSize() const
{
    QString dir = getAlgeriaPagesCacheDir();
    QDir d(dir);
    qint64 total = 0;
    const QFileInfoList list = d.entryInfoList(QDir::Files);
    for (const QFileInfo &fi : list) {
        total += fi.size();
    }
    return total;
}

void QuranManager::clearAlgeriaPagesCache()
{
    if (m_isDownloadingAlgeriaPages) {
        cancelBulkAlgeriaPagesDownload();
    }
    QString dir = getAlgeriaPagesCacheDir();
    QDir d(dir);
    const QFileInfoList list = d.entryInfoList(QDir::Files);
    for (const QFileInfo &fi : list) {
        QFile::remove(fi.absoluteFilePath());
    }

    QMutexLocker locker(&m_renderMutex);
    m_pageImageCache.clear();
    emit bulkAlgeriaPagesProgressChanged();
    emit pageCached(1);
}

void QuranManager::startBulkAlgeriaPagesDownload()
{
    if (!isOnline()) return;
    if (m_isDownloadingAlgeriaPages) return;

    m_bulkAlgeriaPagesQueue.clear();
    QString dir = getAlgeriaPagesCacheDir();

    for (int p = 1; p <= 706; ++p) {
        QString local = QStringLiteral("%1/page_%2.jpg").arg(dir, QString::number(p));
        if (!QFile::exists(local)) {
            m_bulkAlgeriaPagesQueue.append(p);
        }
    }

    if (m_bulkAlgeriaPagesQueue.isEmpty()) {
        emit bulkAlgeriaPagesProgressChanged();
        return;
    }

    m_bulkAlgeriaPagesTotalInBatch = m_bulkAlgeriaPagesQueue.size();
    m_bulkAlgeriaPagesDownloadedInBatch = 0;
    m_bulkAlgeriaPagesActiveCount = 0;
    m_isDownloadingAlgeriaPages = true;
    emit bulkAlgeriaPagesProgressChanged();

    fetchNextBulkAlgeriaPage();
    fetchNextBulkAlgeriaPage();
}

void QuranManager::cancelBulkAlgeriaPagesDownload()
{
    m_isDownloadingAlgeriaPages = false;
    m_bulkAlgeriaPagesQueue.clear();
    m_bulkAlgeriaPagesActiveCount = 0;
    emit bulkAlgeriaPagesProgressChanged();
}

void QuranManager::fetchNextBulkAlgeriaPage()
{
    if (!m_isDownloadingAlgeriaPages) return;

    if (m_bulkAlgeriaPagesQueue.isEmpty()) {
        if (m_bulkAlgeriaPagesActiveCount <= 0) {
            m_isDownloadingAlgeriaPages = false;
            emit bulkAlgeriaPagesProgressChanged();
        }
        return;
    }

    int pageNumber = m_bulkAlgeriaPagesQueue.takeFirst();
    m_bulkAlgeriaPagesActiveCount++;

    QUrl url(getRemoteAlgeriaPageUrl(pageNumber));
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36"));
    req.setRawHeader("Accept", "image/jpeg,image/*,*/*;q=0.8");
    req.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);

    QNetworkReply *reply = m_netManager->get(req);
    reply->setProperty("bulkAlgeriaPage", true);
    reply->setProperty("pageNumber", pageNumber);
    reply->ignoreSslErrors();

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        int page = reply->property("pageNumber").toInt();
        m_bulkAlgeriaPagesActiveCount--;

        if (reply->error() == QNetworkReply::NoError) {
            QByteArray data = reply->readAll();
            if (data.size() > 5000) {
                QString localPath = getLocalAlgeriaPagePath(page);
                QFile f(localPath);
                if (f.open(QIODevice::WriteOnly)) {
                    f.write(data);
                    f.close();
                    emit pageCached(page);
                }
            }
        }
        reply->deleteLater();

        if (m_isDownloadingAlgeriaPages) {
            m_bulkAlgeriaPagesDownloadedInBatch++;
            emit bulkAlgeriaPagesProgressChanged();
            fetchNextBulkAlgeriaPage();
        }
    });
}

int QuranManager::downloadedAudioCount() const
{
    return getDownloadedAudioCount(m_selectedReciterId);
}

double QuranManager::audioDownloadProgress() const
{
    if (m_audioTotalInBatch <= 0) return 0.0;
    return qBound(0.0, (double)m_audioDownloadedInBatch / (double)m_audioTotalInBatch, 1.0);
}

int QuranManager::getDownloadedAudioCount(const QString &reciterId) const
{
    QString rId = reciterId.isEmpty() ? m_selectedReciterId : reciterId;
    QString dir = getAudioCacheDirectory(rId);
    QDir d(dir);
    QStringList files = d.entryList(QStringList() << QStringLiteral("*.mp3"), QDir::Files);
    return files.size();
}

qint64 QuranManager::getAudioCacheSize(const QString &reciterId) const
{
    QString rId = reciterId.isEmpty() ? m_selectedReciterId : reciterId;
    QString dir = getAudioCacheDirectory(rId);
    QDir d(dir);
    qint64 total = 0;
    const QFileInfoList list = d.entryInfoList(QDir::Files);
    for (const QFileInfo &fi : list) {
        total += fi.size();
    }
    return total;
}

void QuranManager::clearAudioCache(const QString &reciterId)
{
    cancelAudioDownload();
    QString rId = reciterId.isEmpty() ? m_selectedReciterId : reciterId;
    QString dir = getAudioCacheDirectory(rId);
    QDir d(dir);
    const QFileInfoList list = d.entryInfoList(QDir::Files);
    for (const QFileInfo &fi : list) {
        QFile::remove(fi.absoluteFilePath());
    }
    emit audioDownloadProgressChanged();
}

bool QuranManager::isAyahAudioCached(int surah, int ayah, const QString &reciterId) const
{
    QString rId = reciterId.isEmpty() ? m_selectedReciterId : reciterId;
    QList<int> files = getAudioFilesForAyah(rId, surah, ayah);
    if (files.isEmpty()) files.append(ayah);
    for (int audioAyah : files) {
        if (!getBundledAudioFix(rId, surah, audioAyah).isEmpty()) continue;
        QString path = getLocalAudioPathByAudioAyah(rId, surah, audioAyah);
        if (!QFile::exists(path) || QFile(path).size() <= 1000) return false;
    }
    return true;
}

bool QuranManager::isSurahAudioCached(int surah, const QString &reciterId) const
{
    QString rId = reciterId.isEmpty() ? m_selectedReciterId : reciterId;
    QVariantMap sInfo = const_cast<QuranManager*>(this)->getSurah(surah);
    int total = sInfo.value(QStringLiteral("total_verses"), 0).toInt();
    if (total <= 0) return false;
    for (int a = 1; a <= total; ++a) {
        if (!isAyahAudioCached(surah, a, rId)) return false;
    }
    return true;
}

void QuranManager::startSurahAudioDownload(int surahNumber, const QString &reciterId)
{
    if (!isOnline()) return;
    QString rId = reciterId.isEmpty() ? m_selectedReciterId : reciterId;
    if (rId.isEmpty()) return;

    QVariantMap sInfo = getSurah(surahNumber);
    int totalVerses = sInfo.value(QStringLiteral("total_verses"), 0).toInt();
    if (totalVerses <= 0) return;

    cancelAudioDownload();

    m_audioDownloadQueue.clear();
    m_audioTotalInBatch = 0;
    m_audioDownloadedInBatch = 0;

    QSet<QString> queuedPaths;
    for (int a = 1; a <= totalVerses; ++a) {
        QList<int> files = getAudioFilesForAyah(rId, surahNumber, a);
        for (int audioAyah : files) {
            QString localPath = getLocalAudioPathByAudioAyah(rId, surahNumber, audioAyah);
            if ((!QFile::exists(localPath) || QFile(localPath).size() < 1000) && !queuedPaths.contains(localPath)) {
                queuedPaths.insert(localPath);
                AudioItem item;
                item.surah = surahNumber;
                item.ayah = audioAyah;
                item.reciterId = rId;
                m_audioDownloadQueue.append(item);
                m_audioTotalInBatch++;
            }
        }
    }

    if (m_audioDownloadQueue.isEmpty()) {
        m_audioDownloadStatus = QString::fromUtf8("تم تحميل سورة %1 مسبقاً").arg(sInfo.value(QStringLiteral("name_ar")).toString());
        emit audioDownloadProgressChanged();
        return;
    }

    m_isDownloadingAudio = true;
    m_audioDownloadStatus = QString::fromUtf8("بدء تحميل سورة %1...").arg(sInfo.value(QStringLiteral("name_ar")).toString());
    emit audioDownloadProgressChanged();

    fetchNextAudio();
}

void QuranManager::startFullAudioDownload(const QString &reciterId)
{
    if (!isOnline()) return;
    QString rId = reciterId.isEmpty() ? m_selectedReciterId : reciterId;
    if (rId.isEmpty()) return;

    cancelAudioDownload();

    m_audioDownloadQueue.clear();
    m_audioTotalInBatch = 0;
    m_audioDownloadedInBatch = 0;

    QSet<QString> queuedFullPaths;
    for (int s = 1; s <= 114; ++s) {
        QVariantMap sInfo = getSurah(s);
        int totalVerses = sInfo.value(QStringLiteral("total_verses"), 0).toInt();
        for (int a = 1; a <= totalVerses; ++a) {
            QList<int> files = getAudioFilesForAyah(rId, s, a);
            for (int audioAyah : files) {
                QString localPath = getLocalAudioPathByAudioAyah(rId, s, audioAyah);
                if ((!QFile::exists(localPath) || QFile(localPath).size() < 1000) && !queuedFullPaths.contains(localPath)) {
                    queuedFullPaths.insert(localPath);
                    AudioItem item;
                    item.surah = s;
                    item.ayah = audioAyah;
                    item.reciterId = rId;
                    m_audioDownloadQueue.append(item);
                    m_audioTotalInBatch++;
                }
            }
        }
    }

    if (m_audioDownloadQueue.isEmpty()) {
        m_audioDownloadStatus = QString::fromUtf8("تم تحميل التلاوة كاملة مسبقاً");
        emit audioDownloadProgressChanged();
        return;
    }

    m_isDownloadingAudio = true;
    m_audioDownloadStatus = QString::fromUtf8("بدء تحميل المصحف الصوتي كاملاً...");
    emit audioDownloadProgressChanged();

    fetchNextAudio();
}

void QuranManager::fetchNextAudio()
{
    if (!m_isDownloadingAudio) return;

    if (m_audioDownloadQueue.isEmpty()) {
        m_isDownloadingAudio = false;
        m_audioDownloadStatus = QString::fromUtf8("اكتمل التحميل بنجاح");
        emit audioDownloadProgressChanged();
        return;
    }

    AudioItem item = m_audioDownloadQueue.takeFirst();
    QString localPath = getLocalAudioPathByAudioAyah(item.reciterId, item.surah, item.ayah);

    QString bundledFix = getBundledAudioFix(item.reciterId, item.surah, item.ayah);
    if (!bundledFix.isEmpty()) {
        if (!QFile::exists(localPath) || QFile(localPath).size() != QFile(bundledFix).size()) {
            QFile::remove(localPath);
            QFile::copy(bundledFix, localPath);
        }
        m_audioDownloadedInBatch++;
        emit audioDownloadProgressChanged();
        fetchNextAudio();
        return;
    }

    if (QFile::exists(localPath) && QFile(localPath).size() > 1000) {
        m_audioDownloadedInBatch++;
        emit audioDownloadProgressChanged();
        fetchNextAudio();
        return;
    }

    QString urlStr = getAyahAudioUrlByAudioAyah(item.reciterId, item.surah, item.ayah);
    if (urlStr.isEmpty()) {
        fetchNextAudio();
        return;
    }

    QVariantMap sInfo = getSurah(item.surah);
    QString surahName = sInfo.value(QStringLiteral("name_ar")).toString();
    m_audioDownloadStatus = QString::fromUtf8("%1: آية %2 (%3/%4)")
            .arg(surahName)
            .arg(item.ayah)
            .arg(m_audioDownloadedInBatch + 1)
            .arg(m_audioTotalInBatch);
    emit audioDownloadProgressChanged();

    QUrl url(urlStr);
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Mozilla/5.0"));
    req.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);

    m_activeAudioReply = m_netManager->get(req);
    m_activeAudioReply->ignoreSslErrors();
    m_activeAudioReply->setProperty("localPath", localPath);

    connect(m_activeAudioReply, &QNetworkReply::finished, this, [this]() {
        if (!m_activeAudioReply) return;
        QNetworkReply *reply = m_activeAudioReply;
        m_activeAudioReply = nullptr;

        QString path = reply->property("localPath").toString();
        if (reply->error() == QNetworkReply::NoError) {
            QByteArray data = reply->readAll();
            if (data.size() > 1000) {
                QFile f(path);
                if (f.open(QIODevice::WriteOnly)) {
                    f.write(data);
                    f.close();
                }
            }
        }
        reply->deleteLater();

        if (m_isDownloadingAudio) {
            m_audioDownloadedInBatch++;
            emit audioDownloadProgressChanged();
            fetchNextAudio();
        }
    });
}

void QuranManager::cancelAudioDownload()
{
    m_isDownloadingAudio = false;
    m_audioDownloadQueue.clear();
    if (m_activeAudioReply) {
        m_activeAudioReply->abort();
        m_activeAudioReply->deleteLater();
        m_activeAudioReply = nullptr;
    }
    m_audioDownloadStatus = QString::fromUtf8("تم إيقاف التحميل");
    emit audioDownloadProgressChanged();
}

QString QuranManager::formatFileSize(qint64 bytes) const
{
    if (bytes < 1024) return QStringLiteral("\u200E%1 B\u200E").arg(bytes);
    if (bytes < 1024 * 1024) return QStringLiteral("\u200E%1 KB\u200E").arg(bytes / 1024.0, 0, 'f', 1);
    if (bytes < 1024 * 1024 * 1024) return QStringLiteral("\u200E%1 MB\u200E").arg(bytes / (1024.0 * 1024.0), 0, 'f', 1);
    return QStringLiteral("\u200E%1 GB\u200E").arg(bytes / (1024.0 * 1024.0 * 1024.0), 0, 'f', 2);
}

void QuranManager::recordAyahListened(int surah, int ayah)
{
    if (surah <= 0 || ayah <= 0) return;

    QString today = QDate::currentDate().toString(Qt::ISODate);
    QString key = QStringLiteral("%1:%2").arg(surah).arg(ayah);

    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    QString settingKey = QStringLiteral("quran/listeningHistory/%1").arg(today);
    QStringList ayahs = s.value(settingKey).toStringList();

    if (!ayahs.contains(key)) {
        ayahs.append(key);
        s.setValue(settingKey, ayahs);

        QStringList dateList = s.value(QStringLiteral("quran/listeningHistoryDates")).toStringList();
        if (!dateList.contains(today)) {
            dateList.append(today);
            s.setValue(QStringLiteral("quran/listeningHistoryDates"), dateList);
        }

        s.sync();
        emit listeningHistoryChanged();
    }
}

QVariantList QuranManager::getDailyListeningStats() const
{
    QVariantList result;
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    QStringList dateList = s.value(QStringLiteral("quran/listeningHistoryDates")).toStringList();

    // Sort dates descending (newest first)
    std::sort(dateList.begin(), dateList.end(), [](const QString &d1, const QString &d2) {
        return d1 > d2;
    });

    for (const QString &dStr : dateList) {
        QString settingKey = QStringLiteral("quran/listeningHistory/%1").arg(dStr);
        QStringList ayahs = s.value(settingKey).toStringList();
        if (ayahs.isEmpty()) continue;

        QDate d = QDate::fromString(dStr, Qt::ISODate);

        QVariantMap dayMap;
        dayMap[QStringLiteral("date")] = dStr;
        dayMap[QStringLiteral("count")] = ayahs.size();
        dayMap[QStringLiteral("dayOfWeek")] = d.isValid() ? d.dayOfWeek() : 0;
        dayMap[QStringLiteral("year")] = d.isValid() ? d.year() : 0;
        dayMap[QStringLiteral("month")] = d.isValid() ? d.month() : 0;
        dayMap[QStringLiteral("day")] = d.isValid() ? d.day() : 0;

        result.append(dayMap);
    }
    return result;
}

int QuranManager::getTodayListenedCount() const
{
    QString today = QDate::currentDate().toString(Qt::ISODate);
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    QString settingKey = QStringLiteral("quran/listeningHistory/%1").arg(today);
    return s.value(settingKey).toStringList().size();
}

int QuranManager::getTotalListenedCount() const
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    QStringList dateList = s.value(QStringLiteral("quran/listeningHistoryDates")).toStringList();
    QSet<QString> allUniqueAyahs;

    for (const QString &dStr : dateList) {
        QString settingKey = QStringLiteral("quran/listeningHistory/%1").arg(dStr);
        QStringList ayahs = s.value(settingKey).toStringList();
        for (const QString &a : ayahs) {
            allUniqueAyahs.insert(a);
        }
    }
    return allUniqueAyahs.size();
}

void QuranManager::clearListeningHistory()
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    QStringList dateList = s.value(QStringLiteral("quran/listeningHistoryDates")).toStringList();
    for (const QString &dStr : dateList) {
        s.remove(QStringLiteral("quran/listeningHistory/%1").arg(dStr));
    }
    s.remove(QStringLiteral("quran/listeningHistory"));
    s.remove(QStringLiteral("quran/listeningHistoryDates"));
    s.sync();
    emit listeningHistoryChanged();
}

bool QuranManager::shouldShowTextModeDisclaimer(const QString &appVersion) const
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    QString confirmedVersion = s.value(QStringLiteral("quran/disclaimer_confirmed_version")).toString();
    bool isConfirmed = s.value(QStringLiteral("quran/disclaimer_confirmed"), false).toBool();

    // If app version changed since confirmation, reset awareness confirmation for the new update
    if (confirmedVersion != appVersion) {
        isConfirmed = false;
    }

    QDate today = QDate::currentDate();
    QString lastShownStr = s.value(QStringLiteral("quran/disclaimer_last_shown_date")).toString();
    QDate lastShownDate = QDate::fromString(lastShownStr, Qt::ISODate);

    if (!isConfirmed) {
        // Appears once a day until confirmed (during first week or after an update)
        if (!lastShownDate.isValid() || lastShownDate != today) {
            return true;
        }
        return false;
    } else {
        // Once confirmed, appears once a month (every 30 days)
        if (!lastShownDate.isValid() || lastShownDate.daysTo(today) >= 30) {
            return true;
        }
        return false;
    }
}

void QuranManager::confirmTextModeDisclaimer(const QString &appVersion)
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    s.setValue(QStringLiteral("quran/disclaimer_confirmed_version"), appVersion);
    s.setValue(QStringLiteral("quran/disclaimer_confirmed"), true);
    s.setValue(QStringLiteral("quran/disclaimer_last_shown_date"), QDate::currentDate().toString(Qt::ISODate));
    s.sync();
}

void QuranManager::recordTextModeDisclaimerShown()
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    s.setValue(QStringLiteral("quran/disclaimer_last_shown_date"), QDate::currentDate().toString(Qt::ISODate));
    s.sync();
}

bool QuranManager::isTextModeDisclaimerConfirmed(const QString &appVersion) const
{
    QSettings s(SettingsHelper::settingsFilePath(), QSettings::IniFormat);
    QString confirmedVersion = s.value(QStringLiteral("quran/disclaimer_confirmed_version")).toString();
    bool isConfirmed = s.value(QStringLiteral("quran/disclaimer_confirmed"), false).toBool();
    return isConfirmed && (confirmedVersion == appVersion);
}
