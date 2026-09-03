# VAKA 03 — ZİYARETÇİLER (tasarım, G17)

## Ne ödüyor

Prologdan beri oyunun söylemeden söylediği tek şey: **sahiplenmeden bakmak.**
Bebeği tutamadı, kasabaya verdi. Köpeğe isim vermedi, bir kız verdi. Kasabayı
onardı, yerleşimciler geldi, hiçbiri onun değil. Vaka 3 bu cümleyi *söylemez*;
oyuncuya bir kapı verir ve kapıyı ona açtırır ya da kapattırır.

Concord iki hafta içinde geliyor (Vaka 2, ch14: haritada tarih; ch17: "temas
ziyareti, gelir ve konuşurlar"). Onlar Ellie gibi "ölü yıllardan sonra doğan
çocukları" bulup kaydeden bir örgüt. Kötü değiller. **Sahiplenici**ler:
listeler, dosyalar, "koruma altına alma". Kasaba ise dokuz yıl önce bir bebeği
kucağına almış ve **kimseye sormamış**.

Kapı sorusu: **Ellie'yi onlara gösterir misin, göstermez misin?** İkisi de
savunulabilir. Oyun cevabı vermiyor; oyuncunun cevabına iki farklı sabah veriyor.

## Ton kuralları (G14.1 devam)

- Silah yok, tehdit sahnesi yok, "kaçış" yok. Kimse koşmuyor.
- Concord adamları **nazik ve yorgun**. Kötülük yok; yöntem var.
- Ellie'nin fikri **sorulur** ve **belirleyici değildir** — o dokuz yaşında.
- "Paylaşmak", "sahiplenmek", "aile" kelimeleri diyalogda **geçmez**.
- Mareşal'in kızı adıyla **anılmaz**; bir kez, tek bir nesneyle yankılanır (ch23).

## Sekiz bölüm — hepsi kasabanın **içinde ve çevresinde**

Vaka 1 kasabayı aradı, Vaka 2 doğuya gitti. Vaka 3 **eve döner**: her bölüm
kasabanın tanıdığımız bir köşesi, ziyaret için hazırlanıyor. Biçme = kasabayı
görünür kılma. Kimin için görünür — soru bu.

| # | id | yer | landmark | palet | saat | mekanik notu |
|---|---|---|---|---|---|---|
| 19 | ch19_town_square | kasaba meydanı | meeting_stone | GREEN | morning | Vaka 1'in başladığı çimenlik; iki kanıt: Ellie'nin işaretlediği taş, tören listesi |
| 20 | ch20_watchtower_road | gözcü kulesine yol | water_tower | DRY_GOLD | midday | **time_lapse yok**, ama gün ortası sert ışık; "yolu görsünler" |
| 21 | ch21_school_field | okul bahçesi | playground | LUSH | afternoon | Ellie'nin ok çizdiği oyun alanı; kırılgan kanıt: tebeşir çizimi (fragile) |
| 22 | ch22_the_orchard_again | bahçenin bahçesi | orchard | AMBER | golden | Yabancı'nın diktiği; hasat duygusu; yerleşimciler yardım eder (mid_chat) |
| 23 | ch23_the_grave_row | mezarlık sırası | clearing | DUSK_VIOLET | dusk | **tek yankı**: küçük bir tahta işaret, yazısız; walk_only kanıt (yürüyerek) |
| 24 | ch24_the_gate_line | kasaba kapısı, çit hattı | crossing | GREEN_COOL | dawn | kapının önü; sazlık; "buradan geçecekler" |
| 25 | ch25_night_watch | gece nöbeti, kule altı | water_tower | EMERALD | night | fireflies; **zaman baskısı**: farlar yaklaşır (HUD hattı) |
| 26 | ch26_the_visit | ziyaret | meeting_stone | WHEAT | sunset | **finale**: biçme kısa (small); sonunda **Kapı Kartı** (seçim) |

Landmark'lar mevcut olanlardan seçildi; yeni mesh yok. Palet ve saatler bir
gün + bir gece + bir şafak döngüsü çiziyor: 19 sabah → 26 gün batımı.

## Kanıtlar (bölüm başına iki)

Vaka 3'ün kanıtları geçmişi değil **şimdiyi** anlatır: kasabanın nasıl
hazırlandığını ve Concord'un ne olduğunu. Cole notları yine çıkarım.

- 19: `stone_mark` (Ellie'nin taşa kazıdığı yedi yıldız — kopyalamış), `roster` (kasabanın kendi yazdığı isim listesi; **Ellie'nin adı yok** — Sarah silmiş)
- 20: `mirror` (kuleye asılmış işaret aynası), `oil_can` (kule merdiveni yağlanmış — biri çıkacak)
- 21: `chalk_map` (**kırılgan**; Ellie'nin tebeşirle çizdiği kasaba haritası: bir ev daire içinde), `bell` (okul zili, yeniden asılmış)
- 22: `pruning_saw` (temiz, keskin — Yabancı bakım yapmış), `ladder` (üç basamağı yeni)
- 23: `marker` (yazısız tahta işaret, **Mareşal'in değil**, biri buraya da gömmüş), `ribbon_grey` (gri kurdele — Concord işareti?)
- 24: `wire` (çit teli yeniden gerilmiş), `sign_blank` (boş tabela; kasaba ne yazacağına karar verememiş)
- 25: `lantern` (Gus'ın feneri, yakılmış), `radio_log` (Gus'ın son üç gün kaydı: farlar, mesafeler)
- 26: `letter` (Concord'un getirdiği mektup: **teşekkür**, talep değil), `photograph` (Ellie'nin fotoğrafı — Concord'un dosyasından; **bebeklik**, dokuz yıl önce çekilmiş: **birileri onu daha o zaman biliyordu**)

26'nın ikinci kanıtı büküm değil, **anlam**: Concord onu dokuz yıl boyunca
biliyordu ve gelmedi. Şimdi geliyorlar çünkü Yabancı sustu. Tehdit, hiç
olmadığı kadar küçük ve gerçek: **dosyada olmak**.

## Kapı Kartı (finale seçimi)

Ch26 debrief'inden sonra `GateCard`: iki sayfa anlatı (ConvoyCard kalıbı) +
üçüncü sayfada iki düğme. Metin ne "paylaş" ne "koru" der:

- **Kapıyı aç** → *"Bring her out. Let them see what a town did."*
- **Kapıyı kapat** → *"Tell them the file is wrong. There was never a child here."*

İki bitiş kartı (`ending_open`, `ending_closed`), ikisi de **sabah**, ikisi de
verandada ışık. Farkı tek bir detay taşır:
- Açık: Ellie meydanda, Concord'un adamı **defterini kapatıyor** ve bir şey yazmadan gidiyor. Köpek Ellie'nin yanında.
- Kapalı: Concord gidiyor, kasaba sessiz. Ellie pencereden bakıyor. Köpek **kapıda**, Mareşal'in yanında — kızın değil.

Köpeğin nerede durduğu, oyunun bütün cevabı. Hiçbir satır bunu söylemez.

## Sistem

- `story.json` → `case_03.chapters` (8), `hud_line`, `objective`, `teaser_image`.
- Açılış: `ChapterProgress.case_three_open()` = `case02_closed`.
- `chapters()` ve `active_case_chapters()` üçüncü listeyi de tanır; `active_case_is_two()` yerine `active_case_index()` (1/2/3).
- Root: `_is_last_chapter(ch26)` → `finale_case03` diyalogu → `GateCard` → seçim `story/gate_open` bayrağı → ilgili bitiş kartı → `case03_closed`.
- Kapı tercihi kayıtta kalır; hub'daki kasaba diaroması **Ellie'yi** açık kapıda meydana, kapalıda pencereye koyar (mevcut `_build_ellie` konumu bayrağa göre).
- Test `Case3Check`: veri bütünlüğü (anahtarlar, landmark'lar, kanıt sayıları, brief/debrief var), açılış kapısı, finale yönlendirmesi, iki bitiş.

## Yapılmayacaklar

Yeni makine, yeni ekonomi, yeni landmark mesh'i, silah, kovalamaca, "Ellie
Mareşal'in kızı" (kapı prologda kapandı ve kapalı kalır).
