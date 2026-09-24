# Act 2 landmark paintings

Six original imagegen watercolor paintings, using
`assets/backdrop/act2_parallax/continuous_landscape.png` as the style reference.
The native generated PNGs are retained without cropping, repainting or stretching.
These are stylized architectural illustrations rather than documentary reconstructions.

- Level 3 — `shah_mosque.png`: Shah Mosque, Isfahan.
- Level 4 — `persepolis.png`: Persepolis, Gate of All Nations and surviving columns.
- Level 5 — `si_o_se_pol.png`: Si-o-se-pol bridge, Isfahan.
- Level 6 — `hafez.png`: Tomb of Hafez, Shiraz.
- Level 7 — `dowlat_abad.png`: Dowlat Abad Garden's windcatcher, Yazd.
- Level 8 — `cyrus.png`: Tomb of Cyrus, Pasargadae.

`LandmarkGallery.tscn` packages the textures and room mapping. Each painting
has a fixed, centered composition throughout its room: walking, jumping and
camera tracking never shift it. A plate-only shader lowers saturation and
contrast to separate the distant architecture from gameplay.

Camera position drives a dissolve across the full 320px room-to-room camera
travel, identically forward and backward. Source-over opacity is corrected so
the outgoing plate stays opaque behind the incoming plate: the old panorama
and sun cannot leak through at the midpoint. The first transition from the
original panorama into Level 3 still fades naturally. Render-time camera
synchronization prevents a one-frame tracking lag.

Watercolor filtering follows the existing panorama; gameplay still renders in
the nearest-filtered 320×180 world viewport. The gallery is non-solid and behind
all gameplay. Its opaque paintings cover the original sun sprite, avoiding a
sun disc drawn across a dome or tower. No second sun is created.

Level 8 is a short, hazard-free coda added to provide the sixth requested room.
It continues from Level 7 and holds the garden's final completion acknowledgement.
No signs or checkpoint flags are restored.

Architectural reference checks:
[Meidan Emam / Shah Mosque](https://whc.unesco.org/en/list/115),
[Persepolis](https://whc.unesco.org/en/list/114),
[The Persian Garden](https://whc.unesco.org/en/list/1372),
[Pasargadae](https://whc.unesco.org/en/list/1106).

Validation: `act2_landmark_test`, `act2_parallax_test`, `act2_routes_test`,
`act2_progression_test`, plus movement, checkpoint, carpet and save regressions.
Logs are in `output/act2_landmarks/`.
