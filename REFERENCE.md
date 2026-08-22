# LastLawn — Godot Taşıma Referansı

Bu doküman, LastLawn'ın SwiftUI + SceneKit prototipinde (Sprint 1 → 5A) inşa edilen
**her sistemi, algoritmayı ve ayar değerini** Godot'a birebir taşıyabilecek ayrıntıda
tarif eder. Swift kodu okumadan, yalnızca bu dokümanla aynı oyunu kurabilmelisin.

---

## 1. Oyun konsepti ve hedef his

- **Tür:** Rahatlatıcı, tatmin edici (satisfying) çim biçme oyunu. Amerikan banliyö bahçesi, sıcak bir yaz günü.
- **Görsel hedef:** Stilize-gerçekçi, mid-core mobil seviye. Fotogerçekçilik değil; doygun doğal renkler, tek güneş, yumuşak gölgeler, dolgun çim.
- **Çekirdek döngü:** Bahçedeki tüm biçilebilir hücreleri biç → %100'de "LAWN COMPLETE" + kamera kuşbakışı ödül anı. Kanca: çimin altına saklanmış 2 gizli obje (secret) keşfi.
- **Platform hedefi:** Mobil (iOS'ta 60fps hedefiyle geliştirildi), portre yönelim.

---

## 2. Dünya düzeni ve koordinatlar

SceneKit sahnesindeki düzen (Godot'ta aynı yerleşimi kur; eksen adları değişebilir):

- **1 birim = 1 hücre.** Grid: **16 sütun × 24 satır = 384 hücre**, orijin merkezli.
  - Hücre merkezi: `x = col + 0.5 - 8`, `z = row + 0.5 - 12`
  - row 0 = **kuzey** (ev tarafı, -Z), row 23 = güney (yol tarafı, +Z).
- **Yön kuralı:** yaw=0 → kuzey. `forward = (sin(yaw), 0, -cos(yaw))`. Yaw artışı = sağa dönüş.
- **Yerleşim (kuzeyden güneye):**
  - Ana ev: `z = -(12 + 4.8)` merkezli (veranda lawn'a taşmasın diye 4.8 birim geride)
  - Lawn: `x ∈ [-8, 8]`, `z ∈ [-12, 12]`
  - Çit: yanlarda `x = ±9.6`, güneyde `z = 13.6` (kuzeyde ev var, çit yok)
  - Kaldırım: `z ≈ 15.2` merkezli, 2.2 birim derin
  - Asfalt yol: `z ≈ 19.4` merkezli, 6.5 birim derin, 60 birim geniş
  - Komşu evler: `z ≈ 28.4`, x = -11 / 0.5 / 11.5
- **Mower başlangıcı:** `(0, z = 10.5)` yani güney-orta, kuzeye (eve) bakar.

---

## 3. Veri modeli (LawnModel) — render'dan tamamen bağımsız tut

Godot'ta saf bir GDScript/C# sınıfı olarak birebir taşı:

```
enum CellState { TALL, MOWED, OBSTACLE, SECRET, SECRET_REVEALED }
```

- `states: CellState[384]`, `mowedCount: int`
- **mowableCells** = OBSTACLE olmayan hücre sayısı (SECRET'lar dahil). Tamamlanma: `mowedCount >= mowableCells`.
- `mow(col, row)` → sonuç: `NONE` (zaten biçik/engel) | `MOWED` | `SECRET_REVEALED`. TALL→MOWED, SECRET→SECRET_REVEALED; MOWED bir daha değişmez (görsel yeniden-şeritleme hariç, bkz. §4).
- **Engeller** (`OBSTACLE` işaretlenir + çarpışma dikdörtgeni listesine eklenir):
  - Çiçek tarhı: 2 hücre — grid oranı (0.30, 0.62) ve (0.36, 0.62) → col 4 ve 5, row 14
  - Taş: (0.72, 0.38) → col 11, row 9
  - **Havuz:** col 10–13 × row 17–19 (12 hücre). Çarpışma için hücre hücre değil **TEK büyük dikdörtgen** eklenir (kenar boyunca pürüzsüz kayma için)
  - Şezlong hücresi: havuzun doğusu, col 14, row 18
- **Çarpışma dikdörtgenleri:** her engel için `(minX, maxX, minZ, maxZ)` dünya koordinatında (hücre ±0.5).
- **Secret yerleşimi (her oyunda rastgele):** 2 hücre; kenarlardan ≥2 hücre içeride, durumu TALL olmalı, iki secret arası mesafe ≥8 hücre. 300 deneme limiti. Restart'ta tüm MOWED/SECRET_REVEALED/SECRET hücreler TALL'a döner ve secret'lar YENİDEN rastgele dağıtılır.

---

## 4. Biçme mekaniği ve GERÇEK LAWN STRIPING (yön bazlı)

### Biçme
- Her frame, mower merkezli **deck yarıçapı** içinde merkezi kalan tüm hücreler biçilir (yarıçap tipe göre, bkz. §6). Tarama: yarıçapı kapsayan hücre penceresi + merkez mesafe testi.
- **Frame başına tek haptic + tek biçme sesi** (kaç hücre biçilirse biçilsin) — titreşim/ses boğulmasın.
- Biçme yalnızca hareket halindeyken değil her zaman aktif (bıçak dönüyor); pratikte hareketle tetiklenir.

### Striping (ana görsel mekanik — Sprint 5A)
- Şerit tonu hücreden **geçiş yönüne** göre: yön kovası `0=K, 1=D, 2=G, 3=B`
  (`|fx| >= |fz|` ise doğu/batı, değilse kuzey/güney).
- 4 ton (zemin çarpım/tint rengi olarak):
  - Kuzey: `(1.00, 1.00, 0.92)` — en açık
  - Doğu: `(0.90, 0.95, 0.82)`
  - Batı: `(0.77, 0.85, 0.67)`
  - Güney: `(0.66, 0.75, 0.58)` — en koyu
- **Yeniden şeritleme:** hücre zaten biçikse ama yeni geçiş yönü kovası farklıysa ton GÜNCELLENİR (sayaç/haptic değişmez). Hücre başına `son şerit yönü` (Int8, -1=yok) tutulur. Sonuç: oyuncu paralel gidiş-gelişlerle baseball-field deseni çizebilir.
- Secret hücresi biçilince ton yerine **toprak rengi** `(0.52, 0.38, 0.26)`.

### Biçme animasyonu
- Hücrenin çim tutamı **mower'ın gittiği yöne yatarak** kaybolur: tutam node'u önce yaw'a çevrilir, sonra 0.1 sn'de öne ~77° devrilir (`rotateBy x: -1.35`) + 0.25'e ölçeklenir, sonra gizlenir.
- Parçacık: mower'ın **SAĞ yanından** püsküren yaprak biçimli kırpıntılar (bkz. §9).

---

## 5. Çim görselleştirme

### Zemin — tek sürekli plane + hücre tint haritası
- Zemin 16×24 birimlik TEK plane. Çim albedo dokusu **X'te 7 tekrar** (Z orantılı ~10.5), üstüne normal map (yoğunluk 0.6), roughness 0.95.
- Hücre durumu, **16×24 piksellik küçük bir doku** ile gösterilir: her piksel bir hücrenin renk çarpanı (multiply). Linear filtreleme hücreler arası yumuşak geçiş verir. Biçmede tek piksel boyanıp doku güncellenir.
  - Godot karşılığı: zemin materyaline ikinci bir `tint` texture'ı + shader'da `albedo *= texture(tint, cell_uv)`; ya da 16×24'lük `ImageTexture`'ı `Image.set_pixel` ile güncelle.
- Tint değerleri: uzun çim `(0.62, 0.64, 0.44)` (koyu sarımsı), biçilmiş = §4'teki 4 ton, toprak `(0.52, 0.38, 0.26)`, havuz tabanı `(0.70, 0.92, 0.95)` (su yarı saydam olduğu için altı havuz tabanı gibi görünür).

### Uzun çim tutamları — crossed quads
- Biçilebilir her hücrede **1 tutam kümesi node'u**. Küme = **7 tutam × 2 kesişen quad** (üst kenar %75'e daralır), tek geometri.
- **Performans kuralı:** yalnızca **8 paylaşılan küme geometrisi varyantı** üretilir (deterministik seed'li RNG ile); 384 hücre bunları klonlamadan paylaşır. Çeşitlilik node bazlı: rastgele Y rotasyonu + 0.9–1.1 ölçek + hücre içi konum jitter'ı.
  - Godot karşılığı: **MultiMeshInstance3D** (8 MultiMesh, hücreler instance) — SceneKit'tekinden bile verimli olur.
- Tutam ölçüleri: boy 0.30–0.66, en 0.26–0.46; küme içi ofset ±0.34.
- Doku: transparan zemin üzerinde 9 sivri yaprak silüeti (kök imajın altında), alpha'lı; çift taraflı materyal; normaller YUKARI bakar (çim kartı hilesi — arka yüz kararması olmaz, zemin gibi aydınlanır).
- **Rüzgar sallanması GPU'da** (vertex shader):
  `pos.x += sin(TIME * 2.0 + pos.x*4.0 + pos.z*5.0) * max(pos.y, 0) * 0.06`
  (genlik 0.06, hız 2.0; kök sabit, uç sallanır).

### Prosedürel dokular (TextureLibrary)
Tümü önce diskte aranır (`grass_albedo` vb. isimlerle), yoksa runtime üretilir. Godot'ta NoiseTexture2D veya ambientCG/PolyHaven CC0 dokularıyla değiştir. Üretilen setler:
`grass_albedo` (512, yeşil leke + kırpıntı çizik + kuru sarı uçlar, seamless), `grass_normal` (256), `dirt_albedo`, `asphalt_albedo` (çatlaklı), `siding_albedo` (32px yatay paneller), `roof_shingles_albedo` (kaydırmalı kiremit sıraları), `bark_albedo`, `wood_albedo` (damarlı çit ahşabı), `grass_blade_tuft` (tutam silüeti), `cloud_billboard` (radyal blob yığını), `leaf_particle` (12×32 ince yaprak), `ao_radial` (radyal siyah degrade — tüm fake gölgeler bundan).

---

## 6. Mower tipleri ve parametreleri

| Parametre | Push 🔴 | Traktör 🚜 | Robot 🤖 |
|---|---|---|---|
| Hız (birim/sn) | 3.0 | 4.8 | 2.1 |
| Kesim yarıçapı (birim) | 0.7 (1 hücre) | 1.1 (2 hücre) | 0.7 |
| Maks. dönüş hızı (rad/sn) | 1.7 | 1.5 | 2.6 |
| Gövde yarıçapı (çarpışma) | 0.55 | 0.85 | 0.45 |
| Kontrol | sürükle-yönlendir | sanal joystick | otonom + dürtme |
| Geri vites | yok | var (0.5×) | yok |
| Ses | motor | motor | sessiz vızıltı |
| Sürücü karakteri | arkasında yürür | koltukta oturur | yok |

### Modeller (primitive kombinasyonları, hepsi -Z'ye bakar)
- **Push:** metalik kırmızı deck (0.72×0.16×0.95) + koyu ön bıçak bloğu + motor bloğu + kırmızı kaput + starter/yakıt kapağı silindirleri + yan **egzoz borusu** + 4 tekerlek (lastik r0.13 + çelik jant + göbek) + çelik itme kolu (2 boru, x-ekseni eğimi +0.9 rad yani üst uç geriye) + **kauçuk tutamaç** + altta fake-AO dairesi (1.5). Boya: metalness 0.65 / roughness 0.28. Rölanti titreşimi: gövde grubu ±(0.004, 0.007) 0.045 sn periyot.
- **Traktör:** sarı geniş kesim tablası (1.5×0.9), yeşil şasi (0.75×0.3×1.9) + önde kaput, direksiyon kolonu + torus simit, koltuk + sırtlık, arka tekerlek r0.30 / ön r0.18 (sarı jantlı). Renkler: gövde `(0.22,0.45,0.16)`, aksan `(0.95,0.78,0.15)`.
- **Robot:** basık koyu silindir taban (r0.42×0.12) + basık yarım küre kabuk (r0.40, y-ölçek 0.42) + **emissive LED torus halka** (camgöbeği `(0.2,0.85,0.9)`, 0.9 sn'de nefes alır gibi parlar-söner) + ön sensör gözü + kırmızı uçlu anten.

---

## 7. Kontrol şemaları (Sprint 5A — HAREKET OTOMATİK DEĞİL)

### Ortak hareket çekirdeği
- **Throttle:** girdi varken hedef hız oranı dolar, bırakınca 0.
- **Hızlanma:** 0→max **0.4 sn** lerp. **Yavaşlama:** bırakınca **0.55 sn**'de doğal durma (anında fren yok). `rate = maxSpeed / süre; speed += clamp(target-speed, ±rate*dt)`.
- **Smooth steering:** hedef açısal hız → mevcut açısal hıza lerp:
  ```
  omega += (desiredOmega - omega) * min(1, 9.0 * dt)      // steerSmoothing = 9
  speedFraction = |speed| / maxSpeed
  yaw += omega * (1 - 0.45 * speedFraction) * dt          // hızlıyken dönüş %45 genişler
  ```
- Duvarlar: pozisyon lawn sınırına kırpılır (inset = bodyRadius×0.6) → kayma kendiliğinden. Otomatik duvara-paralel dönme YOK (oyuncu kontrolünde).
- Engel çarpışması: daire-dikdörtgen en yakın nokta testi → penetrasyon kadar normal boyunca dışarı itme. Yansıma yok.

### Push
- Parmak basılıyken: throttle=1, sürükleme delta'sı (min 8pt) **kamera-göreli** hedef yaw üretir: `targetYaw = camYaw + atan2(dx, -dy)`. `desiredOmega = clamp(shortestAngle(yaw→target) * 5, ±maxTurn)`. Parmak kalkınca throttle=0 → yavaşlayıp durur.

### Traktör (sanal joystick, sol alt)
- Joystick **Y**: ileri/geri gaz — `dy>0 → throttle=dy`, `dy<0 → throttle=dy*0.5` (geri yavaş).
- Joystick **X**: direksiyon — `desiredOmega = joyX * maxTurn * sign` (geri giderken işaret ters: araç gibi).
- Joystick bırakılınca throttle=0, steer=0.
- Joystick UI: taban r55pt, topuz r24pt, ölü bölge 0.25, bırakınca yayla merkze döner.

### Robot (otonom boustrophedon + dürtme)
- **Rota üretimi:** satır satır serpantin (çift satır soldan sağa, tek satır sağdan sola), her hücre için waypoint. Engel hücresi yerine **aynı sütunda en yakın açık satıra** (±1..±4 ara) detour waypoint'i konur → havuz/tarh çevresinden dolaşır.
- **Yürütme:** aktif waypoint'e `targetYaw = atan2(dx, -dz)`; varış mesafesi **0.35**. Hücresi zaten biçilmiş waypoint'ler atlanır. Liste bitince kalan bekleyen hücrelerden en yakını hedeflenir; hiç kalmadıysa robot durur (throttle 0).
- **Zemine dokunma:** hit-test → o noktaya gider (lawn içine kırpılır), varınca **en yakın bekleyen waypoint'ten** devam.
- **Swipe dürtme (YENİ):** ≥60pt swipe → yön kamera-göreli dünyaya çevrilir, `hedef = pozisyon + yön × 3.5` (lawn içine kırpılır) override edilir; robot o yönde ~3-4 hücre biçip pattern'ine döner. Smooth steering geçerli.

---

## 8. Sürücü karakteri (Character3D)

İskelet sistemi YOK — eklemler ayrı node, animasyon sinüs/lerp. Boy ~1.55 birim, kafa/boy ~1/7.

### Yapı (pivotlar: rotasyon omuzdan/kalçadan)
- Gövde kutusu 0.34×0.44×0.20 (turuncu tişört `(0.92,0.50,0.18)`), pivot bel hizasında.
- Kafa küresi r0.115 (ten `(0.87,0.67,0.52)`) + **kaş/göz koyu bandı** (0.16×0.035, yüz önünde) + güneş şapkası (kenar silindiri r0.175 + tepe r0.10, haki).
- Kollar: omuz pivotu (±0.21, 0.42), üst kol (tişört) 0.24 + alt kol (ten) 0.22 + el küresi.
- Bacaklar: kalça pivotu ±0.09; üst bacak (kot `(0.28,0.36,0.52)`) 0.36, diz pivotu, alt bacak 0.34 + bot (0.11×0.09×0.22, öne uzar).
- Karakter **mower node'unun child'ı** → araçla döner, rig gizlenince gizlenir. Gölge düşürür.

### Push pozu ve yürüme
- Konum: mower lokali (0, 0.79, +1.45) — arkada. Kollar öne-aşağı handle'a: euler x=-0.85, hafif içe. Gövde öne eğik x=-0.12.
- **Yürüme** (hız oranı > 0.06): `phase += dt * (5 + 3.5*speedFraction)`
  - Üst bacaklar: `±sin(phase) * 0.48` (zıt fazlı)
  - Dizler: yalnız geri salınımda kırılır: `max(0, ∓sin(phase)) * 0.55`
  - Gövde yalpası: `z = sin(phase)*0.045`, dikey zıplama `|sin(phase)|*0.022`
- **Idle:** bacaklar hızla toparlanır (lerp 8/sn), nefes: `torsoY = sin(t*2.2)*0.008`.

### Traktör pozu ve sürüş
- Konum: traktör lokali (0, 0.80, +0.42) — koltukta. Üst bacaklar yatay (x=-1.35), alt bacaklar aşağı (x=+1.15). Kollar direksiyona: x=-1.35, ±0.28 içe.
- **Direksiyon tepkisi** (steer = normalize omega): gövde yaw hedefi `-steer*0.18` (lerp 6/sn), kafa gövdenin 0.6'sı, kollar z'de `∓0.10 - steer*0.12`.
- Motor titreşimi: `torsoY = sin(phase*40)*0.004`.

---

## 9. Efektler

- **Kırpıntı parçacıkları:** mower'ın SAĞ yanından (`right = (cos yaw, 0, sin yaw)`, ofset 0.45) püskürür; yön `sağ + 0.8 yukarı`, yayılma 55°, hız 2.4±1.2, yerçekimi -9.8, ömür 0.6±0.25, boyut 0.045, açısal hız 300±180°/sn, doku = yaprak imajı, birthRate 90, emisyon 0.06 sn, **alpha blend** (additive DEĞİL). Spawn frekans limiti: 0.12 sn.
- **Secret ışıltısı:** altın küre r0.15 (emissive `(1.0,0.82,0.25)`), 0.8 sn'de ±0.16 yüzer + 0.5 sn'de 1.0↔1.3 pulse + sürekli döner; üstüne loop'lu kıvılcım parçacığı (birthRate 10, boyut 0.035, yukarı süzülür).
- **Kazı efekti:** toprak renkli patlama (birthRate 160, 0.15 sn emisyon, ömür 0.5, yerçekimli).
- **Keşif objeleri:** topraktan -0.15'ten +0.7'ye 0.7 sn'de yükselir + döner, 1.4 sn bekler, yukarı süzülerek kaybolur.
  - 🔑 Anahtar: dik torus halka (r0.11) + şaft silindiri + 2 diş kutusu; altın-kahve `(0.62,0.48,0.22)`, metalness 0.8.
  - 📻 Radyo: kahve kutu (0.44×0.28×0.14) + koyu ızgara + 3 metal tel + 2 döner düğme + eğik anten.

---

## 10. Kamera

- Perspektif, FOV 55°, **arkadan-üstten takip**. Zoom preset'leri (geride/yükseklik/ileri bakış):
  - near (3.6, 3.0, 1.6) · **mid (5.0, 4.2, 2.2)** ← aktif · far (7.0, 6.0, 2.8)
- Takip: odak noktası mower'a lerp (**4.0/sn**), kamera yaw'ı mower yaw'ına lerp (**2.6/sn** — dönüşlerde gecikme hissi). Pozisyon: `odak - forward(camYaw)*back + (0, height, 0)`; bakış: `odak + forward*lookAhead + (0, 0.3, 0)`.
- **Tamamlanma:** kamera `(0, 30, 4)`'e lerp'lenir (1.8/sn), merkeze kuşbakışı bakar.

---

## 11. Havuz

- 4×3 hücre gömülü havuz. **Su:** yarı saydam turkuaz `(0.30,0.75,0.82, a=0.72)`, roughness 0.12, segmentli plane (16×12) + vertex dalga shader'ı: `y += sin(TIME*1.8 + x*3.0 + z*2.2) * 0.02`.
- Taş bordür: 4 kenarda açık krem `(0.90,0.88,0.82)` kutular (0.35 kalın, 0.12 yüksek).
- Şezlong: ahşap dokulu iskelet (oturak 0.6×1.0 + eğik sırtlık -0.7 rad + 4 ayak) + **turuncu katlanmış havlu** kutusu; havuzun doğusundaki engel hücresinde, batıya bakar.

---

## 12. Çevre / mahalle envanteri

- **Ana ev:** siding dokulu gövde (13×3.2×4.2) + kiremit dokulu piramit çatı (14.2×2.4×5.4) + **baca** (tuğla kutu + şapka, çatıda) + kapı (çerçeve + 2 gömme panel + paspas) + 2 pencere (çerçeve + **karanlık iç mekan katmanı** + iki yanda krem **perdeler** + yarı saydam yansımalı cam + artı kayıt + denizlik) + veranda (platform + döşeme + 2 direk + **korkuluk**: üst ray + 4'er dikey çubuk + kiremit saçak + basamak) + duvar dibi **5 çalı** (basık küreler, kapı önü boş) + duvar dibi temas gölgesi bandı (ao dokusu).
- **Çit:** ahşap dokulu; kazık 0.14×~0.85×0.06 sivri değil düz + yatay kiriş; **her kazıkta ±0.05 boy ve ±0.025 rad açı jitter'ı** (el yapımı his). Aralık 0.62.
- **Ağaçlar (3):** lawn dışında — (-9.3,-10.8) s1.0 / (9.1,-2) s0.85 / (-9.2,8) s0.9. Bark dokulu hafif eğik gövde + **2 eğik dal silindiri** + **9 küçük iç içe deforme küme** (halka dizilimli, alçaklar koyu `(0.20,0.42,0.16)`, yüksekler açık `(0.33,0.57,0.25)`, eksen bazlı rastgele ölçek) + zeminde yaprak gölge lekesi (ao dokusu, güneş yönünde ofsetli).
- **Yol:** asfalt dokulu plane + kesik sarımsı orta şerit çizgileri (1.6×0.14, 4 birim arayla) + derzli kaldırım.
- **Arabalar (yolda park):** mavi **sedan** `(0.25,0.42,0.62)` (alt gövde + kabin + koyu yansıtıcı cam bloğu + emissive farlar + kırmızı stoplar) ve kırmızı **pickup** `(0.62,0.28,0.22)` (kabin önde + açık kasa duvarları). Her ikisinde: jant/göbek detaylı tekerlekler, **yan camlar, kapı derzi, ön/arka plaka, yan aynalar**. Boya metalness 0.55 / roughness 0.3.
- **Komşu evler (3, düşük detay):** krem / adaçayı / kiremit-pembe gövde + kiremit çatı + kapı + 2 pencere + mini veranda.
- **Çiçekler:** tarhta 6 karışık; bahçede 2 küme × 5 çiçek, **3 tür**: papatya (6 basık beyaz taç küresi + sarı merkez), lale (kadeh silüetli oval, rastgele renk), lavanta (4 mor boncuk dikey başak). Hepsi sap + **hafif rüzgar salınımı** (±0.06 rad, ~1.9 sn periyot, rastgele faz).
- **Posta kutusu:** bark direk + metalik lacivert kutu + kırmızı bayrak. **Hortum:** 3 iç içe yeşil torus halkası, ev kenarında.
- **Bulutlar:** 4 billboard plane (yumuşak blob dokusu, 13–20 birim), y=24–30, 30 sn'de ±2.5 birim salınır.

---

## 13. Işık ve atmosfer

- **Güneş (directional):** euler `(-0.9, -0.6, 0)` — sol üstten, ~50° eğim. Renk `(1.0, 0.96, 0.88)` sıcak, yoğunluk 1000. **Gölgeler açık:** map 1024, radius 4 (yumuşak kenar), 8 örnek, gölge rengi siyah a=0.5.
- **Ambient:** `(0.55, 0.62, 0.70)` mavimsi, yoğunluk 420 (gölgeler simsiyah olmasın).
- **Gökyüzü:** dikey degrade — üst `(0.45, 0.70, 0.95)` → ufuk `(0.80, 0.90, 0.98)`. Aynı degrade **ortam yansıması** (environment/reflection) kaynağı olarak da kullanılır — metalik yüzeyler için şart.
- **Sis (fog):** 26 → 70 birim, renk `(0.80, 0.88, 0.95)`, üs 1.5 — DOF yerine derinlik hissi; komşu evler hafif siste.
- **SSAO:** kamerada, yoğunluk 0.7, yarıçap 0.6 (kalite anahtarıyla kapatılabilir).
- **Fake AO:** mower/karakter/objelerin altında radyal koyu daire dokusu (temas hissi, gerçek gölgeye ek).
- Tüm materyaller PBR (lambert değil): çim/toprak roughness ~0.95–1.0, boya 0.3, cam 0.1 + metalness 0.85–0.9.

---

## 14. Ses sistemi

Dosya bulunursa dosya, yoksa **runtime sentez** (Godot'ta AudioStreamGenerator ile aynısı yapılabilir ya da direkt gerçek ses koy):

- **Motor loop'u:** 85 Hz temel + 6 harmonik (1/k genlikli, saw benzeri) + %10 @ 13 Hz genlik modülasyonu ("pat-pat") + tanh saturasyon; tam 1 sn → dikişsiz loop. Çalarken: volume rölanti 0.28 ↔ hareket 0.45 lerp'i; pitch (rate) 0.82 ↔ 1.0 + dönüşte +0.12'ye kadar boost. Geçişler ~4/sn lerp.
- **Robot modu:** aynı loop, volume 0.08–0.13, rate 1.9 (+0.1 dönüş) → sessiz tiz vızıltı.
- **Biçme "şşşk":** 0.16 sn beyaz gürültü, tek kutuplu lowpass cutoff 2800→500 Hz süpürme, hızlı atak + üstel sönüş; 3 pitch varyantı (1.0/1.15/0.88); 3 player'lık havuzla üst üste binebilir. Volume 0.6.
- **Keşif çanı:** E6 (1318.5 Hz) + 0.12 sn sonra B6 (1975.5 Hz), üstel sönüş, 0.7 sn.
- **Ortam:** `ambient_birds_loop` dosyası varsa %18 volume loop (sentezlenmez).
- **Mute:** kalıcı tercih (UserDefaults karşılığı Godot'ta ConfigFile). **Arka plan:** uygulama pasifken ses motoru duraklar, dönünce sürer.
- Beklenen dosya adları: `mower_engine_loop` (2-4 sn dikişsiz), `grass_cut` (0.1-0.3 sn), `ambient_birds_loop` (10-30 sn).

## 15. Haptics (Godot'ta mobil titreşim karşılıkları)

- Hücre biçme: hafif darbe (yoğunluk 0.7), **frame başına en fazla 1**.
- Secret açığa çıkma: "warning" bildirimi. Secret toplama + %100 tamamlanma: "success".
- Mower değişimi / robot komutu: hafif darbe (0.4–0.5).

---

## 16. HUD / UI (SwiftUI → Godot Control karşılıkları)

- **Üst bar:** "%N biçildi" (animasyonlu sayı) + 🔍 bulunan/toplam secret + yeşil ilerleme kapsülü; sağda **mute butonu** (hoparlör ikonu).
- **Alt orta:** 3'lü **mower seçici** (emoji + ad; seçili olan yeşil vurgulu). Oyun sırasında değiştirilebilir; tamamlanınca gizlenir.
- **Sol alt:** sanal **joystick** — yalnız traktör seçiliyken görünür (yarı saydam).
- **Secret kartı:** ekran ortasında — emoji + ad + gizemli alt yazı; 2 sn sonra **sağ üstteki sayaca küçülerek uçar**. Metinler: 🔑 "Paslı Anahtar — It looks old. What does it open?" / 📻 "Eski Radyo — It still hums faintly."
- **LAWN COMPLETE ekranı:** büyük başlık (yay/pop animasyonu) + "N hücre biçildi · süre: X sn" + **koleksiyon slotları** (bulunan obje emoji+ad, bulunmayan "?") + eksik varsa sarı italik "**You missed something...**" + RESTART butonu.
- Ekran görselleri: sol üstten sıcak güneş gradient overlay'i (turuncu %10 → mor %8) + kenarlarda hafif **vignette** (radyal, %16 siyah).
- Dokunma çakışması: UI elemanları (seçici/joystick/mute) dokunuşu yutmalı; 3D sahne pan/tap'i almamalı.

---

## 17. Kritik sayılar özeti (GameConfig)

```
Grid: 16 × 24, hücre = 1 birim
Kamera: FOV 55, mid preset (back 5.0, height 4.2, lookAhead 2.2)
        pozisyon lerp 4.0/sn, yaw lerp 2.6/sn, kuşbakışı y=30, lerp 1.8/sn
Hareket: hızlanma 0.4 sn, yavaşlama 0.55 sn, geri vites 0.5x
Steering: smoothing 9.0/sn, hız-yarıçap faktörü 0.45
Robot: varış 0.35, dürtme 3.5 birim, swipe eşiği 60pt
Biçme animasyonu: 0.1 sn
Tuft: 7/hücre, 8 varyant, boy 0.30-0.66, sway genlik 0.06 hız 2.0
Parçacık: birthRate 90, boyut 0.045, ömür 0.6, spawn aralığı 0.12 sn
Secret: 2 adet, kenar payı 2, ayrım 8 hücre
Sürükleme eşiği: 8pt
Fog: 26-70; SSAO 0.7; gölge map 1024
```

---

## 18. Godot eşleme önerileri

| SceneKit'te | Godot'ta |
|---|---|
| SCNScene + render delegate döngüsü | Ana Node3D + `_physics_process(delta)` |
| Paylaşılan SCNGeometry (tuft/hücre) | **MultiMeshInstance3D** (8 MultiMesh) |
| Zemin multiply tint dokusu | Zemin ShaderMaterial + 16×24 ImageTexture (`set_pixel` + `update`) |
| Shader modifier (sway/dalga) | Vertex shader (`TIME` yerleşik) |
| SCNParticleSystem | GPUParticles3D (one-shot için `emitting=true` + timer) |
| lightingEnvironment + fog + SSAO | WorldEnvironment (Sky, Fog, SSAO yerleşik) |
| UIPanGesture / joystick / hit test | InputEvent + Control tabanlı joystick + `camera.project_ray` |
| @Observable GameState + SwiftUI HUD | Autoload singleton + sinyaller + Control HUD |
| AVAudioEngine sentez | AudioStreamGenerator veya gerçek ses dosyaları |
| Haptic'ler | `Input.vibrate_handheld()` (iOS/Android) |
| flattenedClone tuzağı | Godot'ta karşılığı yok — statik meshlerde otomatik batching/occlusion yeterli |

**Tuzak notları (yaşandı, tekrar etme):**
1. Parçacık sistemlerinde blend modunu açıkça ayarla (additive varsayılan → parlak dev bloblar olmuştu).
2. Chase kamera dönerken dokunma yönünü **ekran/kamera-göreli** hesapla, dünya-göreli değil.
3. Havuz gibi çok hücreli engelleri çarpışmada tek dikdörtgen yap — hücre hücre yapılırsa kenarda takırdar.
4. Secret'ları her restart'ta yeniden rastgele dağıt.
5. Şerit tint dokusunda satır ekseninin görsel eksenle eşleştiğini ilk çalıştırmada doğrula (y-flip kayması klasik hata).

---

## 19. Sprint geçmişi (ne, hangi sırayla inşa edildi)

1. **Sprint 1 (SpriteKit):** grid + otomatik ilerleyen mower + sürükle-yönlendir + biçme + HUD.
2. **Sprint 3:** tuft'lı çim, kamera takibi, bahçe dekoru, parçacık havuzu, ses sistemi (sentez fallback), mute + arka plan sesi düzeltmesi.
3. **Sprint 3.5:** ışık yönü tutarlılığı, yumuşak gölgeler, derinlik sıralaması, palet.
4. **3D geçişi (SceneKit):** kutu-hücreli low-poly, chase kamera, primitive çevre, secret orb temeli.
5. **Sprint 3D-2:** tek plane zemin + tint haritası, crossed-quad tuftlar, PBR + fog + SSAO + bulutlar, mahalle (yol/arabalar/komşular), detaylı mower, yaprak parçacıkları.
6. **Sprint 4:** tuft yoğunluğu, 3 mower tipi + seçici + joystick, robot boustrophedon, havuz, çevre detayları, secret sistemi (rastgele yerleşim, kazı, anahtar/radyo, kart, koleksiyon).
7. **Sprint 5A (son durum):** yön bazlı gerçek lawn striping (4 ton + yeniden şeritleme), otomatik hareketin kaldırılması (throttle + doğal yavaşlama + hıza bağlı dönüş yarıçapı), robot swipe dürtmesi, eklemli sürücü karakteri (yürüme/oturma animasyonları).

Swift kaynak kodu bu repo'da duruyor (`LastLawn/` + `Legacy2D/`) — algoritma detayı gerekirse
en faydalı dosyalar: `GameConfig.swift` (tüm değerler), `Lawn3DBuilder.swift` (model + striping),
`GameSceneKitView.swift` (kontroller + robot AI + kamera), `Character3D.swift` (animasyon formülleri).
