# Art prompts — outstanding pieces (G19)

> **Durum (2026-09-10).** Kart resimleri bitti: prolog'un yedisi
> (`pro_1` … `pro_7`) ve giriş destesinin dördü
> (`intro_1`, `intro_2`, `intro_2b`, `intro_3`) üretilip içe alındı — bkz.
> [ART_PROMPTS_PROLOGUE.md](ART_PROMPTS_PROLOGUE.md) ve
> [ART_PROMPTS_INTRO.md](ART_PROMPTS_INTRO.md). **Bu dosyadaki üç işin
> üçü de hâlâ bekliyor:**
>
> * **Şerif portresi** — `textures/portraits/marshal.jpg` yerinde ama hâlâ
>   eski resim. Bugün açıp baktım: elinde tüfek, kemerinde kılıflı tabanca,
>   göğsünde yazılı "SHERIFF" rozeti ve arkada "HOPE HOLLOW" tabelası. Yani
>   G19'un saydığı dört ihlal de duruyor (kasabanın adı oyunda **Hollow
>   Creek**), değiştirilmesi gerekiyor.
> * **Vaka 02 kartı** — `textures/story/case2_card.jpg` diye bir dosya yok.
> * **Ellie'nin dört çizimi** — `textures/story/drawing_01..04.jpg` yok;
>   G34 bu resimleri bekliyor.
>
> Bu üçünü de üretirken artık kart setinin ölçülen paletini ve güvenli
> kadraj sayılarını kullan: [ART_PROMPTS_INTRO.md](ART_PROMPTS_INTRO.md).

Two images the G19 review flagged, both against the project's own image
rules. Same format as the prologue prompts. Deliver as JPG, 9:16 for the
portrait (1080×1920 or larger), 9:16 for the card.

Shared style reference: the existing portraits and the region map — painterly,
warm, soft-edged, muted palette (olive, ochre, dusty blue), visible brush
texture, no photoreal skin, no sharp digital lines.

The prologue's six cards (`pro_1` … `pro_6`) have their own file, rewritten
for Gemini with the measured palette and safe-crop numbers:
[ART_PROMPTS_PROLOGUE.md](ART_PROMPTS_PROLOGUE.md).

## Ölçülen kısıtlar — portre ve kart için ayrı

**Portre çerçevesi.** Diyalog kutusu portreyi `DIALOGUE_PORTRAIT_SIZE`
= **560×940** (oran 0.596) bir çerçeveye `KEEP_ASPECT_COVERED` ile basıyor,
köşeleri 26px yuvarlatılmış ve çocukları kırpılıyor. Mevcut altı portre
614–619×1100 (oran 0.558–0.563): ölçek 0.905, çizilen 560×995, yani **dikeyde
55px kırpılıyor** — üstten ve alttan ~%3. Demek ki 9:16 üretmek sorun değil,
yeter ki **baş ve ayaklar üst/alt %6'ya girmesin**.

**Portre perdenin ÜSTÜNDE.** `_build` sırası: zemin → %55 siyah perde →
portre → metin paneli. Yani portre kısılmıyor, kendi parlaklığıyla görünüyor
(diyalog zeminlerinin aksine). Hedef, mevcut altılının ölçümü:

| portre | parlaklık | doygunluk | ton |
|---|---|---|---|
| cole | 125 | 0.34 | 31° |
| ellie | 128 | 0.48 | 34° |
| gus | 99 | 0.33 | 30° |
| sarah | 120 | 0.35 | 32° |
| stranger | 86 | 0.44 | 37° |
| **marshal (eski)** | **80** | **0.57** | 33° |

Şerif hem en koyu hem en doygun olan; yenisi **parlaklık 95–120, doygunluk
0.35–0.45, ton 30–37°** olsun ki altılık aile tutsun.

**Ekranda ne kadar büyük.** Portre ekranın **x %5–53, y %35–72**'sini
kaplıyor — oyunda en büyük tek resim. Elleri ve yüzü okunur olmalı.

