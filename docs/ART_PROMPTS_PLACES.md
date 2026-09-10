# Eksik ve yanlış resimler — denetim ve promptlar (G58)

On bir kart resmi bitti. Bu doküman geri kalanı, **oyunun kendi dosyalarını
ölçerek** sıraya koyar: hangisi gerçekten eksik, hangisi kuralı çiğniyor,
hangisi sadece üslup dışı. Sıra öneri sırasıdır.

## Denetim — ölçülen

Bütün `textures/` altındaki resimlerin ortalama parlaklığı, doygunluğu ve
doygun piksellerin medyan tonu ölçüldü. Kart seti (11 resim) **32–46°** ton
aralığında, yani okra→zeytin. Bundan sapanlar ve kural ihlalleri:

| dosya | sorun | ölçüm / kanıt |
|---|---|---|
| ~~`story/ending_open`~~ | **GELDİ (G61), YAZILAR TEMİZLENDİ (G62.1)** | Yeniden üretildi: duvarlar, direkler ve kaide çıplak tahta, hiçbir yerde yazı yok. |
| ~~`story/ending_closed`~~ | **GELDİ (G61)** | Üretildi, bağlandı, temiz. |
| ~~`story/reunion.jpg`~~ | **GELDİ (G61)** | Yeniden boyandı, temiz; perdesi 0.55'ten 0.30'a indirildi (ölçüm aşağıda). |
| `portraits/marshal.jpg` | **KARAR: değişmiyor** | Silahlı hâli **bilinçli tercih** (2026-09-10). Bu dosya için "silah yok" kuralının kalıcı istisnası; bir daha önerilmeyecek. Diğer kurallar (yazı, ateş, kan) geçerli. |
| `hub/case2_teaser.jpg` | **kural ihlali** | Resmin içine uydurma harfler çizilmiş ("YMMOM"). Yazı yasak. |
| ~~`story/birthday.jpg`~~ | **GELDİ (G62)** | Yeniden boyandı: yazı yok, tam dokuz mum (ölçülerek sayıldı), yüzler çözünmemiş. Konu bölgesi eskinin %40 üstünde parlaklıkta. |
| `hub/town_square.jpg` | **GÖRÜNMÜYOR** | Ölçtüm: hub'ın arka planı `_build_ground_gradient` içinde çiziliyor, ama hemen ardından **opak** bir `SubViewportContainer` (canlı 3B kasaba) tam ekran üstüne biniyor; `transparent_bg` hiçbir yerde açılmıyor ve park hâlinde de `_diorama_still` kaplıyor. Yani bu 643 KB, 3B sahne ilk kez çizilene kadarki bir-iki karelik "siyah flaş" kalkanı. **Buna resim sipariş etmeye değmez** — ya silinir (arkasındaki sıcak degrade zaten aynı işi yapar) ya olduğu gibi kalır. |
| `story/convoy.jpg` | palet + karanlık | Medyan ton **252°** (mavi-mor), setteki tek soğuk üye; ve kartın 0.45 perdesi altında ekranda **19**'da kalıyor. Promptu yazıldı: [ART_PROMPTS.md](ART_PROMPTS.md) §4. |
| `menu/cover_portrait.jpg` | **kırpılıyor** + üslup | 4:5 resim 1170×2532'yi kaplarken genişliğin %42'sini kaybediyor; telefon kadrajında başlığın "U"su ve "N"i kesiliyor (`out/menu_phone.png`). Korku üslubu (kökler, kemikler) setin geri kalanıyla ilgisiz. Promptu yazıldı: [ART_PROMPTS.md](ART_PROMPTS.md) §5, ve `GameConfig.MENU_COVER_HAS_TITLE` ile başlığı oyunun kendisi çizebiliyor artık (G64). |

Sorun görülmeyenler: `hub/corkboard.jpg` (arka doku), `story/homecoming.jpg`
(sete en yakın olan), altı portre (`cole`, `ellie`, `gus`, `sarah`,
`stranger` + yüz ikonları; ton 22–37°), iki harita.

## Yeni yetenek: diyalogların arkasında resim (G58)

