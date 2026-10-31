# Sky data — sources, licences, how the table is built

Echoel Studio's sky view (founder 2026-10-28/31, plan `scratchpads/PLAN_INSTRUMENT_FIELD_2026-10-28.md`,
"Himmel und Natur als Quelle") draws the sky from a bundled catalogue plus arithmetic. Nothing is
downloaded at run time; nothing is taken from Sky Guide or any other app.

## Stars — `EchoelStudio/Core/Sources/EchoelCore/StarCatalogData.swift`

- **Source:** *The Bright Star Catalogue, 5th Revised Ed.* (Hoffleit D., Warren Jr. W. H., 1991),
  NASA NSSDC/ADC, distributed by the CDS as catalogue **V/50** (file `catalog`, byte layout in its
  `ReadMe`). The copy used for the build came from the Harvard TDC mirror
  (`http://tdc-www.harvard.edu/catalogs/bsc5.dat.gz`, the same 9 110 records).
- **Licence:** distributed by NASA ADC and CDS for free use with acknowledgement; it is a NASA data
  product and generally treated as public domain. Acknowledgement: this line and the file header.
  ⚠️ No lawyer has looked at it; the founder decides whether that is enough for the store build.
- **Selection:** every record with a J2000 position and V ≤ 5.5 → 2 887 stars (the 14 records
  removed from the catalogue have no position and drop out).
- **Fields kept:** HR number, RA and Dec J2000 in degrees (4 decimals), V, B−V (or `-`).
- **Names:** the IAU proper names (IAU Working Group on Star Names list) of 116 bright and
  well-known stars, matched by Bayer designation in the catalogue's own name field; where a
  designation has two catalogue components, the brighter one carries the name.
- **Not included:** constellation lines. The usual line sets come from GPL software (Stellarium);
  if lines come, they are defined in this repository from IAU star names.

## Sun, Moon, planets — `EchoelStudio/Core/Sources/EchoelCore/SkyBodies.swift`

- Algorithms: J. Meeus, *Astronomical Algorithms*, 2nd ed. (1998): ch. 12–13 (sidereal time,
  horizontal coordinates, `Sky.swift`), 21 (precession), 25 (Sun, low accuracy), 40 (parallax),
  41 (planet magnitudes), 47 (Moon, the largest terms of the ELP-2000/82 series as Meeus prints
  them). Algorithms and published coefficients, re-implemented; no code copied.
- Planet elements: E. M. Standish, JPL Solar System Dynamics, "Keplerian Elements for
  Approximate Positions of the Major Planets", table 1 (1800–2050) — a U.S. government work.
- Accuracy, measured against PyEphem 4.2.1 over 400 random dates 1950–2050 while building:
  Sun 0.009°, Moon 0.008° (geocentric), Mercury 0.02°, Venus 0.02°, Mars 0.04°, Jupiter 0.14°,
  Saturn 0.18°, Uranus 0.04°, Neptune 0.02°. The tests pin Meeus's worked examples, not PyEphem.

## Rebuilding the star table

```python
# python3 build.py bsc5.dat names.txt > lines.txt  (names.txt: "Alp CMa|Sirius" per line)
import sys
names = dict(l.rstrip("\n").split("|") for l in open(sys.argv[2]) if l.strip())
rows = []
for line in open(sys.argv[1], encoding="latin-1"):
    line = line.rstrip("\n").ljust(197)
    if not line[75:77].strip() or not line[102:107].strip():
        continue                                   # removed record: no position
    v = float(line[102:107])
    if v > 5.5:
        continue
    ra = (int(line[75:77]) + int(line[77:79]) / 60 + float(line[79:83]) / 3600) * 15
    dec = (-1 if line[83] == "-" else 1) * (int(line[84:86]) + int(line[86:88]) / 60 + int(line[88:90]) / 3600)
    bv = line[109:114].strip()
    rows.append([int(line[0:4]), ra, dec, v, float(bv) if bv else None, names.get(line[7:14])])
best = {}                                          # a name stays on the brighter component only
for row in rows:
    if row[5] and (row[5] not in best or row[3] < best[row[5]][3]):
        best[row[5]] = row
for row in rows:
    name = row[5] if row[5] and best[row[5]] is row else None
    bv = "-" if row[4] is None else f"{row[4]:.2f}"
    print(f"{row[0]} {row[1]:.4f} {row[2]:.4f} {row[3]:.2f} {bv}" + (f" {name}" if name else ""))
```
