#ifndef QURANPAGEIMAGEPROVIDER_H
#define QURANPAGEIMAGEPROVIDER_H

#include <QQuickImageProvider>
#include "quranmanager.h"

class QuranPageImageProvider : public QQuickImageProvider
{
public:
    explicit QuranPageImageProvider(QuranManager *mgr)
        : QQuickImageProvider(QQuickImageProvider::Image)
        , m_mgr(mgr)
    {
    }

    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override
    {
        // id format: "<page>_<highlightSurah>_<highlightAyah>_<darkMode>_<riwayah>_<tajweedMode>_<token>"
        QString cleanId = id;
        int qIdx = cleanId.indexOf(QLatin1Char('?'));
        if (qIdx != -1) cleanId = cleanId.left(qIdx);

        QStringList parts = cleanId.split(QLatin1Char('_'));
        if (parts.isEmpty()) return QImage();

        int pageNumber = parts.value(0).toInt();
        int highlightSurah = parts.value(1).toInt();
        int highlightAyah = parts.value(2).toInt();
        bool darkMode = parts.value(3).toInt() == 1;
        int riwayah = (parts.size() > 4) ? parts.value(4).toInt() : 0;
        bool tajweedMode = false;
        if (parts.size() > 5) {
            tajweedMode = (parts.value(5).toInt() == 1);
        } else if (m_mgr) {
            tajweedMode = m_mgr->tajweedMode();
        }

        int maxP = m_mgr ? m_mgr->maxPages() : 706;
        if (pageNumber < 1 || pageNumber > maxP) pageNumber = 1;

        bool algeriaMode = false;
        if (parts.size() > 7) {
            algeriaMode = (parts.value(7).toInt() == 1);
        } else if (m_mgr) {
            algeriaMode = m_mgr->algeriaMode();
        }

        return m_mgr->renderPageImage(pageNumber, highlightSurah, highlightAyah, darkMode, riwayah, tajweedMode, algeriaMode, requestedSize, size);
    }

private:
    QuranManager *m_mgr;
};

#endif // QURANPAGEIMAGEPROVIDER_H