`DialogueBox` artık perdesinin (55% siyah) **altında** bir yer resmi
çizebiliyor. Hangi konuşmanın hangi yerde geçtiğini **veri** söylüyor:
`data/dialogue.json` içindeki `backdrops` bloğu (en uzun eşleşen id öneki
kazanır), ya da bir konuşmanın kendi `backdrop` alanı. Boş bırakılırsa kutu
bugüne kadar olduğu gibi şeffaf kalır.

**Bilerek boş bırakılanlar:** `brief_` (brifing zaten biçilecek bahçenin
üstünde oynuyor — G54, senin isteğin) ve `debrief_` (biçilmiş bahçenin ve
sonuç panelinin üstünde oynuyor). Resimler geldiğinde `finale_` →
`places/office_dusk` ve `quiet_` → `places/road_east` yapılacak; şimdilik
ikisi de boş, çünkü olmayan bir resmi adlandıran kural her satırda uyarı
basıyor.

### Bir diyalog zemininin görünen kısmı — ölçüldü

`BackdropShot` ile 1170×2532 kadrajda ölçtüm (`out/dialogue_backdrop.png`):

* Metin paneli ekranın **%70**'inden aşağısını kaplıyor.
* Portre çerçevesi **x %5–53, y %35–72** arasında duruyor.
* Yani zeminden görünen: **üstten %35'lik tam genişlikteki şerit**, artı
  **sağda x %53–100 arası, %70'e kadar inen** bant. Resmin sol-alt yarısı
  hiç görünmüyor.

Buradan çıkan iki kural, kart promptlarından **farklı**:

1. **Konu üst üçte birde ve sağ yarıda olsun.** Sol alt köşe mobilyadır.
2. **Kart resimlerinden yaklaşık iki kat parlak boyanmalı.** Zemin %55 siyah
   perdenin altında: ekrandaki parlaklığı kaynağın ~0.45'i. Kartlar ekranda
   57–79 seviyesinde okunuyor; aynı seviyeye çıkmak için kaynağın **130–175**
   olması gerekiyor. Kart promptlarındaki "alt üçte bir en koyu olsun" kuralı
   burada geçerli **değil** — metnin altlığını perde zaten sağlıyor.

## Kullanım (kartlarla aynı)

9:16 dikey, arayüzden seç; prompt metnine piksel yazma. Stil referansı olarak
`textures/intro/pro_1.jpg` + o promptun altında yazan ikinci dosyayı ekle.
Prompt İngilizce; altındaki Türkçe satır kontrol için. "Şu olmasın" listesi
yazma — modeller olumsuzu okumaz, aşağıdaki promptlarda her yasak olumlu
cümleye çevrildi. Uzun kenar 2100'ün altında kalsın (`AssetCheck`).

---

# A — Oyunun finali — GELDİ (G61)

Üçü de üretildi, JPEG'e çevrilip içe alındı (`reunion.jpg` mevcudun üzerine
yazıldı, `.import` ve uid korundu). Ölçüm:

| dosya | parlaklık | doygunluk | ton | üst | orta | alt |
|---|---|---|---|---|---|---|
| ending_open | 56 | 0.47 | 30° | 88 | 54 | 26 |
| ending_closed | 66 | 0.44 | 31° | 107 | 57 | 34 |
| reunion | 73 | 0.56 | 32° | 92 | 64 | 63 |

İkisi de (ending_*) kart hedefinin içinde ve `pro_5`/`pro_7` ile aynı ailede.
**Kavuşma kartı için bir düzeltme gerekti:** eski masal resmi 113 parlaklıkta
ve kartın %55 perdesi altında ekranda 51'e düşüyordu; yeni resim 73, aynı
perde altında 33 — telefon kadrajında render aldım, resim çamurlaştı ve
içindeki gün batımı kayboldu. Perde bu iki sayfa için **0.30**
(`GameConfig.REUNION_SCRIM`): resim ekranda 51'e, metin bandı 44'e geliyor,
beyaz yazı gölgesiyle hâlâ okunuyor. Parti sayfası zaten kendi perdesini
(0.22) ayarlıyordu, aynı sebeple.

