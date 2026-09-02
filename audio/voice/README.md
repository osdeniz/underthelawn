# Voice lines

One file per translation key, named exactly for the key:

    audio/voice/DLG_BRIEF_CH01_1.ogg
    audio/voice/DLG_TOWN_SARAH_0C.ogg

A localised recording overrides the shared one:

    audio/voice/tr/DLG_BRIEF_CH01_1.ogg
    audio/voice/en/DLG_BRIEF_CH01_1.ogg

`.ogg`, `.wav` and `.mp3` are all accepted, in that order of preference.

Nothing is generated here. A missing file is silence, not a warning — the game
plays exactly as it does today until real recordings are dropped in, and no
code has to change when they are. The dialogue box asks for the line's key as
it prints it, and cuts the audio short if the player taps through.

Keys live in `i18n/strings.csv`; every spoken line in `data/dialogue.json`
carries one.
