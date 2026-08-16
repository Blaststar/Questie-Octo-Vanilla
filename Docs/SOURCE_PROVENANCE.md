# Questie-Octo source provenance and licensing audit

Audit date: 2026-08-15

## Purpose

This document records the source snapshots available during the GitHub/licensing
pass and preserves provenance for future human and AI-assisted maintenance.
This pass is documentation/licensing-only: no gameplay, Lua logic, TOC entry,
quest data, map behavior, tracker behavior, artwork, settings, or existing
project note was changed or removed.

The baseline addon archive audited here was:

- `Questie-Octo(1).zip`
- SHA-256: `3e0528012df2a0a36cd9185850ec71a330e5feb2abc87dc6b44e8f765e5f2fea`
- 139 regular files before licensing documents were added.

## Source snapshots available for this audit

| Source snapshot | SHA-256 | Role / note |
| --- | --- | --- |
| Questie 5.2.3 | `806a12d894a9d8568b73d86a95aeda79f29bebf90320a5f0007bec8db9803335` | Main historical UI/behavior target; no project-level Questie license found in supplied ZIP. |
| Questie 6.0.0 | `de997f793871b898f6a8f9f6494b79fcd55fc82f8e087b88a026a3dfc99550b9` | Architecture bridge and source of some reference assets/libraries; no project-level Questie license found in supplied ZIP. |
| Ace3v | `0482801133653d0e611e29335b22e77ad3de05a14ab8c35c163eb3f05eaaebeb` | Bundled/adapted Ace3 compatibility libraries. |
| pfQuest-classicAPI-octo | `484553544a30f4031273873c9673b779240339626455aa0e3c05f5c3df577dfb` | pfQuest-family data/runtime heritage and compatibility reference. |
| pfQuest-octo | `f4180ff88fbca25e7c673ab8fb5903c8a94807678b89ca70eefede0a8b3bd7c4` | Octo-specific pfQuest branch/reference. |
| ShaguTweaks | `3d772e41ea576a9b8e3d25017cb3cc2f93347d7ee4da4fa7bb69f2e403bcc007` | Vanilla UI/compatibility reference. |
| ShaguTweaks-extras | `2727f09cbbbdc08b2a06f424758363d0f206fef2ff0485449e03867a41a84357` | Additional Shagu compatibility/reference material. |
| MoveAnything | `452b9d7dc5c74d7f0c4a2f51954bfcaa0b20b951fbf742951a48390dd21cf7fd` | Compatibility/debugging reference; no general license file found in supplied snapshot. |
| Tortoise/Turtle server snapshot | `ed3b3638f26733d30993e0d2a1fac1e31a0738d5f66bd11a23c52509f7d47ee9` | Offline server-data provenance recorded by existing generated-data notes. |
| Calendar reference archive | `f4418d71aaf86fcc1067f3f02b7291aab6f3c37bb4d607a440127879270553a9` | Event/calendar verification material. |

The filenames used for upload can carry duplicate suffixes such as `(2)` or
`(3)`. The SHA-256 values above identify the actual snapshots independently of
those local upload names.

## Later compatibility reference snapshots

The following snapshots were supplied later in the same project and were used
only to cross-check UI compatibility behavior. They are not bundled with
Questie-Octo and this record does not change their licensing or ownership.

| Compatibility reference | SHA-256 | Role / note |
| --- | --- | --- |
| pfUI-classicAPI-octo | `5b4ed17b4ca94712ea7cc35cd86f31dfdc7b5d94a83bb51abb3cfca2e8e4911b` | Tooltip lifecycle, minimap shape, and Vanilla/ClassicAPI UI compatibility reference. |
| DragonflightUI-Reforged | `2c08e1ae203f54d7969262b65056d58d5e9e8c26f3b61f2c935ff0825525ac68` | Replacement ESC/GameMenu behavior and square-minimap compatibility reference. |

## Historical sources no longer available as exact archives

Existing Questie-Octo comments and README history establish that Questie 3.3.5,
7.0.0, and 8.0.0 were used during the earlier backport work. Those exact source
archives are no longer available in the current workspace, so they cannot be
re-hashed during this licensing pass.

Do not delete their references from source comments or documentation. Those
references are the remaining provenance record for the earlier work.

Later `Docs/ARCHITECTURE.md` records additional Questie generations as reference
material, including Questie 7-9, Questie 10-11, and Questie 11.34.1 as an
edge-case reference. Earlier README sections saying Questie 9/10/11 were not
used are historical stage-specific notes and intentionally remain intact.

## Exact-match audit observations

The baseline Questie-Octo archive contained many files that are byte-identical
to supplied source snapshots, especially under `Libs/` and `Data/`. Exact hash
matches are only one kind of provenance: adapted code, generated tables,
converted artwork, copied behavior, and compatibility patterns can remain
third-party-derived even when a whole-file hash no longer matches.

For this reason future audits must consult both hashes and the retained source
comments/documentation.

## License findings

### Questie-Octo original contributions

Original portions first authored for Questie-Octo are offered under the MIT
License. See `../LICENSE` and `../LICENSES/Questie-Octo-MIT.txt`.

### Ace3v

The supplied Ace3v snapshot includes the Ace3 Development Team license. Its
verbatim text is preserved at `../LICENSES/Ace3v-LICENSE.txt`.

### pfQuest / Shagu

The supplied pfQuest and Shagu snapshots contain MIT license files. Their exact
texts are preserved individually in `../LICENSES/` so their original copyright
years and notices are not collapsed into a generic replacement.

### Questie

No project-level Questie license file was found in the supplied Questie 5.2.3
or 6.0.0 snapshots. The `Questie/Libs/LICENSE.txt` file in those snapshots is
Ace3's license and is not treated as Questie's project license. Questie-derived
material is therefore excluded from the scope of the Questie-Octo MIT grant in
this repository notice.

### ClassicAPI

ClassicAPI.dll is an external dependency and is not bundled. Upstream states
GPL v3 or later. The upstream GPLv3 license document is included at
`../LICENSES/ClassicAPI-GPL-3.0.txt` for reference and compliance clarity.

## Packaging invariant

The GitHub/licensing package must preserve every pre-existing archive member's
uncompressed bytes. Licensing/provenance files are additions only. A future AI
or human contributor should not use a licensing cleanup as a reason to rewrite
source, change gameplay, strip comments, remove historical notes, or normalize
third-party files.