## ~~Kalan tek iş~~: `ending_open` içindeki yazılar — ÇÖZÜLDÜ (G62.1)

> İkinci üretim temiz geldi: duvarda, kaidede ve solda tabela yok, meydanın
> bütün ahşabı çıplak. Ölçüm: parlaklık 62 (öncesi 56, ikizi `ending_closed`
> 66), doygunluk 0.47, ton 31°, üçte birler 99/59/27 — ikizinin
> (107/57/34) yanına oturuyor. Kızın elindeki kâğıtta okunur harf yok, sadece
> el yazısı izlenimi. Aşağıdaki prompt kullanılan hâli.

Resmin içine üç tabela çizilmiş — duvarda "PEOPLE LAND TOGETHER STILL HERE",
kaidede "SAME HANDS BRIGHTER DAYS", solda "A SMALLER BRIGHTER TOMORROW".
Telefon kadrajında görünen genişlik %82 (x %9–91), yani **duvardaki tabela
tam ortada ve okunuyor**, soldaki kısmen. Proje kuralı resimde yazı
istemiyor; üstelik oyun iki dilli, resme gömülü İngilizce çevrilemiyor.

Kırpmayla kurtarılamıyor (duvardaki tabela kadrajın tam ortasında). Yeniden
üretmek istersen prompt aşağıda: tek fark, tabelaları **olumlu** cümleyle
ortadan kaldırması ("the boards are bare"). "Yazı olmasın" yazmak modele yazı
ekletiyor, o yüzden hiç yazıdan bahsetmiyor.

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no digital linework. Vertical 9:16 composition. A small town square on a clear morning, seen from among the crowd: in the middle distance a child stands alone on the flagstones talking, with a dog sitting close against her knee, and behind her thirty townspeople in a loose half circle, their faces soft and unresolved, listening. In the near foreground, seen from behind, four figures in long plain coats stand with their backs to the viewer, one of them holding a closed notebook at his side. A great old tree spreads over the square with a string of unlit lamps in it, and mended clapboard houses close the sides; every wall, post and plinth in the square is bare weathered board, plain and unpainted, with nothing hung or fixed on it. Early morning light coming from the left across the flagstones, long soft shadows, dew still on the grass at the edges. Palette held in warm ochre and olive browns: deep umber #433a28, olive #60533d, raw sienna #7e6540, ochre #a68c67, bone #b3a794, pale cream #e2bf93. The child and the dog sit between 40% and 55% of the frame height, centred; the coated backs fill the bottom third and are the darkest part of the painting, under half the brightness of the top. Everything of importance sits inside the central 77% of the width. Plain and public: one child speaking, a whole town standing behind her.
```

---

# A.1 — İlk hâlleri (kayıt olarak)

İkisi de tam ekran **kart**, yani kart kuralları geçerli: alt üçte bir en
koyu, önemli her şey ortadaki %77'de, Ken Burns ilk kart normal / ikinci
kart ters (aynı resim iki kez oynuyor).

## `story/ending_open` — "Meydanda bütün kasaba arkasındayken dört yabancıya ejderhaları anlattı."

İkinci referans: `pro_7.jpg`.

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no digital linework. Vertical 9:16 composition. A small town square on a clear morning, seen from among the crowd: in the middle distance a child stands alone on the flagstones talking, with a dog sitting close against her knee, and behind her thirty townspeople in a loose half circle, their faces soft and unresolved, listening. In the near foreground, seen from behind, four figures in long plain coats stand with their backs to the viewer, one of them holding a closed notebook at his side. A great old tree spreads over the square with a string of unlit lamps in it, and mended clapboard houses close the sides. Early morning light coming from the left across the flagstones, long soft shadows, dew still on the grass at the edges. Palette held in warm ochre and olive browns: deep umber #433a28, olive #60533d, raw sienna #7e6540, ochre #a68c67, bone #b3a794, pale cream #e2bf93. The child and the dog sit between 40% and 55% of the frame height, centred; the coated backs fill the bottom third and are the darkest part of the painting, under half the brightness of the top. Everything of importance sits inside the central 77% of the width. Plain and public: one child speaking, a whole town standing behind her.
```