**Kavuşma kartı.** `story/reunion.jpg` tam ekran `KEEP_ASPECT_COVERED` ve
**%55 siyah perdenin altında**; metin yüksekliğin **%58**'inden başlıyor.
İki ayrı sayfada kullanılıyor: kavuşma anı ve **köpeğe isim verme** sayfası
(orada bir metin kutusu da açılıyor). Yani: köpek resimde net görünmeli, alt
%42 sakin kalmalı, ve perde yüzünden kaynak parlaklık **130–175** olmalı
(kart setinin 80–120'sinin aksine).

**Yasaklar (proje kuralı).** Resimde yazı yok, silah yok, ateş/alev yok, kan
yok, askerî imge yok, kafatası/zombi yok, kırmızı alarm ışığı yok. Aşağıdaki
iki promptta hepsi olumlu cümleye çevrildi.

---

## 1. Şerif — `textures/portraits/marshal.jpg` — **KARAR: DEĞİŞMİYOR**

> **Kapandı (2026-09-10).** Portrenin silahlı hâli **bilinçli tercih**; ileriye
> dönük planları var. Bu dosya için "silah yok" kuralının kalıcı istisnası;
> bir daha önerilmeyecek, denetim tablolarında ihlal olarak sayılmayacak.
> Aşağıdaki prompt kayıt olarak duruyor, **kullanılmayacak.** (Not: `gus.jpg`
> zaten silahsız — gözlüklü, tulumlu tamirci; silahlı olan bu dosya.)

İkinci referans: `textures/portraits/gus.jpg` (setin en yakın tonu) + çapa
olarak `textures/intro/pro_1.jpg`.

Mevcut resimde **elinde tüfek, kemerinde kılıflı tabanca, göğsünde yazılı
"SHERIFF" rozeti ve arkada "HOPE HOLLOW" tabelası** var — dördü de yasak,
üstelik kasabanın adı **Hollow Creek**. Prompt bunların hepsini olumluya
çeviriyor: eller boş, rozetin yerinde yazısız solmuş bir iz, arkada tabela
yok.

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no photoreal skin and no sharp digital linework. Vertical 9:16 composition, a single standing figure filling most of the frame. A man in his fifties stands on the dirt road of a small rural town, seen full length at a three-quarter angle: a worn brown canvas work coat, an open collar, and on the breast a faded star-shaped mark in the cloth where a badge was carried for years, the shape alone with a plain unmarked surface. His hands are empty — one pushed into a coat pocket, the other hanging loose and open at his side. Behind him a wooden porch out of focus with a single lit lamp, and far off the soft silhouette of a windmill; the buildings carry no boards or plates of any kind. His face is tired and patient, the eyes not on the viewer but slightly aside and down, a man who has stayed. Late afternoon, low warm sun from the left, the porch lamp a weak second source from the right, long soft shadows. Palette held in warm ochre and olive browns: deep umber #433a28, olive #60533d, raw sienna #7e6540, ochre #a68c67, bone #b3a794, with the colour held back — closer to a dusty olive than to a rich brown. The figure fills the lower three quarters of the frame with clear air above the head; the background is soft and simple so the coat, the hands and the face read cleanly. Keep the head and the feet well inside the frame, away from the top and bottom edges. Quiet, heavy and kind: nothing threatening in the stance, nothing to prove.
```

Türkçe kontrol: elli yaşlarında adam, tam boy, dörtte üç açı, yıpranmış
kanvas ceket, göğüste **yazısız** solmuş yıldız izi, **eller boş** (biri
cepte), arkada odak dışı veranda ve tek fener, uzakta yel değirmeni silueti,
binalarda **tabela/levha yok**. Bakış izleyicide değil. Doygunluk mevcut
resimden **düşük** olsun (0.57 → 0.40 civarı), parlaklık biraz **yüksek**
(80 → 95–120). Baş ve ayaklar üst/alt %6'ya girmesin.

---

## 2. Kavuşma — `story/reunion.jpg` (mevcudun üzerine)

İkinci referans: `pro_6.jpg` (sepetin devredildiği kart — aynı sıcaklık, aynı
"yüzsüz yakınlık" çözümü).

Mevcut resim oyunun **en parlak** resmi (parlaklık 113; kart seti 57–79) ve
masal kitabı üslubunda net yüzlerle; Vaka 1'in finali tam orada üslup
kırılıyor. Yeni resim iki sayfaya birden hizmet etmeli:

* **"ELLIE EVDE — Sarah hiçbir şey söylemiyor. Sadece sarılıyor."**
* **"BİR İSMİ OLMALI — Ellie: 'Buraya kadar seninle yürüdü. Ona ne diyelim?'"**

Yani **köpek resimde net görünmek zorunda** ve alt %42 metne (ve isim
kutusuna) kalmalı. Yüzler bilerek çözünmüyor: satır "hiçbir şey söylemiyor,
sadece sarılıyor" diyor, bu da yüz sorununu hikâyenin kendi çözümüyle
kapatıyor.

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no photoreal skin and no sharp digital linework. Vertical 9:16 composition. Late afternoon at the gate of a clapboard farmhouse: a woman has gone down on one knee on the path and is holding a girl of nine against her, both faces turned into the other's shoulder and left unresolved, her hand flat on the back of the girl's head. Close beside them a shaggy fair-coated dog stands with its head lifted, looking up at the girl, drawn clearly and sharply enough to be recognised on its own — it is the third figure in the picture, not a detail. Behind them the open gate, a mended porch, and four or five townspeople standing back at a respectful distance in soft indistinct shapes, none of them coming closer. Warm low sun from behind the house, dust in the air, long shadows falling toward the viewer along the path. Bright and open: the light is the subject as much as the hold is, and the painting overall is roughly twice as bright as a story card, because it is seen through a dark veil in the game. Palette held in warm ochre and olive browns: olive #60533d, raw sienna #7e6540, ochre #a68c67, bone #b3a794, pale cream #e2bf93, with the greens dusty and unsaturated. The woman, the girl and the dog sit between 20% and 55% of the frame height, centred; the lower two fifths of the picture is quiet path and shadow with nothing in it. Everything of importance sits inside the central 77% of the width. Held and undramatic: no gestures, no crowd pressing in, one long quiet hold and a dog waiting to be spoken to.
```

Türkçe kontrol: yolda tek dizinin üstüne çökmüş kadın, ona sarılmış dokuz
yaşındaki kız, **yüzler birbirinin omzunda ve belirsiz**, hemen yanlarında
başını kaldırıp kıza bakan açık tüylü köpek (**net ve tanınır**), arkada açık
bahçe kapısı ve saygılı mesafede duran birkaç belirsiz kasabalı. Figürler
yüksekliğin %20–55'inde, **alt iki bölü beş boş** (metin ve isim kutusu
oraya geliyor). Kaynak parlaklık **130–175** (perde yiyecek). Balon, bayrak,
konfeti, pankart, yazı yok; kalabalık üstlerine gelmiyor.

