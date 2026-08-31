# Cover art

Drop either or both in here; the main menu picks by screen shape and falls
back to `textures/intro/intro_1.jpg` when neither exists.

    cover_portrait.jpg    phones   (4:5 works, see the crop note below)
    cover_wide.jpg        desktop / Steam   (16:9)

`.png`, `.jpg`, `.jpeg` and `.webp` are all accepted.

## The crop

The cover is drawn to COVER the screen, so it is cropped, never letterboxed.
The phone viewport is 1170x2532 — an aspect of 0.46. A 4:5 image is 0.80, so
covering that screen scales it to the height and crops roughly two fifths of
its width, a fifth off each side. Keep the title and any faces inside the
middle three fifths, or export a taller crop as well.

## Import settings

Leave VRAM compression ON (`compress/mode=2`) — a full-screen cover is one of
the largest textures in the build and this is about four times smaller than
lossless. Turn mipmaps OFF (`mipmaps/generate=false`): the image is drawn at
roughly 1:1 and never minified, so they are a third more memory for nothing.
