# İlk beş dakika — metin ve akış denetimi (G36, 2026-09-07)

Ölçüm yöntemi: sıfır kayıtla akış `root.gd` üzerinden izlendi, her kart ve
diyalog satırı `strings.csv`'den kelime sayısıyla döküldü, prolog yolunun
hücre sayısı ve yönlendirme bayrağı headless bir probe ile okundu.

## Akış (sıfır kayıt)

| Adım | Dokunuş | Kelime (TR) | Süre tahmini |
|---|---|---|---|
| Menü → Başla | 1 | — | 3 sn |
| prologue.cards (4 kart) | 4 | 59 | 20 sn okuma |
| Yol (ch00): 9×34, **250 biçilebilir hücre**, tamamı biçilmeli | — | — | itmeli 3 hücre/sn → ≥ 83 sn saf, pratikte 2–3 dk; traktörle ~1 dk |
| pro_road diyaloğu (6 satır + onay) | 7 | 34 | 15 sn |
| prologue.after (3 kart) | 3 | 44 | 15 sn |
| intro.after_prologue (2 kart) | 2 | 30 | 10 sn |
| brief_ch01 (3 satır, seçim, cevap, satır, onay) | 7 | ~48 | 20 sn |
| ch01 başlar | — | — | — |

Toplam: ilk gerçek bahçeye kadar **25 dokunuş, ~215 kelime, 4–6 dakika**.
Yol bittikten ch01 başlayana kadar oyun olmadan **19 dokunuş, ~156 kelime,
~60–70 sn**: ilk beş dakikanın en uzun oyunsuz koridoru.

## Bulgular (öncelik sırasıyla)

1. **Yönlendirme bayrağı yolda yanıyor.** `Game._begin_search` her ilk
   seviyede `_first_run = GameState.is_first_run()` diyor ve 4 sn sonra
   `mark_orientation_done` çağrılıyor. Sıfır kayıtta ilk seviye prolog
   yolu; probe: yolda 5 sn sonra `is_first_run=false`. Sonuç: ch01 —
   asıl ilk bahçe — ilk-koşu ipuçlarını (iki gömünün etrafına renk,
   %8/%45'te erken koku satırı) hiç almıyor. Ayrıca `Hud.show_orientation`
   (NEDEN BURADASIN / FIRST_L1–3 / ARAMAYA BAŞLA) **hiçbir yerden
   çağrılmıyor**: ölü kod, ölü metin. Karar: ya sayfayı ch01'de 4. saniyede
   gerçekten göster, ya da sil. Her durumda `is_road()` iken bayrağa
   dokunulmasın.
2. **Yolun görevi ile bitiş koşulu uyuşmuyor.** Açılış: "Yeşil tarlaya kadar
   önünü biçerek ilerle." Bitiş: 250 hücrenin hepsi. Oyuncu ışığa doğru bir
   şerit açıp durur, seviye bitmez. Öneri: yol, son iki sıradan herhangi
   bir hücre kesildiğinde bitsin ("çite vardı"); veya metin "Yolu temizle"
   olsun. İlki prologa yakışır ve süreyi ~40 sn'ye indirir.
3. **19 dokunuşluk metin koridoru.** Yol bitince arka arkaya: diyalog (7),
   iki kart seti (5), brifing (7). Öneri: `intro.after_prologue` ikinci kart
   ("EVE DÖNMEDİ", 21 kelime) ile brifingin ilk iki satırı aynı bilgiyi
   veriyor; kartı bir satıra indir ve brifingi 3 satır + onaya kısalt (seçim
   kalabilir ama tek cevap satırı). Hedef ≤ 12 dokunuş, ≤ 100 kelime.
4. **Aynı bilgi dört kez.** "Ellie… bu sabahtan beri" — after_prologue
   kartı, brifing cevabı (R2), FIRST_L1, KAYIP posteri. Poster taşısın;
   diğer üçünden ikisi gitsin.
5. **Bakış açısı menteşesi zayıf.** Prolog birinci tekil Şerif ("Kızımı",
   "yürüyordum"); oyuncu yolu Şerif olarak yürüyor. Sonra tek cümle "seni
   çağırdım" ile oyuncu başka biri (dedektif) oluyor ve ch01'de Şerif
   telsizden "sana" konuşuyor. Menteşe kartını netleştir: "Dokuz yıl sonra,
   Ellie kaybolduğunda, seni çağırdım. Ben kasabayı tutarım; sen bakarsın."
   Böylece "o" zamiri de çözülür (Ellie'nin adı bir kart sonra geliyordu).
6. **"Sonra… Sonra"**: prologue.after[2] "Dokuz yıl sonra…" ile
   intro.after_prologue[0] "Sonra, dokuzuncu doğum gününün sabahı —" peş
   peşe. Birini değiştir. "Dokuz yıl / dokuzuncu doğum günü" yankısı iyi,
   bilinçliyse kalsın.
7. **Türkçe düzeltmeler.** "Bir çit vardı, ve birinin…" → "ve"den önce
   virgül yok. "Neden çim?" → "Neden biçiyoruz?". 19–21 kelimelik iki kart
   satırı (intro.cards[4], after_prologue[1]) ikiye bölünsün; duygusal
   zirvede en uzun cümle olmamalı.
8. **Yolda makine seçici.** Deneme modu üç makineyi de gösteriyor
   (İtmeli/Traktör/Robot) — oyunun 30. saniyesinde, makinelerin ne olduğu
   söylenmeden. Traktörü hissettirmek amaç; Robot yolda gizlenebilir.

## Sorunsuz bulunanlar

Menü tek dokunuş; kartların "devam etmek için dokun" ipucu; ch01 açılış
başlığı (SON BİÇİM: 847 GÜN ÖNCE) ve sürüş ipucu; brifingde seçim; KAYIP
posteri; koku satırlarının bölge adı vermesi; ilk toplama ipuçları (hurda,
yiyecek) tek seferlik ve kısa.

## Uygulama (aynı gün, G36.1)

A–E uygulandı: bayrak yolda yanmıyor ve yönlendirme sayfası ch01'in 4. saniyesinde gerçekten çıkıyor (3 satır, ARAMAYA BAŞLA); yol son iki sıraya varınca bitiyor ve ilerleme çubuğu şeridin ne kadar ilerlediğini gösteriyor; yol sonrası koridor 19 → 15 dokunuş (pro_road 5 satır, after_prologue tek kart, brifing 2 satır + seçim + onay); menteşe kartı Ellie'yi adıyla söylüyor ve rolü veriyor; virgül, "Neden biçiyoruz?", kısaltılan iki uzun satır; robot yolda gizli. `OpeningCheck` (20 iddia, headless) hepsini ölçüyor.

## Uygulama planı (özgün)

A. `is_road()` iken ilk-koşu bayrağına dokunma; yönlendirme sayfasını ch01'de
   göster veya kaldır (karar: sayfa kalsın, 3 satır; ARAMAYA BAŞLA).
B. Yol bitişi: son iki sıra kuralı + `PRO_ROAD_TASK` aynı kalır.
C. Koridor: after_prologue tek kart; brifing 3+seçim+onay; menteşe kartı.
D. Metin düzeltmeleri (madde 6–7); Robot yolda gizli.
E. `FlowCheck`'e "yolda bayrak yanmaz", "ch01'de ipucu tonu var", "yol son
   sıraya varınca biter" iddiaları; `TextCheck`'e kart satırı ≤ 16 kelime.