Türkçe kontrol: meydanda tek başına konuşan çocuk, dizine yaslanmış köpek,
arkada yarım daire kasabalılar, ön planda sırtı dönük dört paltolu figür,
birinin elinde **kapalı** defter, üstte yanmayan lambalarla ağaç. Yazı,
üniforma, silah, araç, bayrak yok; yüzler net değil.

## `story/ending_closed` — "Vaktimiz için teşekkür edip kamyonları geri çevirdiler. Kimse zili çalmadı."

İkinci referans: `pro_5.jpg`.

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no digital linework. Vertical 9:16 composition. Seen from just inside an open garden gate at early morning: two plain flatbed trucks are already small in the distance, going away down a dirt road through low mist, and a dog sits in the gateway in the near foreground with its back to the viewer, watching them go. Beside the dog, at the very bottom edge of the frame, the worn toes of a man's boots. To the upper left, the corner of a clapboard house with one warm lit window and the faint shape of a child standing in it, looking out. The road is otherwise empty and the fields on both sides are grey with dew. Palette held in warm ochre and olive browns with the cold of the morning carried by low saturation rather than by blue: deep umber #38301e, olive #60533d, raw sienna #7e6540, bone #b3a794, pale cream #e2bf93, with the lit window the only saturated warmth in the picture. The trucks and the road sit between 35% and 50% of the frame height, centred; the gateway, the dog and the boots fill the bottom third and are the darkest part of the painting. Everything of importance sits inside the central 77% of the width. Quiet and withheld: nothing was given away, and nobody is celebrating.
```

Türkçe kontrol: açık bahçe kapısından bakış, uzaklaşan iki sade kasa kamyon,
kapıda sırtı dönük oturan köpek, alt kenarda bir çift yıpranmış bot, sol
üstte ışığı yanan pencerede çocuk silueti, sisli tarlalar. Askerî görünüm,
tente, yazı, plaka, silah yok.

---

# B — Diyalog yerleri (yeni)

**Bu ikisi kart değil**: yukarıdaki "görünen kısım" kuralları geçerli — konu
üst üçte birde ve sağ yarıda, ve kaynak parlaklık **130–175** (perde
yiyecek). Geldiğinde `data/dialogue.json` → `backdrops` içinde `finale_` ve
`quiet_` bu dosyaları gösterecek.

## `places/office_dusk` — Şerif'in verandası, rapor verilen yer

İkinci referans: `pro_1.jpg`.

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no digital linework. Vertical 9:16 composition. The porch of a small clapboard town office at the end of the day, seen from the yard looking up at it: three worn steps, a plain bench, a hurricane lamp hanging from a hook by the door and lit, the door itself standing half open on a dim interior with the corner of a desk and a wall of pinned paper just visible. Two enamel mugs sit on the bench rail. Behind and above the porch, a wide dusk sky with the last warm light along the roofline, and the tops of trees. The porch stands empty, waiting for someone to come and report. Bright and open in its upper half: the sky and the roofline are luminous, the lamp is the warmest point, and the painting overall is roughly twice as bright as a story card, because it is seen through a dark veil in the game. Palette held in warm ochre and olive browns: olive #60533d, raw sienna #7e6540, ochre #a68c67, bone #b3a794, pale cream #e2bf93, deep umber #433a28 in the doorway. The lamp, the door and the roofline sit in the upper third of the frame and in the right half of the width; the lower left quarter is quiet, plain boards and shadow with nothing in it. No lettering anywhere on the building or the papers.
```

Türkçe kontrol: verandada üç basamak, bank, yanan fener, yarı açık kapı,
içeride masanın köşesi ve iğnelenmiş kâğıtlar, alacakaranlık gökyüzü. Konu
**üst üçte bir ve sağ yarı**; sol alt çeyrek boş. Kâğıtlarda ve binada yazı
yok. Resim kartlardan belirgin **daha parlak** olmalı.

