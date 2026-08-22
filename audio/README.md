# audio/

Sprint brief: runtime ses sentezi yok. AudioDirector bu dört dosyayı burada arar,
bulamazsa konsola uyarı yazıp sessiz devam eder (hata vermez):

| Dosya | Kullanım |
| --- | --- |
| `mower_engine_loop.ogg` | Motor döngüsü — rölanti/hareket arası volume+pitch lerp'i (§14) |
| `grass_cut.ogg` | Biçme darbesi — pitch varyantlı, frame başına en fazla 1 |
| `discovery_chime.ogg` | Secret keşif jingle'ı |
| `ambient_birds_loop.ogg` | Ortam döngüsü |

Döngü dosyaları için Godot'un import ayarında **Loop** açık olmalı; AudioDirector
`AudioStreamOggVorbis.loop`'u yüklerken yine de zorlar.
