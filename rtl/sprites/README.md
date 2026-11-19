# Sprite ROMs

The checked-in 20×20 character PNGs and 16×16 grass tile are converted to synchronous
12-bit RGB ROMs by `tools/ee354_optimized_sprite_script.py`. Alpha pixels become
`12'h000` (transparent); visible black is raised to `12'h111`.

Example:

```bash
python3 tools/ee354_optimized_sprite_script.py source.png \
  --output-dir rtl/sprites/png --size 20
```

The resized PNG is written to `rtl/sprites/png`, and `<name>_rom.v` is written to
`rtl/sprites`. Build and simulation scripts include these ROMs automatically.

## Character image sources

These images are for this non-commercial course project and retain their respective
owners' rights.

- Giant: PNGitem, `https://www.pngitem.com/middle/iJxwRR_clash-royale-giant-png-ice-wizard-clash-royale/`
- Ice Golem: KindPNG, `https://www.kindpng.com/imgv/iiJJoxx_ice-golem-png-transparent-png/`
- Knight: StickPNG, `https://www.stickpng.com/img/games/clash-royale/clash-royale-knight`
- Mini P.E.K.K.A: myEmotes, `https://myemotes.io/stickers/mini_pekka`

The grass tile was generated locally as a small deterministic texture to avoid the
block-RAM cost of a full 480×360 arena image.