---

## 3. Doğum günü — `story/birthday.jpg` — **GELDİ (G62)**

> **Ölçüm.** Yeni resim: parlaklık 38, doygunluk 0.59, ton 28°. Promptta
> 60–80 / 0.40–0.50 istemiştim, yani **hedefin altında** geldi — ama
> **bakılması gereken sayı o değildi.** Konu bölgesi (kız + pasta, x %25–75,
> y %38–58) **56**, kızın yüzü **50**; eski resimde aynı bölgeler **40** ve
> **39**. Yani yeni resmin ortalaması biraz daha düşük olmasına rağmen
> **konusu %40 daha parlak**: çevresi düzgün biçimde karanlık, ışık merkezde
> toplanmış. Mum ışığında gece için doğru olan da bu — ortalama değil,
> kontrast. Bu yüzden dosyaya eğri/gama uygulamadım. Perde (0.22) altında
> konu 44, yüz 39; eskisi 31 ve 30'du.
>
> **Kontroller geçti:** alev sayısı ölçülerek sayıldı (en parlak satır
> y %53.2, dokuz tepe, x %38–58 — yani **tam dokuz mum**, kadrajın
> ortasında); resimde **hiç yazı yok** (masadaki kâğıtlarda sadece çiçek
> çizimleri); yüzler yarı gölgede ve çözünmemiş, sadece kızın yüzü net;
> pasta %50–53'te, alt iki bölü beş sakin. Telefon kadrajında render alındı:
> `out/reunion_page_1.png`.
>
> Alev seçeneği: **alevli hâli** seçildi. Aşağıdaki prompt kayıt olarak
> duruyor; alevsiz varyantın tek satırlık değişikliği de altında.

