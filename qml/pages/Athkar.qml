import QtQuick 2.6
import Sailfish.Silica 1.0
import QtMultimedia 5.0

Page {
    id: pageAthkar

    property string textAthkar_text: ""
    property var playlist: []
    property int playlistIndex: 0
    property bool isPlaying: false

    function shuffleArray(array) {
        var arr = array.slice()
        for (var i = arr.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
        }
        return arr;
    }

    function gettextathkar(textAthkar_textID) {
        switch (textAthkar_textID) {
        case 0:
            textAthkar_text = "الله أكبر، الله أكبر، الله أكبر، سبحان الذي سخر لنا هذا وما كنا له مقرنين وإنا إلى ربنا لمنقلبون اللهم إنا نسألك في سفرنا هذا البر والتقوى، ومن العمل ما ترضى، اللهم هون علينا سفرنا هذا واطو عنا بعده، اللهم أنت الصاحب في السفر، والخليفة في الأهل، اللهم أنى أعوذ بك من وعثاء السفر، وكآبة المنظر وسوء المنقلب في المال والأهل، وإذا رجع قالهن وزاد فيهن آيبون، تائبون، عابدون، لربنا حامدون."
            break
        case 1:
            textAthkar_text = "عن جابِرٍ رضيَ اللَّه عنه قال : كانَ رسولُ اللَّه صَلّى اللهُ عَلَيْهِ وسَلَّم يُعَلِّمُنَا الاسْتِخَارَةَ في الأُمُور كُلِّهَا كالسُّورَةِ منَ القُرْآنِ ، يَقُولُ إِذا هَمَّ أَحَدُكُمْ بالأمر ، فَليَركعْ رَكعتَيْنِ مِنْ غَيْرِ الفرِيضَةِ ثم ليقُلْ : اللَّهُم إِني أَسْتَخِيرُكَ بعِلْمِكَ ، وأستقدِرُكَ بقُدْرِتك ، وأَسْأَلُكَ مِنْ فضْلِكَ العَظِيم ، فإِنَّكَ تَقْدِرُ ولا أَقْدِرُ ، وتعْلَمُ ولا أَعْلَمُ ، وَأَنتَ علاَّمُ الغُيُوبِ . اللَّهُمَّ إِنْ كنْتَ تعْلَمُ أَنَّ هذا الأمرَ خَيْرٌ لي في دِيني وَمَعَاشي وَعَاقِبَةِ أَمْرِي » أَوْ قالَ : « عَاجِلِ أَمْرِي وَآجِله ، فاقْدُرْهُ لي وَيَسِّرْهُ لي، ثمَّ بَارِكْ لي فِيهِ ، وَإِن كُنْتَ تعْلمُ أَنَّ هذَا الأَمْرَ شرٌّ لي في دِيني وَمَعاشي وَعَاقبةِ أَمَرِي » أَو قال : « عَاجِل أَمري وآجِلهِ ، فاصْرِفهُ عَني ، وَاصْرفني عَنهُ، وَاقدُرْ لي الخَيْرَ حَيْثُ كانَ ، ثُمَّ رَضِّني بِهِ » قال : ويسمِّي حاجته . رواه البخاري."
            break
        case 2:
            textAthkar_text = "عَنْ أَبي هُرَيْرَةَ رَضِيَ اللهُ عَنْهُ أَنَّ رَسُولَ اللهِ صَلَّى اللهُ عَلَيْهِ وَسَلَّمَ قَالَ : « مَنْ جَلَسَ مَجْلِساً كَثُرَ فِيهِ لَغَطُهُ ، فَقَالَ قَبْلَ أَنْ يَقُومَ مِنْ مَجْلِسِهِ ذَلِكَ : سُبْحَانَكَ اللَّهُمَّ وَبِحَمْدِكَ ، أَشْهَدُ أَنْ لا إِلهَ إِلَّا أَنْتَ أَسْتَغْفِرُكَ وَأَتْوبُ إِلَيْكَ ، إِلَّا غُفِرَ لَهُ مَا كَانَ في مَجْلِسِهِ ذَلِكَ »."
            break
        case 3:
            textAthkar_text = "حدثنا خالد بن مخلد حدثنا سليمان قال حدثني عمرو بن أبي عمرو قال سمعت أنس بن مالك قال كان النبي صلى الله عليه وسلم يقول اللهم إني أعوذ بك من الهم والحزن والعجز والكسل والجبن والبخل وضلع الدين وغلبة الرجال"
            break
        case 4:
            textAthkar_text = "اللهم باعد بيني وبين خطاياي كما باعدت بين المشرق والمغرب اللهم نقني من خطاياي كما ينقى الثوب الأبيض من الدنس اللهم اغسلني من خطاياي بالثلج والماء والبرد رواه البخاري."
            break
        case 5:
            textAthkar_text = "اللهم إني أسألك العافية في الدنيا والآخرة ، اللهم إني أسألك العفو والعافية في ديني ودنياي وأهلي ومالي ، اللهم استر عورتي وآمن روعاتي ؛ اللهم احفظني من بين يدي ومن خلفي وعن يميني وعن شمالي ومن فوقي ، وأعوذ بعظمتك أن أغتال من تحتي"
            break
        case 6:
            textAthkar_text = "دعاء عظيم ثابت عن النبي الكريم صلى الله عليه وسلم، كان يقوله صلى الله عليه وسلم في كل مرة يخرج فيها من بيته، روى أهل السنن الأربعة وغيرهم عن أم المؤمنين أم سلمة هند المخزومية زوج النبي صلى الله عليه وسلم ورضي الله عنها أنها قالت:ما خرج النبي صلى الله عليه وسلم من بيتي قط إلا رفع طرفه إلى السماء فقال: اللهم إني أعوذ بك أن أضل أو أضل أو أزل أو أزل أو أظلم أو أظلم أو أجهل أو يجهل عليَّ."
            break
        case 7:
            textAthkar_text = "اللهمَّ اجعلْ في قلبي نورًا وفي بصري نورًا وفي سمعي نورًا وعن يميني نورًا وعن يساري نورًا وفوقي نورًا وتحتي نورًا وأمامي نورًا وخلفي نورًا واجعلْ لي نورًا."
            break
        case 8:
            textAthkar_text = "عَنْ ثَوْبَانَ رَضِيَ اللَّهُ عَنْهُ قَالَ: قَالَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ: مَنْ قَالَ حِينَ يُصْبِحُ: رَضِيتُ بِاللَّهِ رَبًّا وَبِالإِسْلَامِ دِينًا وَبِمُحَمَّدٍ نَبِيًّا كَانَ حَقًّا عَلَى اللَّهِ أَنْ يُرْضِيَهُ." + "\n" + "رواه الترمذي وقال: حَدِيثٌ حَسَنٌ" + "\n" + "-------" + "\n" +
            "عَنْ عَبْدِ اللَّهِ بْنِ مَسْعُودٍ رَضِيَ اللَّهُ عَنْهُ قَالَ: كَانَ نَبِيُّ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ إِذَا أَصْبَحَ قَالَ: أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ وَالْحَمْدُ لِلَّهِ لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ، رَبِّ أَعُوذُ بِكَ مِنْ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ." + "\n" + "رواه مسلم" + "\n" + "-------" + "\n" +
            "اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ." + "\n" + "رواه الترمذي" + "\n" + "-------" + "\n" +
            "سَيِّدُ الِاسْتِغْفَارِ: اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ لَكَ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ." + "\n" + "رواه البخاري" + "\n" + "-------" + "\n" +
            "عَنْ أَبِي هُرَيْرَةَ رَضِيَ اللَّهُ عَنْهُ أَنَّ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ قَالَ: مَنْ قَالَ: لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ فِي يَوْمٍ مِائَةَ مَرَّةٍ، كَانَتْ لَهُ عَدْلَ عَشْرِ رِقَابٍ، وَكُتِبَتْ لَهُ مِائَةُ حَسَنَةٍ، وَمُحِيَتْ عَنْهُ مِائَةُ سَيِّئَةٍ." + "\n" + "صحيح مسلم" + "\n" + "-------" + "\n" +
            "قراءة آية الكرسي: مَنْ قَالَهَا حِينَ يُصْبِحُ أُجِيرَ مِنْ الْجِنِّ حَتَّى يُمْسِيَ، وَمَنْ قَالَهَا حِينَ يُمْسِي أُجِيرَ مِنْ الْجِنِّ حَتَّى يُصْبِحَ." + "\n" + "رواه الطبراني وقال الهيتمي رجاله ثقات" + "\n" + "-------" + "\n" +
            "عَنِ ابْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا قَالَ: لَمْ يَكُنْ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ يَدَعُ هَؤُلَاءِ الدَّعَوَاتِ حِينَ يُصْبِحُ وَحِينَ يُمْسِي: اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي، اللَّهُمَّ اسْتُرْ عَوْرَاتِي وَآمِنْ رَوْعَاتِي، اللَّهُمَّ احْفَظْنِي مِنْ بَيْنِ يَدَيَّ وَمِنْ خَلْفِي وَعَنْ يَمِينِي وَعَنْ شِمَالِي وَمِنْ فَوْقِي، وَأَعُوذُ بِعَظَمَتِكَ أَنْ أُغْتَالَ مِنْ تَحْتِي." + "\n" + "رواه أحمد وأبو داود وابن ماجه وقال الألباني: صحيح" + "\n" + "-------" + "\n" +
            "قَالَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ: مَا مِنْ عَبْدٍ يَقُولُ فِي صَبَاحِ كُلِّ يَوْمٍ وَمَسَاءِ كُلِّ لَيْلَةٍ: بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ ثَلَاثَ مَرَّاتٍ لَمْ يَضُرَّهُ شَيْءٌ." + "\n" + "الترمذي وابن ماجه وقال الألباني: صحيح" + "\n"
            break
        case 9:
            textAthkar_text = "عَنْ ثَوْبَانَ رَضِيَ اللَّهُ عَنْهُ قَالَ: قَالَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ: مَنْ قَالَ حِينَ يُمْسِي: رَضِيتُ بِاللَّهِ رَبًّا وَبِالإِسْلَامِ دِينًا وَبِمُحَمَّدٍ نَبِيًّا كَانَ حَقًّا عَلَى اللَّهِ أَنْ يُرْضِيَهُ." + "\n" + "رواه الترمذي وقال: حَدِيثٌ حَسَنٌ" + "\n" + "-------" + "\n" +
            "عَنْ عَبْدِ اللَّهِ بْنِ مَسْعُودٍ رَضِيَ اللَّهُ عَنْهُ قَالَ: كَانَ نَبِيُّ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ إِذَا أَمْسَى قَالَ: أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ وَالْحَمْدُ لِلَّهِ لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا، رَبِّ أَعُوذُ بِكَ مِنْ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ." + "\n" + "رواه مسلم" + "\n" + "-------" + "\n" +
            "اللَّهُمَّ بِكَ أَمْسَيْنَا وَبِكَ أَصْبَحْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ." + "\n" + "رواه الترمذي" + "\n" + "-------" + "\n" +
            "سَيِّدُ الِاسْتِغْفَارِ: اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ لَكَ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ." + "\n" + "رواه البخاري" + "\n" + "-------" + "\n" +
            "عَنْ أَبِي هُرَيْرَةَ رَضِيَ اللَّهُ عَنْهُ أَنَّ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ قَالَ: مَنْ قَالَ: لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ فِي يَوْمٍ مِائَةَ مَرَّةٍ، كَانَتْ لَهُ عَدْلَ عَشْرِ رِقَابٍ، وَكُتِبَتْ لَهُ مِائَةُ حَسَنَةٍ، وَمُحِيَتْ عَنْهُ مِائَةُ سَيِّئَةٍ." + "\n" + "صحيح مسلم" + "\n" + "-------" + "\n" +
            "قراءة آية الكرسي: مَنْ قَالَهَا حِينَ يُمْسِي أُجِيرَ مِنْ الْجِنِّ حَتَّى يُصْبِحَ، وَمَنْ قَالَهَا حِينَ يُصْبِحُ أُجِيرَ مِنْ الْجِنِّ حَتَّى يُمْسِيَ." + "\n" + "رواه الطبراني وقال الهيتمي رجاله ثقات" + "\n" + "-------" + "\n" +
            "عَنِ ابْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا قَالَ: لَمْ يَكُنْ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ يَدَعُ هَؤُلَاءِ الدَّعَوَاتِ حِينَ يُمْسِي وَحِينَ يُصْبِحُ: اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي، اللَّهُمَّ اسْتُرْ عَوْرَاتِي وَآمِنْ رَوْعَاتِي، اللَّهُمَّ احْفَظْنِي مِنْ بَيْنِ يَدَيَّ وَمِنْ خَلْفِي وَعَنْ يَمِينِي وَعَنْ شِمَالِي وَمِنْ فَوْقِي، وَأَعُوذُ بِعَظَمَتِكَ أَنْ أُغْتَالَ مِنْ تَحْتِي." + "\n" + "رواه أحمد وأبو داود وابن ماجه وقال الألباني: صحيح" + "\n" + "-------" + "\n" +
            "قَالَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ: مَا مِنْ عَبْدٍ يَقُولُ فِي صَبَاحِ كُلِّ يَوْمٍ وَمَسَاءِ كُلِّ لَيْلَةٍ: بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ ثَلَاثَ مَرَّاتٍ لَمْ يَضُرَّهُ شَيْءٌ." + "\n" + "الترمذي وابن ماجه وقال الألباني: صحيح" + "\n" + "-------" + "\n" +
            "عَنْ أَبِي هُرَيْرَةَ أَنَّهُ قَالَ: جَاءَ رَجُلٌ إِلَى النَّبِيِّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ فَقَالَ: يَا رَسُولَ اللَّهِ مَا لَقِيتُ مِنْ عَقْرَبٍ لَدَغَتْنِي الْبَارِحَةَ، قَالَ: أَمَا لَوْ قُلْتَ حِينَ أَمْسَيْتَ: أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ - لَمْ تَضُرَّكَ." + "\n" + "رواه مسلم" + "\n"
            break
        default:
            textAthkar_text = ""
            break
        }
    }

    function getAthkarFiles(index) {
        var relFiles = []
        switch (index) {
        case 0: relFiles = ["sounds/Athkar/1_18.ogg"]; break
        case 1: relFiles = ["sounds/Athkar/1_13.ogg"]; break
        case 2: relFiles = ["sounds/Athkar/1_17.ogg"]; break
        case 3: relFiles = ["sounds/Athkar/1_14.ogg"]; break
        case 4: relFiles = ["sounds/Athkar/1_10.ogg"]; break
        case 5: relFiles = ["sounds/Athkar/5_1.ogg"]; break
        case 6: relFiles = ["sounds/Athkar/1_6.ogg"]; break
        case 7: relFiles = ["sounds/Athkar/1_8.ogg"]; break
        case 8: relFiles = [
            "sounds/Athkar/1_1.ogg",
            "sounds/Athkar/1_2.ogg",
            "sounds/Athkar/1_3.ogg",
            "sounds/Athkar/1_4.ogg",
            "sounds/Athkar/2_4.ogg",
            "sounds/Athkar/2_1.ogg",
            "sounds/Athkar/1_19.ogg",
            "sounds/Athkar/3_1.ogg"
        ]; break
        case 9: relFiles = [
            "sounds/Athkar/2_1.ogg",
            "sounds/Athkar/1_3.ogg",
            "sounds/Athkar/1_2.ogg",
            "sounds/Athkar/2_2.ogg",
            "sounds/Athkar/3_2.ogg"
        ]; break
        default: relFiles = []; break
        }

        var resolved = []
        for (var i = 0; i < relFiles.length; i++) {
            if (typeof prayerManager !== "undefined" && prayerManager.resolveAthkarPath) {
                resolved.push(prayerManager.resolveAthkarPath(relFiles[i]))
            } else {
                resolved.push("/usr/share/harbour-thakir/" + relFiles[i])
            }
        }
        return resolved
    }

    Timer {
        id: nextTrackTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (isPlaying && playlistIndex < playlist.length) {
                athkarPlayer.source = playlist[playlistIndex]
                athkarPlayer.play()
            }
        }
    }

    Audio {
        id: athkarPlayer

        onStatusChanged: {
            if (status === Audio.EndOfMedia) {
                if (isPlaying && playlistIndex + 1 < playlist.length) {
                    playlistIndex++
                    stop()
                    nextTrackTimer.start()
                } else {
                    stopAthkar()
                }
            } else if (status === Audio.LoadedMedia) {
                if (isPlaying && playbackState !== Audio.PlayingState) {
                    play()
                }
            }
        }

        onPositionChanged: {
            if (duration > 0) {
                progressBar_positionMedia.maximumValue = duration
                progressBar_positionMedia.value = position
            }
        }

        onDurationChanged: {
            if (duration > 0) {
                progressBar_positionMedia.maximumValue = duration
            }
        }

        onPlaybackStateChanged: {
            if (playbackState === Audio.StoppedState && !isPlaying) {
                progressBar_positionMedia.value = 0
            }
        }
    }

    function playAthkar() {
        if (athkarPlayer.playbackState === Audio.PausedState) {
            isPlaying = true
            athkarPlayer.play()
            return
        }
        if (athkarPlayer.playbackState === Audio.PlayingState) {
            return
        }
        var files = getAthkarFiles(athkar.currentIndex)
        if (athkar.currentIndex === 8 || athkar.currentIndex === 9) {
            files = shuffleArray(files)
        }
        playlist = files
        playlistIndex = 0
        if (playlist.length > 0) {
            isPlaying = true
            athkarPlayer.stop()
            athkarPlayer.source = playlist[0]
            athkarPlayer.play()
        }
    }

    function pauseAthkar() {
        if (athkarPlayer.playbackState === Audio.PlayingState) {
            athkarPlayer.pause()
        }
    }

    function stopAthkar() {
        isPlaying = false
        nextTrackTimer.stop()
        athkarPlayer.stop()
        playlistIndex = 0
        progressBar_positionMedia.value = 0
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: pageAthkar.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Listening to some Athkar: ")
            }

            Row {
                id: iconButtons
                spacing: Theme.paddingLarge
                anchors.horizontalCenter: parent.horizontalCenter

                IconButton {
                    id: play
                    icon.source: "image://theme/icon-l-play"
                    enabled: athkarPlayer.playbackState !== Audio.PlayingState
                    onClicked: playAthkar()
                }
                IconButton {
                    id: pause
                    icon.source: "image://theme/icon-l-pause"
                    enabled: athkarPlayer.playbackState === Audio.PlayingState
                    onClicked: pauseAthkar()
                }
                IconButton {
                    id: stop
                    icon.source: "image://theme/icon-l-clear"
                    enabled: isPlaying || athkarPlayer.playbackState === Audio.PlayingState || athkarPlayer.playbackState === Audio.PausedState
                    onClicked: stopAthkar()
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (playlist.length > 1 && isPlaying)
                      ? (qsTr("Clip %1 of %2").arg(prayerManager.formatDigits((playlistIndex + 1).toString())).arg(prayerManager.formatDigits(playlist.length.toString())))
                      : ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                visible: text.length > 0
            }

            ProgressBar {
                id: progressBar_positionMedia
                width: parent.width
                minimumValue: 0
                maximumValue: 100
                value: 0
            }

            ComboBox {
                id: athkar
                width: parent.width
                label: qsTr("Athkar: ")
                description: qsTr("Click to select a dhikr")
                currentIndex: 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("Doaa for Travel") }
                    MenuItem { text: qsTr("Doaa Istikhara") }
                    MenuItem { text: qsTr("Doaa Istighfar") }
                    MenuItem { text: qsTr("Doaa Istiaatha") }
                    MenuItem { text: qsTr("Doaa Istiftah") }
                    MenuItem { text: qsTr("Doaa Affiya") }
                    MenuItem { text: qsTr("Doaa leave the house") }
                    MenuItem { text: qsTr("Doaa go to the mosque") }
                    MenuItem { text: qsTr("Morning Athkar") }
                    MenuItem { text: qsTr("Evening Athkar") }
                }
                onCurrentIndexChanged: {
                    stopAthkar()
                    gettextathkar(currentIndex)
                }
            }

            TextArea {
                color: "orange"
                font.family: "cursive"
                width: parent.width
                horizontalAlignment: Text.AlignJustify
                text: textAthkar_text
                wrapMode: Text.Wrap
                readOnly: true
                autoScrollEnabled: true
            }
        }
    }

    onStatusChanged: {
        if (status !== PageStatus.Active) {
            stopAthkar()
        }
    }

    Component.onCompleted: {
        gettextathkar(athkar.currentIndex)
    }
}
