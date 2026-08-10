# App Icon — Liquid Glass source

Layers imported into Icon Composer to produce `TheRecruitingCompass/TheRecruitingCompass/AppIcon.icon`.

- `background.png` — full-bleed green gradient (no rounding/shadow; OS masks). Bottom layer, glass off.
- `fg-white.png` — field marks + center ring. Middle layer, specular + shadow.
- `fg-gold.png` — compass arrow + center pivot. Top layer, specular + higher shadow for depth.
- `preview-3layer.png` — flat composite reference.

Derived from the legacy 1024 PNG by chroma-keying the green (foreground) and rebuilding the gradient (background). To edit: reopen `AppIcon.icon` in Icon Composer (ships with Xcode 26).
