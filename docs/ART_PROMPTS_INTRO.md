# Giriş kartları — Gemini için promptlar (intro_1, intro_2, intro_2b, intro_3)

Prolog artık kendi altı resmine sahip (`pro_1 … pro_6`, G57). Geriye kalan
dört kart — `textures/intro/intro_1.jpg`, `intro_2.jpg`, `intro_2b.jpg`,
`intro_3.jpg` — hâlâ eski masal/çizgi roman üslubunda. Bunlar hub'daki
**"girişi tekrar oynat"** yolunda oynuyor, yani oyunda görünmeye devam
ediyorlar. Hedef: aynı dosya adlarının üzerine, yeni altılıyla aynı elden
çıkmış görünen dört resim.

## Gemini'de nasıl kullanılır

1. **En boy oranını arayüzde 9:16 (dikey) seç.** Prompt metnine piksel
   yazmayın; model bazen sayıyı resmin içine çiziyor. Gelen boy ne olursa
   olsun ben JPEG'e çevirip içe alıyorum (uzun kenar 2100'ün altında
   kalmalı — `AssetCheck` bunu zorluyor; senin altılık set 1844 ve 1672
   geldi, ikisi de uygun).
2. **Stil referansı olarak artık eski `intro_1.jpg` DEĞİL, yeni prolog
   resimlerini ekleyin.** Set artık o altısı. Her prompta iki dosya
   ekleyin: çapa olarak `textures/intro/pro_1.jpg`, artı o kartın altında
   yazan **ikinci referans**. Promptların sonundaki "match the palette and
   brushwork of the attached paintings" cümlesini bırakın.
3. **Prompt metni İngilizce** olsun; aynı sahneyi Türkçe verdiğinizde model
   belirgin biçimde daha az uyuyor. Her promptun altında Türkçe kontrol
   özeti var.
