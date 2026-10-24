# Test reels

The regression set (P1-17): `python -m scripts.regression` in `backend/` runs every row through
the server-side fetch and Extract and prints accuracy per section. Target: 20 links, 5 per
platform, mixed sections, at least 4 in Arabic. Expected section `none` means no section fits
(the save should go to review).

| # | Platform | URL | Language | Expected section | Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | Instagram | https://www.instagram.com/reel/De1aH9Po2ps/ | ar | tools | Plinth, Claude Code, Blender, UE5 |
| 2 | TikTok | https://vt.tiktok.com/ZSgmg8pkU/ | en | tools | VoiceStudio; also has claims |
| 3 | TikTok | https://vt.tiktok.com/ZSgm3sUEk/ | en | tools | hairline skill |
| 4 | TikTok | https://vt.tiktok.com/ZSgm3tAkB/ | ar | none | AirPods sale ad: products aren't a section yet |
| 5 | Instagram | https://www.instagram.com/reel/Dezc4qeimex/ | en | tools | brag skill |
| 6 | Instagram | https://www.instagram.com/reel/De1HVuyixUW/ | ar | places | Aroya cruise, Alexandria to Istanbul |
| 7 | Instagram | https://www.instagram.com/reel/Ddwj68hNLCA/ | en | places | Halawa café, teleport question |