## 3.1 Prompt (kullanılan)

İkinci referans: `pro_6.jpg` (setin sıcak, insanlı kartı) + çapa
`textures/story/reunion.jpg` (yeni kavuşma resmi — aynı kart, bir sayfa önce).

### Ölçülen kısıtlar — bu kart setin en KARANLIĞI, bilerek

Kavuşma kartının parti sayfası perdesini kendisi **0.22**'ye indiriyor;
koddaki gerekçe şu: *"parti resmi mumlarla aydınlanıyor, diğer ikisini okunur
tutan perde onu söndürürdü."* Yani buradaki hedef, diyalog zeminlerinin
tersine, **parlak boyamak değil**:

| | parlaklık | doygunluk | ton | üst | orta | alt |
|---|---|---|---|---|---|---|
| birthday (eski) | 42 | 0.59 | 27° | 46 | 38 | 43 |
| perde altında (×0.78) | **33** | | | | | |
| yeni hedef | **60–80** | 0.40–0.50 | 27–34° | | | alt %40 sakin |

Eski resim ekranda 33'te kalıyor, yani biraz çamurlu; 60–80 kaynak ekranda
47–62 verir. Doygunluk 0.59 setin en yükseği — 0.40–0.50'ye çekilmeli.

**Metin bandı.** Kart yazısı yüksekliğin **%58**'inden başlıyor
("BİR DİLEK TUT, ELLIE" / "Meydanın feneri altında dokuz mum. Bütün kasaba
öne eğiliyor."). Mevcut resim tam oraya iki tebrik kartı, bir tavşan ve bir
paket yığmış. Yenisinde **pasta ve mumlar %38–58 arasında**, alt iki bölü beş
sakin masa ve gölge olsun.

**Telefon kadrajı.** 941×1672 bir resmin görünen genişliği **%82** (x %9–91).

### Mevcut resimdeki üç sorun (bakarak sayıldı)

1. **Yazı, iki yerde ve okunur:** sağda "ELLIE", altta "HAPPY BIRTHDAY
   ELLIE". İkisi de kadrajın içinde. Yazı yasak, üstelik oyun iki dilli.
2. **Üslup:** yüzler foto-gerçekçi ve hepsi net; setin geri kalanı boyanmış ve
   yüzleri çözünmüyor.
3. **Mum sayısı yanlış:** satır "dokuz mum" diyor, resimde on-on bir tane var.

### Ateş kuralı — bu kartın tek istisnası

Projenin resim kuralları ateş/alev istemiyor. Bu kartın **yazılı sahnesi**
mum alevi (satır bunu söylüyor) ve kodun 0.22 perdesi de o ışığa göre
ayarlanmış. Prompt dokuz mumu alev olarak yazıyor — bir tehdit imgesi değil,
bir doğum günü pastası. **Alev hiç istemiyorsan** ikinci bir seçenek var:
dilek tutulduktan **hemen sonrası** — dokuz sönmüş mum, ince duman telleri,
ışığı yalnız meydanın feneri taşıyor. O varyantta promptta
`nine candle flames` yerine
`nine just-extinguished candles trailing thin smoke, the square's lantern carrying all the light`
yaz, gerisi aynı kalır. Hangisini istediğini söyle, dokümana onu işlerim.

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no photoreal skin and no sharp digital linework. Vertical 9:16 composition. A small town square at night, close in on a long wooden table: a girl of nine leans forward over a plain round cake with exactly nine candle flames on it, her face lit warmly from below and clearly drawn, her hair falling forward. Around and behind her the townspeople lean in as one loose ring, half in shadow, their faces soft and unresolved, hands folded or resting on the table. Above them a single iron street lantern on its post carries the rest of the light, with a line of cut-paper flowers strung between the lantern and a porch. Every card, paper and parcel on the table is turned face down or shows only drawn flowers and houses, their surfaces bare and unmarked. Night, and the only two sources are the candles and the lantern: warm light on the girl and the nearest faces, deep blue-brown darkness behind the ring, the far houses only a few lit windows. Palette held in warm ochre and olive browns with the night carried by low saturation rather than by blue: deep umber #38301e, olive #60533d, raw sienna #7e6540, ochre #a68c67, pale cream #e2bf93. The cake and the candles sit between 38% and 58% of the frame height, centred; the lower two fifths of the picture is quiet table top and shadow with nothing standing on it. Everything of importance sits inside the central 77% of the width. Held and unposed: nobody is performing, one child about to blow and a town leaning in to watch her do it.
```

Türkçe kontrol: uzun ahşap masa, öne eğilmiş dokuz yaşındaki kız, **tam
dokuz** mum, alttan aydınlanmış **net** yüz; çevrede yarı gölgede, **yüzleri
belirsiz** kasabalılar; üstte demir sokak feneri ve kesme kâğıt çiçek dizisi;
masadaki bütün kâğıtlar ya **ters çevrilmiş** ya da üstünde sadece çiçek/ev
çizimi var, **yazı yok**. Işık yalnız mumlar + fener. Pasta ve mumlar
%38–58'de, **alt iki bölü beş boş**. Balon, konfeti, pankart, havai fişek,
kalabalık öne kaçmış yüzler yok. Kaynak parlaklık 60–80, doygunluk 0.40–0.50.

---

## Eski taslaklar (kayıt olarak)

Aşağıdaki üç madde G19'da Türkçe taslak olarak yazılmıştı; Şerif'in yeni
promptu yukarıda §1'de. Vaka 02 kartı ve Ellie'nin çizimleri hâlâ bekliyor.

## 1. The Marshal — `textures/portraits/marshal.jpg` (replaces the current one)

**Görsel:** Elli yaşlarında bir adam, tam boy, dörtte üç açıdan, kırsal bir
kasabanın toprak yolunda duruyor. Yıpranmış kahverengi kanvas ceket, açık
gömlek, eski bir yıldız rozetinin solmuş izi göğüste. Elleri boş; biri
ceketin cebinde, diğeri yanında sarkıyor. Arkasında ahşap veranda ve yanan
tek bir veranda ışığı, uzakta bir yel değirmeni silueti. Yüzünde yorgunluk ve
sabır; bakış izleyiciye değil, hafif yana ve aşağıya.

**Işık:** Geç öğleden sonra, alçak sıcak güneş soldan; verandanın ışığı
sağdan zayıf ikinci kaynak. Uzun yumuşak gölgeler.

**Ton:** Sessiz, ağır, şefkatli. Kaybetmiş ama kalmış bir adam. Tehdit yok.

**Stil:** Mevcut portrelerle aynı resimsel dil: yağlıboya dokusu, yumuşak
kenarlar, kısık renk, ochre-zeytin-toz mavi paleti.

**Kompozisyon notu:** Figür kadrajın alt dörtte üçünü doldurur; başın
üstünde nefes payı. Arka plan bulanık ve sade. Portre diyalog kutusunun
üstünde büyük gösterilir; el ve yüz okunur olmalı.

**YASAK:** Tüfek, tabanca, kılıf, mermi, herhangi bir silah. Yazı, harf, tabela
metni (mevcut resimde "HOPE HOLLOW" ve "SHERIFF" yazıyor; kasabanın adı oyunda
**Hollow Creek**, tabelada isim olmayacak). Ateş, kan, kafatası, askerî işaret, kırmızı alarm ışığı.
Rozetin üstünde okunur yazı olmasın.

## 2. Case 02 card — `textures/story/case2_card.jpg` (replaces the current one)

**Görsel:** Bir mantar panoya iğnelenmiş çocuk çizimi, yakın plan. Çizimde
bir ev, bir güneş ve kapı önünde birbirine yakın duran çok sayıda çöp adam —
pastel boya ile, çocuk eliyle. Sağda pirinç bir masa lambası kâğıdı
aydınlatıyor. Alt sağdan yaşlı bir erkek eli kâğıda doğru uzanmış, henüz
dokunmamış. Arkada karanlık bir pencere ve saksı bitkileri.

**Işık:** Yalnızca masa lambası; sıcak sarı, dar koni. Odanın geri kalanı
loş mavi-gri.

**Ton:** Sessiz keşif anı. "Bunu o çizdi ve biz şimdi görüyoruz." Korku yok.

**Stil:** Resimsel, yumuşak; mantar dokusu ve kâğıdın kırışığı belli. Mevcut
kartlarla aynı dil.

**Kompozisyon notu:** Kâğıt kadrajın sol üst üçte ikisinde; alt üçte bir
boş/loş kalır — kart başlığı ve alt metin oraya biner. Lamba sağ kenarda.

**YASAK:** Kâğıtta hiçbir harf, kelime, rakam, imza — çocuk çizimi yalnızca
şekillerden oluşur (bir önceki üretimde "MOMMY" benzeri bozuk bir yazı çıktı;
bu kart o yüzden yeniden üretiliyor). Yüz detayı yok. Silah, ateş, kan,
kafatası yok.

## 3. Ellie's drawings — `textures/story/drawing_01.jpg` … `drawing_04.jpg` (new, G34 pending art)

Sprint 3's second item waits on these. Four crayon drawings by a
nine-year-old, one unlocked after each of Case 02's first four chapters
and shown in the Journal (a DRAWINGS strip under Discoveries) and once, small,
on the results panel of the chapter that unlocks it. No text on the paper,
no faces that need to be "right" — a child's marks. Deliver as JPG, 4:3
(1600×1200 or larger), all four in the same hand.

**Ortak görsel dil:** Beyaz-krem kağıt, kenarları hafif kıvrık, üstte iki
bant izi. Balmumu pastel: kalın, düzensiz, bastırılmış izler; kağıdın dokusu
renklerin arasından görünür. Perspektif yok, çocuk çizimi orantısı (başlar
büyük, eller beş çubuk). Palet: yeşil, kahverengi, gök mavisi, sarı, bir
parça kırmızı — kırmızı yalnızca elbise ve çiçek için, asla kan veya ışık.

**YASAK (projenin görsel kuralları):** yazı yok, silah yok, ateş yok, kan
yok, askerî simge yok, kafatası/zombi yok, kırmızı alarm ışığı yok.

**drawing_01 — "Bahçe":** Ellie'nin evi ve önündeki çim; çimin bir şeridi
biçilmiş (koyu yeşil-açık yeşil çizgiler), köşede küçük kahverengi bir köpek
oturuyor, gökte turuncu bir uçurtma. Güneş sağ üstte, ışınları çubuk çubuk.

**drawing_02 — "Göl":** Sazlıklar arasında küçük bir kayık, içinde şapkalı
bir figür kürek çekiyor; kıyıda uzun bacaklı iki gri kuş. Su, üst üste mavi
dalgalı çizgiler.

**drawing_03 — "Kasaba":** Yan yana dört ev, birinin penceresi sarı
(yanıyor), ötekiler koyu; önlerinde masalar ve bir sıra çocuk figürü el ele.
Bir evin çatısında yeni tahtalar (açık sarı çubuklar).

**drawing_04 — "Ne gördüm":** Ormanın kenarı, ağaçların arasında iki iri
sarı nokta (bir hayvanın gözleri gibi ama belirsiz), önde arkası dönük küçük
bir kız figürü, saçında kırmızı kurdele. Korku değil merak: gökte yıldızlar,
ay dolunay. Bu resim Vaka 02'nin sorusunu çizer, cevabını değil.

**Kompozisyon notu:** Kağıt kadrajı doldurur, çevresinde koyu masa yüzeyi
görünür (parşömen albümüyle aynı masa). Günlük'te 2 sütun küçük gösterilir;
kalın çizgiler ve az ayrıntı okunur kalmalı.
