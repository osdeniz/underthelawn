# Prolog kartları — Gemini için promptlar (pro_1 … pro_6)

Altı resim de eksik (`textures/intro/` içinde yalnızca intro_1, intro_2,
intro_2b, intro_3 var; prolog kartları şimdilik onlara düşüyor). Hedef:
`textures/intro/pro_1.jpg` … `pro_6.jpg`.

## Gemini'de nasıl kullanılır

1. **En boy oranını arayüzde 9:16 (dikey) seç.** Prompt metnine piksel
   yazmayın — "1170×2532" model için gürültü ve bazen resmin içine sayı
   çizdiriyor. Mevcut dört kart 1172×2100 (oran 0.558), yani 9:16 sete uyar.
2. **Her prompta stil referansı olarak `textures/intro/intro_1.jpg`
   dosyasını ekleyin** ve promptun sonundaki cümleyi bırakın ("match the
   palette and brushwork of the attached painting"). Setin tutarlılığı için
   en etkili yöntem bu; altı kart aynı elden çıkmış görünür.
3. **Prompt metni İngilizce** olsun. Aynı sahneyi Türkçe verdiğinizde Gemini
   belirgin biçimde daha az uyuyor. Her promptun altında ne istediğinin
   Türkçe özeti var, kontrol için.
4. **"Şu olmasın" listesi yazmayın.** Görüntü modelleri olumsuzu okumaz;
   "insan yok" yazınca insan koyma olasılığı artar. Aşağıdaki promptlar her
   yasağı olumlu cümleye çevirdi ("the street stands empty, every door
   closed").
5. Her resmi 3–4 kez üretip, **alt üçte biri en koyu olanı** seçin (aşağıya
   bakın). Beğendiğinizi "same painting, but …" ile düzeltmeyin; promptu
   bir kelime değiştirip yeniden üretmek daha temiz sonuç veriyor.

## Ölçülen kısıtlar (bunlar tahmin değil, koddan ve mevcut resimlerden)

**Palet.** Mevcut dört kartın baskın renklerinin tamamı 30–52 ton aralığında
(okra → zeytin), doygunluk 0.12–0.53. Sette mavi, mor, yeşil baskın renk
olarak hiç yok. Duraklar: `#38301e` `#433a28` `#60533d` `#7e6540` `#a68c67`
`#b3a794` `#e2bf93` `#f5e6cd`, artı doygunluğu düşürülmüş kartta tek bir nötr
gri `#5a5b5b`. Senin taslaklarındaki "gökyüzü mavi-mor" ve "soğuk mavi-gri"
bu setin dışına düşerdi: alacakaranlık kartında soğukluğu **doygunluğu
0.10'un altında, hafif maviye kaçan grilerle** verdim, tek sıcak kaynak
veranda ışığı olarak kalsın.

**Güvenli kadraj.** Kartlar `KEEP_ASPECT_COVERED` ile çiziliyor ve Ken Burns
1.06'ya kadar yaklaşıyor. iPhone 16 Pro'da (1170×2532) 9:16 bir resmin
görünen genişliği %77'ye düşüyor: **her iki yandan ~%11 kesiliyor**, üstten
ve alttan ~%3. Yani önemli hiçbir şey kenarlardaki %12'ye girmesin. (Menü
kapağı tam bu yüzden başlığını kaybetmişti, G35.)

**Değer yapısı.** Kart metni yüksekliğin %58'inden başlıyor ve üstüne
yukarıdan aşağı %5 → %78 siyaha giden bir perde biniyor. Mevcut resimlerin
üçte bir ortalama parlaklıkları: üst 136–180, orta 98–146, **alt 63–86**.
Kural: alt üçte bir, üst üçte birin yarısı kadar parlak olsun. Promptlara
yazdım.

**Ken Burns yönü.** pro_2 ve pro_6 ters yönde (sıkı başlar, açılır); o iki
kartta kenarlarda önemli detay olmaması ayrıca önemli.

---

## pro_1 — "Hastalığın ilçeyi geçmesi on bir gün sürdü. Kızımı dört günde aldı."

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted and slightly washed out, no digital linework. Vertical 9:16 composition. The empty main street of a small rural town at midday, seen from the middle of the road at eye level: two-storey clapboard houses on both sides, every curtain drawn, every door closed, a porch with a small stack of unopened mail gone soft with damp. In the lower left third, a car stands with its door left open, leaves collected on the seat, rain having got in long ago. The road narrows away from the viewer and ends at a county road and the first field gone to tall grass. Flat overcast noon light, almost no shadows. Palette held entirely in warm ochre and olive browns: deep umber #433a28, raw sienna #7e6540, ochre #a68c67, bone #b3a794, pale cream #e2bf93, with no saturated colour anywhere. The bottom third of the picture is the darkest part of the painting, roughly half as bright as the top third. Everything of importance sits inside the central 77% of the width. Quiet, still, vacant: something happened and finished, and nobody came back. Match the palette and brushwork of the attached painting.
```

Türkçe kontrol: boş ana cadde, açık araba kapısı sol altta, kapalı perdeler,
uzakta otlanmış ilk tarla. Kimse yok, hiçbir şey kırık veya yanmış değil,
tabela/yazı yok. Ken Burns normal.

---

## pro_2 — "Adı Maggie'ydi. Beş yaşındaydı. Çukuru kendim kazdım…"

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no digital linework. Vertical 9:16 composition. The corner of an old back garden under a large bare-limbed tree, early morning: in the middle of the frame a rectangle of freshly turned dark earth, level with the ground, its edges still crumbling, and a garden spade standing upright in the soil beside it. A single plain board of untreated wood, entirely blank, leans against the tree trunk. Behind, the corner of a house with one dark window. The garden stands empty and completely still. Low cold side light from the left, the tree throwing one long shadow across the turned earth, dew on the grass; the only warmth in the picture is the wooden handle of the spade. Palette held in warm ochre and olive browns: deep umber #38301e, raw sienna #7e6540, ochre #a68c67, bone #b3a794, with no saturated colour. The turned earth sits between 40% and 55% of the frame height, centred; the tree trunk carries the right edge. Everything of importance sits inside the central 77% of the width, and the bottom third is the darkest part of the painting. Restrained and factual, nothing decorative, nothing added.
```

Türkçe kontrol: kazılmış toprak, kürek, yazısız tahta, ağaç, karanlık
pencere. **Bilerek "mezar", "çocuk", "gömü" kelimeleri geçmiyor** — bu
kelimeler Gemini'de ya reddettiriyor ya melodrama çeviriyor; acıyı kart
metni taşıyor. Reddederse "freshly turned earth" yerine "a newly dug and
levelled planting bed" yazın, resim aynı çıkar. Çiçek, mum, kurdele, oyuncak
eklenmesin. Ken Burns TERS.

---

## pro_3 — "Ondan sonra sadece yol kaldı, o yol da çimene dönmüştü."

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no digital linework. Vertical 9:16 composition. A two-lane country road running from the viewer's feet straight to the horizon, the asphalt swallowed by waist-high grass so that only broken fragments of the faded yellow centre line still show through. Leaning telephone poles along both verges with their wires sagging low. Low hills at the horizon and, at the very end of the road where it narrows to a point, a tiny indistinct roofline: somewhere to reach, and very far away. The road lies empty, nothing on it and nothing beside it. Late afternoon, the sun low to the right, the grass heads backlit and turning gold while the asphalt fragments stay cool grey, long horizontal shadows across the lanes. Palette held in warm ochre and olive browns: deep umber #433a28, olive #60533d, raw sienna #7e6540, ochre #a68c67, pale cream #e2bf93. The vanishing point sits about 30% down the frame, centred; foreground grass fills the bottom third and is the darkest part of the painting. Everything of importance sits inside the central 77% of the width. Tired but walkable: the road is distance, not threat.
```

Türkçe kontrol: otların altında kaybolmuş yol, eğik direkler, ufukta
küçücük çatı hattı. Araç, tabela, bavul gibi kıyamet klişeleri yok.
Ken Burns normal.

---

## pro_4 — "Bir barakada ne varsa aldım ve önümü biçerek yürüdüm."

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no digital linework. Vertical 9:16 composition. In the lower right third, the open doorway of a small field shed, its interior a warm brown darkness, and half pulled out of it an old red push lawn mower: red painted body, black wheels, a bent metal handle. From the shed a single mown stripe runs away across the field, short green down its middle and waist-high grass standing on either side, and joins the country road in the distance about 30% down the frame. The field is otherwise untouched and empty of people; the stripe is the only mark anyone has made. Morning, the sun low on the left, the cut stripe wet and shining, dew on the severed grass tips. Palette held in warm ochre and olive browns: deep umber #433a28, olive #60533d, ochre #a68c67, bone #b3a794, with the mower's dull red as the single accent and no other saturated colour. The mower sits between 55% and 65% of the frame height; the mown stripe runs diagonally from lower right to upper left. Everything of importance sits inside the central 77% of the width, and the bottom third is the darkest part of the painting. Small, mechanical, stubborn: a man has found a way to keep going.
```

Türkçe kontrol: baraka kapısı sağ altta, oyundakiyle aynı kırmızı itmeli
makine, tek biçilmiş şerit diyagonal olarak yola çıkıyor. Kırmızı, resmin
tek doygun rengi — bu bilinçli, oyunun makinesi o. Benzin bidonu, marka,
yazı yok. Ken Burns normal.

---

## pro_5 — "Bir çit vardı ve birinin verandasında yanan bir ışık. On dokuz gündür yürüyordum."

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no digital linework. Vertical 9:16 composition. Eye level from inside the tall grass at the roadside, blurred grass heads framing both lower corners. In the middle distance a long wooden fence line with one gate standing open. Beyond the fence, further back, a dark house in silhouette with a single warm yellow porch light burning — the only warm light in the whole painting — throwing a weak halo onto the ground at the foot of the fence. Low hills behind. Dusk, the sun already gone, the sky empty and even: dim grey-blue at the top desaturated almost to grey, paler cool grey at the horizon, every cool tone kept below 10% saturation so the picture still reads as the same warm ochre family. Grass and fence in cool olive greys: #5a5b5b, #60533d, #433a28, with the porch light's #e2bf93 as the one exception. The porch light sits between 42% and 50% of the frame height, in the right third; the fence runs as a horizontal line at about 55%. The bottom third is grass in near-darkness and is the darkest part of the painting. Everything of importance sits inside the central 77% of the width. Not relief yet: somebody is there, and the walking has stopped.
```

Türkçe kontrol: çit hattı, açık kapı, tek sıcak veranda ışığı sağ üçte
birde. Pencerede insan silüeti, ay, ikinci ışık, far yok. **Taslaktaki
"mavi-mor gökyüzü" burada doygunluğu %10'un altına indirilmiş grilere
çevrildi**; yoksa kart diğer beşinden kopardı. Ken Burns normal.

---

## pro_6 — "İkinci kez yapamazdım… Bu yüzden onu bir kasabanın tamamına verdim."

```
Oil painting on canvas, painterly with visible brush texture and soft edges, muted, no digital linework. Vertical 9:16 composition, cropped at chest height so that no face is in the frame. At the centre, a wicker basket with a folded rust-red blanket inside it, held by two pairs of adult hands at the same moment: on the left a man's hands, weathered, soil-stained, the nails dark, still gripping the handle a little too tightly; on the right a woman's hands, clean, a knitted cardigan cuff at the wrist, taking the weight. The basket is held by both. Behind them a porch step and a plain painted board wall, morning. In the lower left corner, entering the frame, the tan back and one ear of a dog looking up at the basket, small and unemphasised. Soft morning light from the upper right; the basket and blanket carry the warmth, the hands are neutral, the background is pale and low contrast. Palette held in warm ochre and olive browns: bone #b3a794, ochre #a68c67, umber #433a28, pale cream #f5e6cd, with the blanket's dull rust red as the only saturated colour. The basket sits between 38% and 52% of the frame height, centred, the hands cutting in from both edges. Everything of importance sits inside the central 77% of the width, and the bottom third is the darkest part of the painting. Quiet and factual: the moment a thing passes from one pair of hands to another.
```

Türkçe kontrol: sepet, kırmızı battaniye, iki çift el, arkada veranda
basamağı, sol altta köpeğin sırtı. **Bebek bilerek çıkarıldı**: kundak ve
bebek imgesi hem Gemini'de sık sık reddediliyor hem de kötü çiziliyor;
katlanmış battaniye onu ima ediyor, kartın metni zaten söylüyor. Yüz, yüzük,
gözyaşı yok — gerginliği yalnızca sol eller anlatıyor. Ken Burns TERS,
köpek açılırken görünen ödül: promptta köşede duruyor, tam kenara koymayın.

---

## Teslim

JPG, dikey 9:16, en az 1172×2100 (daha büyüğü iyi). Dosya adları
`pro_1.jpg` … `pro_6.jpg`, `textures/intro/` içine. Godot bir sonraki açılışta
kendisi içe alır; o zamana kadar kartlar mevcut yedek resimlere düşmeye
devam eder. Altısı geldiğinde bir tur render alıp metnin her kartta okunur
kaldığını ölçerim.
