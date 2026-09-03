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


## G16.1 — the world's sounds

Fourteen more placeholders from `tools/gen_audio.py`, same convention: put a
`.ogg` of the same base name beside the `.wav` and it wins.

- `rain_loop`, `crickets_loop`, `lamp_hum_loop`, `bed_day`, `bed_evening` — LOOPS;
  the director forces loop mode on them, so a recording need not carry loop metadata,
  but should be cut to loop cleanly.
- `wind_gust`, `footstep_grass_a`, `footstep_grass_b`, `footstep_dirt`, `dog_huff`,
  `rabbit_rustle`, `bird_takeoff`, `settler_card`, `food_pickup` — one-shots, played
  through a three-voice round-robin pool with slight random pitch on the natural ones.

Recording notes: the beds sit at -14 dB under the engine and should have no melody
line — anything hummable becomes unbearable by the fourth yard. Footsteps are short
(under 250 ms); the director spaces them by distance walked, not by a timer.