## `places/road_east` — yolda, geceye yakın: sessiz sahnenin (geçiş bedeli) yeri

İkinci referans: `pro_3.jpg`. `intro_2b` de doğuya bakan bir kapı ama o
kapalı ve kimse yok; burada yolda **biri var**.

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no digital linework. Vertical 9:16 composition. A dirt road at the very end of the day, seen from the middle of it: a rope has been strung waist high across the road between two leaning poles, with two hurricane lamps hung from it and lit, and on the far side two figures stand waiting, in long coats and wide hats, seen at middle distance and slightly from behind the light so their faces are unresolved shapes. The road runs on past them into open grassland. A wide luminous dusk sky fills the upper half of the frame with the last band of warm light along the horizon. Bright and open above the rope: the sky is the subject as much as the road is, and the painting overall is roughly twice as bright as a story card, because it is seen through a dark veil in the game. Palette held in warm ochre and olive browns: olive #60533d, raw sienna #7e6540, ochre #a68c67, bone #b3a794, pale cream #e2bf93. The rope, the lamps and the two figures sit around 45% of the frame height and toward the right half of the width; the lower left quarter is quiet road and grass with nothing in it. The scene is a toll, not an ambush: hands are empty and the lamps are held high so everyone can be seen.
```

Türkçe kontrol: yola gerilmiş halat, iki eğik direk, asılı iki yanan fener,
öte tarafta bekleyen iki paltolu figür (yüz belirsiz), üst yarıda geniş
alacakaranlık gökyüzü. Silah, ateş, namlu, barikat, asker görüntüsü yok —
eller boş ve fenerler yukarıda. Konu sağ yarıda; sol alt çeyrek boş.

### İsteğe bağlı iki yer daha

* `places/square_tree` — meydandaki büyük ağaç. Bunu üretirsen **iki işi
  birden** çözer: hub'ın çizgi film üslubundaki `hub/town_square.jpg`'sinin
  yerine de geçebilir.
* `places/workshop` — Gus'un atölyesi (tezgâh, asılı el aletleri, sökülmüş
  bir çim makinesi). Atölye sayfasının arkası şu an düz panel.

---

# C — Değiştirme kararı sende olanlar

Bunlar için prompt yazmadan önce ne istediğini bilmem gerekiyor, çünkü ikisi
oyunun kimliğini değiştirir:

1. **Şerif portresi** — prompt yazıldı ve Gemini biçimine çevrildi:
   [ART_PROMPTS.md](ART_PROMPTS.md) §1, ölçülen çerçeve ve palet sayılarıyla.
   Bence en acil iş: diyalog kutusunda ekranın yarısını kaplıyor ve elinde
   tüfek var.
2. **`hub/case2_teaser.jpg`** — içindeki uydurma harfler yüzünden zaten
   değişmesi gerekiyor. Ellie'nin çizimi olarak yeniden üretilebilir; G34
   için beklenen dört çizim (`story/drawing_01..04`) ile aynı işi yapar.
3. **`story/reunion.jpg`** (G61) ve **`story/birthday.jpg`** (G62) geldi.
   Kavuşma kartının üç sayfasının hepsi artık kendi resmiyle oynuyor.
4. **`menu/cover_portrait.jpg`** — iki ayrı karar: (a) 9:16 bir kapak
   üretmek (başlık kırpılması biter), (b) korku üslubundan (kökler, kemikler)
   vazgeçip oyunun sıcak paletine geçmek. Başlığı resmin içine değil oyunun
   kendisine çizdirmek en iyisi: o zaman Türkçe/İngilizce de doğru görünür.
   Kod bunu zaten destekliyor (`MainMenu._cover_art` / `_has_cover`), tek
   satırlık bir bayrak gerekiyor.
5. **`story/convoy.jpg`** — promptu yazıldı (§4). Yeniden üretmek istemezsen
   ton düzeltmesi de bir seçenek: doygunluğu ve tonu sıcak tarafa çekmek
   yeniden üretim gerektirmez, ama 0.45 perde altındaki 19'luk parlaklığı
   düzeltmez — onun için yeni resim gerekiyor.