4. **"Şu olmasın" listesi yazmayın.** Görüntü modelleri olumsuzu okumaz;
   "insan yok" yazınca insan koyma olasılığı artar. Aşağıdaki promptlarda
   her yasak olumlu cümleye çevrildi ("the street stands empty, every door
   closed").
5. Her resmi 3–4 kez üretip **alt üçte biri en koyu olanı** seçin. Beğendiğini
   "same painting, but …" ile düzeltmeyin; promptu bir kelime değiştirip
   yeniden üretmek daha temiz sonuç veriyor.

## Ölçülen kısıtlar — bu sefer SENİN gelen altı resminden

Onun için sayılar prolog dokümanındakinden farklı: hedef artık eski dört
kart değil, yeni altısı. Her resmin üçte bir ortalama parlaklıkları
(0–255), doygunluk ortalaması ve doygun piksellerin medyan tonu:

| dosya | üst | orta | alt | alt/üst | doygunluk | medyan ton |
|---|---|---|---|---|---|---|
| pro_1 | 128 | 64 | 34 | 0.27 | 0.04 | 40° |
| pro_2 | 32 | 39 | 30 | 0.94 | 0.12 | 45° |
| pro_3 | 119 | 59 | 33 | 0.28 | 0.44 | 37° |
| pro_4 | 109 | 58 | 36 | 0.33 | 0.48 | 35° |
| pro_5 | 97 | 46 | 28 | 0.28 | 0.29 | 36° |
| pro_6 | 97 | 70 | 69 | 0.71 | 0.42 | 32° |
| *eski* intro_1 | 149 | 129 | 83 | 0.55 | 0.37 | 35° |
| *eski* intro_2 | 159 | 98 | 86 | 0.54 | 0.43 | 40° |
| *eski* intro_2b | 136 | 146 | 74 | 0.54 | 0.19 | 35° |
| *eski* intro_3 | 180 | 124 | 63 | 0.35 | 0.35 | 40° |

Okunacak üç şey:

**Ton tutuyor, değer tutmuyor.** Onlu setin tamamı 32°–45° arasında, yani
okra→zeytin. Renk ailesi zaten ortak. Ayrışan şey parlaklık: yeni altılının
üst üçte biri 97–128, eskilerin 136–180; yeni altılının **altı 28–36**,
eskilerin 63–86. Eski dört kart yanına konduğunda "daha açık, daha neşeli"
duruyor ve set ikiye bölünüyor. Yeni dördün hedefi: **üst üçte bir 100–130,
alt üçte bir 30–45**, alt/üst oranı **0.30 civarı**. Promptlara yazdım.

**Alt üçte bir metnin altlığıdır.** Kart yazısı yüksekliğin %58'inden
başlıyor, üstüne %5→%78 siyaha giden bir perde biniyor. `pro_6` bu kuralın
tek istisnası (alt 69, sepet ve eller alt kadrajı dolduruyor) ve zaten yazının
en zor okunduğu kart o. Dördünde de tekrarlanmasın.

**Güvenli kadraj.** Kartlar `KEEP_ASPECT_COVERED` ile çiziliyor, Ken Burns
1.06'ya kadar yaklaşıyor. 1170×2532'de 9:16 bir resmin görünen genişliği
**%77**'ye düşüyor: iki yandan ~%11, üst-alttan ~%3 kesiliyor. Önemli hiçbir
şey kenarlardaki %12'ye girmesin. `intro_2b` Ken Burns **TERS** oynuyor
(sıkı başlar, açılır) — o kartta kenarlar ayrıca boş kalsın.

**Yasaklar (proje kuralı).** Resimde yazı yok, silah yok, ateş/alev yok, kan
yok, askeri imge yok, kafatası/zombi yok, kırmızı alarm ışığı yok. Dördünde
de bunlara ihtiyaç duyulmadı.

---

## intro_1 — "Salgın yıllar önce bitti. Dünya onunla birlikte bitmedi."

İkinci referans: `pro_1.jpg` (aynı sokak, dokuz yıl sonrası).

Bu kart `pro_1`'in **cevabı**: aynı tür sokak, ama artık içinde yaşanıyor.
Fark insanlarla değil, insanların **izleriyle** anlatılıyor — kimse kadrajda
değil, her şey elden geçmiş.

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no digital linework. Vertical 9:16 composition. The main street of the same small rural town years later, seen from the middle of the road at eye level, and clearly lived in again: a two-storey clapboard house on the left whose roof has been patched with pale new boards nailed over the weathered ones, a plain washing line strung across its side yard with two sheets hanging still, the front lawn dug into straight vegetable rows under a low hoop of netting, a wooden wheelbarrow standing in the soil with a spade laid across it as though the work will be picked up again in an hour. The cracked asphalt has grass growing in every seam, with a single footpath worn smooth and bare straight down the middle of the road from years of walking. Late afternoon, the sun low and warm at the far end of the street, long shadows reaching toward the viewer. The street is quiet and nobody is in the frame; the mended roof, the line and the rows are the only things speaking. Palette held in warm ochre and olive browns: deep umber #433a28, olive #60533d, raw sienna #7e6540, ochre #a68c67, bone #b3a794, pale cream #e2bf93. The top third of the picture is the brightest, around half again as bright as the bottom third, and the bottom third — road, shadow, foreground soil — is the darkest part of the painting. Everything of importance sits inside the central 77% of the width. Modest, worn, steady: the world kept going, smaller.
```

Türkçe kontrol: yamalı çatı, çamaşır ipi, ön bahçede sebze sıraları, el
arabası ve kürek, çatlaklarda ot, ortada aşınmış yol izi, alçak sıcak güneş.
Kadrajda insan yok, kırık/yanmış hiçbir şey yok, tabela veya yazı yok.
Ken Burns normal.

---

## intro_2 — "Yeniden kuruyoruz. Küçük kasabalar. Küçük umutlar."

İkinci referans: `pro_6.jpg` (setin sıcak, insanlı kartı).

Setin **tek kalabalık** kartı. Yüzler riskli olduğu için figürler sırtı dönük
ve orta mesafede; şapka ve duruş kim olduklarını yeterince söylüyor. "Küçük
umutlar" satırının altına geldiği için sahne mütevazı kalmalı — bayram değil,
sabah işi.

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no digital linework. Vertical 9:16 composition. A working morning in a small town: raised vegetable beds built from mismatched salvaged boards fill what used to be a back yard, and three figures at middle distance work the rows with their backs to the viewer, in wide-brimmed hats and shirtsleeves, their faces turned away and unresolved. A tall wooden water butt stands at the corner of a barn with a gutter pipe running into it, and against the barn wall a ladder leans where fresh pale boards have been nailed over grey ones. Four hens pick through the grass at the edge of the beds. The sun is low behind the barn, the light coming past it in long soft shafts, shadows stretching toward the viewer across the beds. Palette held in warm ochre and olive browns: deep umber #38301e, olive #60533d, raw sienna #7e6540, ochre #a68c67, bone #b3a794, pale cream #e2bf93, with the green of the rows kept dusty and unsaturated. The top third is the brightest, roughly half again as bright as the bottom third; the foreground beds and their shadows are the darkest part of the painting. Everything of importance sits inside the central 77% of the width. Ordinary, unhurried, and small in scale: a handful of people making a little food, nothing triumphant.
```

Türkçe kontrol: hurda tahtadan yükseltilmiş sebze yatakları, sırtı dönük üç
figür (yüz belirsiz), oluktan beslenen su fıçısı, yeni tahtalarla yamalanmış
ahır duvarı ve merdiven, dört tavuk, arkadan alçak güneş. Bayrak, kalabalık,
festival, çocuk kalabalığı yok; yeşiller tozlu ve doygunluğu düşük.
Ken Burns normal.

---

## intro_2b — "Doğuda daha büyük yerleşimlerin kurtulduğunu söylüyorlar. Onları beklemeyi yıllar önce bıraktık."

İkinci referans: `pro_5.jpg` (alacakaranlık, tek sıcak ışık).

Setin **soğuk** kartı, ama soğukluk maviyle değil **doygunluğu düşürerek**
veriliyor (0.10'un altı) — mavi-mor bir gökyüzü bu setin dışına düşer.
Kartın bütün işi ikinci satır: bekleme **bıraktırılmış**. Onu anlatan iki
nesne var — zincirin arasından büyümüş ot ve doğuya bakan boş sandalye.

Ken Burns **TERS**: resim sıkı başlar ve geri çekilir, bu yüzden kenarlarda
önemli hiçbir şey olmasın, kompozisyon merkeze toplansın.

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted and very low in saturation, no digital linework. Vertical 9:16 composition. The road out of a small town at last light, looking east: a wooden farm gate stands closed across it, held by a loop of chain, and the grass has grown up through the bars and through the chain itself and been left that way for years. Beyond the gate the road runs on, empty, to a flat horizon with no lights on it, one crooked pole beside it with its wires cut and hanging loose. On the near side of the gate a plain wooden chair sits facing east, its seat weathered pale, its legs sunk into the grass. Cold late dusk: the whole picture in desaturated blue-greys and neutral greys #5a5b5b, with the warm ochres of the set kept only in the wood of the gate and the chair, and a single warm glow from a window somewhere behind the viewer catching the top of the chair back and nothing else. Palette otherwise held in umber and bone: #38301e, #60533d, #b3a794. The gate and the chair sit in the middle third of the frame, centred, with the composition gathered toward the centre and the outer edges left as quiet grass and sky. The bottom third is the darkest part of the painting, and the sky at the top is dim rather than bright — no more than half again the brightness of the foreground. Everything of importance sits well inside the central 77% of the width. Patient and finished with waiting: the gate is not locked against anything, it is simply shut.
```

Türkçe kontrol: doğuya bakan kapalı çit kapısı, zincirin arasından büyümüş
ot, kabloları kesilmiş eğik direk, doğuya bakan boş ahşap sandalye, ufukta
ışık yok. Soğukluk doygunluğu düşürmekle veriliyor; mavi-mor gökyüzü yok,
yazı/tabela yok, insan yok. Kompozisyon merkezde — Ken Burns TERS.

---

## intro_3 — "Dokuzuncu doğum gününün sabahı — Ellie geri dönmedi."

İkinci referans: `pro_2.jpg` (setin en ölçülü, en az süslü kartı).

Kartın hissi ağıt değil, **fark ediliş anı**: kimse henüz kimseye
seslenmemiş. Bu yüzden sahnede tek bir olay var — çiy üstünde eve doğru
değil, **evden uzağa** giden küçük ayak izleri. Promptta "kayıp", "çocuk",
"mezar" gibi kelimeler bilerek geçmiyor: bu kelimeler modeli ya reddettiriyor
ya melodrama çeviriyor. Acıyı kartın metni taşıyor, resim taşımıyor.

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no digital linework. Vertical 9:16 composition. A farmhouse porch on a cold clear morning, seen from the foot of the steps: the front door stands wide open onto a dim hallway, and at the far end of the path the garden gate stands open too. Across the field beyond the gate the grass is white with dew, and a single line of small footprints crosses it away from the house, growing fainter and leaving the frame at the left. On the top step, set down and left there, a small party hat folded from plain brown paper. Low mist lies over the field past the gate and the first light is only just on the hills behind it. The porch itself is in shadow, its floorboards and steps dark and cool, and the brightest part of the picture is the dewy field in the middle distance. Palette held in warm ochre and olive browns with the cold of the morning carried by low saturation rather than by blue: deep umber #38301e, olive #60533d, raw sienna #7e6540, bone #b3a794, pale cream #e2bf93. The footprints and the open gate sit between 38% and 55% of the frame height; the dark porch boards fill the bottom third and are the darkest part of the painting, well under half the brightness of the top. Everything of importance sits inside the central 77% of the width. Still, plain and factual: two things left open and one set of marks going away.
```

Türkçe kontrol: ardına kadar açık kapı, açık bahçe kapısı, çiy üstünde evden
uzağa giden küçük ayak izleri, basamakta kahverengi kâğıttan katlanmış parti
şapkası, tarlada alçak sis, gölgede koyu veranda tahtaları. Kurdele, çiçek,
mum, oyuncak, ayakkabı, pasta, bayrak yok; yazı yok; insan yok.
Ken Burns normal.

---

## Bonus — `pro_7` (istersen)

Prolog'un yedi kartı var, altı resmi: son kart (`PRO_07` — "Zamanla beni Şerif
yaptılar… Dokuz yıl sonra Ellie kaybolduğunda seni çağırdım") `pro_6`'yı pan
yönü ters çevrilerek ikinci kez kullanıyor. Ayrı bir resim istersen:

İkinci referans: `pro_5.jpg`.

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no digital linework. Vertical 9:16 composition. A small town seen from the top of the rise above it at dusk, nine years on and holding together: a dozen roofs among trees, four or five windows lit warm, straight vegetable rows behind the nearest houses, a water tower on plain steel legs, and a mown track running down the slope from the viewer's feet into the town. In the immediate foreground, on a fence post at the side of the track, a wide-brimmed hat has been hung and left. The hills close the far side of the valley and the last of the light is behind them. Palette held in warm ochre and olive browns: deep umber #433a28, olive #60533d, raw sienna #7e6540, ochre #a68c67, pale cream #e2bf93, with the lit windows the only saturated warmth in the picture. The town sits between 40% and 60% of the frame height, centred; the foreground slope and the fence post fill the bottom third and are the darkest part of the painting, under half the brightness of the sky. Everything of importance sits inside the central 77% of the width. Responsible and tired: one man looking down at a place he is answerable for.
```

Türkçe kontrol: tepeden görülen kasaba, birkaç sıcak ışıklı pencere, su
kulesi, yamaçtan inen biçilmiş iz, ön planda çit direğine asılmış geniş
kenarlı şapka. Yıldız/rozet, üniforma, silah, bayrak yok; yazı yok; insan
yok. Kartın hissi "hesap verilen bir yer".

## Geldiğinde

Dosyaları `textures/intro/` içine at, adları önemli değil — söyle, ben
`intro_1.jpg`, `intro_2.jpg`, `intro_2b.jpg`, `intro_3.jpg` (ve varsa
`pro_7.jpg`) olarak dönüştürüp içe alır, `PrologueShot` ile telefon
kadrajında render alıp yazının okunurluğunu ve alt üçte birin
parlaklığını ölçerim. `pro_7` gelirse `data/story.json` içindeki
`prologue.after` son kartını ona çeviririm.
