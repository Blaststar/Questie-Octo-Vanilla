# Questie-Octo third-party notices

This file records third-party material and development references known to the
Questie-Octo project. It is intentionally additive: existing source comments,
README history, architecture notes, and audit notes remain authoritative
provenance evidence and should not be removed merely because this summary
exists.

## Ace3 / Ace3v

Questie-Octo bundles and adapts Ace3-family compatibility code under `Libs/`,
including AceCore, AceGUI, AceConfig-related code, and CallbackHandler-related
code. The supplied Ace3v source snapshot carries the Ace3 Development Team
license reproduced verbatim in `LICENSES/Ace3v-LICENSE.txt`.

That license permits source and binary redistribution with conditions and also
contains an explicit restriction on redistribution of a stand-alone Ace3
version without prior written authorization. Questie-Octo distributes these
libraries as embedded addon components, not as a stand-alone Ace3 package.

## LibStub

`Libs/LibStub/LibStub.lua` states that LibStub is placed in the Public Domain.
The embedded notice remains in that source file and is summarized in
`LICENSES/LibStub-PUBLIC-DOMAIN.txt`.

## pfQuest and pfQuest-octo

Questie-Octo uses pfQuest-family source/data/artwork as documented throughout
the project. The supplied source snapshots are licensed under the MIT License:

- `pfQuest-classicAPI-octo`: Copyright (c) 2017-2021 Eric Mauser (Shagu).
- `pfQuest-octo`: Copyright (c) 2021 Eric Mauser (Shagu).

Their exact supplied license texts are preserved in:

- `LICENSES/pfQuest-classicAPI-MIT.txt`
- `LICENSES/pfQuest-octo-MIT.txt`

These notices apply to the relevant pfQuest-derived portions and do not alter
Questie-Octo gameplay behavior.

## ShaguTweaks and ShaguTweaks-extras

ShaguTweaks was used as a Vanilla 1.12 UI/compatibility reference, as recorded
in the existing README and source comments. Supplied source licenses are MIT:

- `ShaguTweaks`: Copyright (c) 2021 Eric Mauser (Shagu).
- `ShaguTweaks-extras`: Copyright (c) 2025 Eric Mauser (Shagu).

Their exact supplied license texts are preserved in:

- `LICENSES/ShaguTweaks-MIT.txt`
- `LICENSES/ShaguTweaks-extras-MIT.txt`

## Questie

Questie is a major implementation, behavior, UI, compatibility, and artwork
reference for Questie-Octo. The preserved project history records work across
multiple Questie generations. Earlier README sections intentionally record the
then-approved chain `5.2.3 -> 6.0.0 -> 3.3.5 -> 7.0.0 -> 8.0.0` and statements
that later versions had not yet been inspected. The later architecture record
then documents subsequent reference use of Questie 7-9, Questie 10-11, and
Questie 11.34.1 for edge cases. Both layers are retained because they describe
different stages of development.

During the licensing audit, the supplied Questie 5.2.3 and Questie 6.0.0
archives contained no project-level Questie license file. Their
`Questie/Libs/LICENSE.txt` is the Ace3 Development Team license for bundled
libraries and must not be represented as a license for Questie itself.

Accordingly, Questie-derived portions are **not** relicensed by the
Questie-Octo MIT grant. They retain whatever rights and restrictions apply to
their upstream source. This repository makes no additional permission claim
for those portions.

The exact historical Questie 3.3.5, 7.0.0, and 8.0.0 archives originally used
are no longer available in the current project workspace. Their provenance is
nevertheless retained in existing Questie-Octo comments and documentation and
should not be erased by future human or AI-assisted changes.

## ClassicAPI.dll

ClassicAPI is an external runtime dependency used by Questie-Octo. The DLL is
not bundled in this Questie-Octo package.

The ClassicAPI upstream repository states that ClassicAPI is licensed under
GNU GPL version 3 or later. A copy of the upstream GPLv3 license document is
included for reference at `LICENSES/ClassicAPI-GPL-3.0.txt`.

Including that license text does not relicense Questie-Octo under the GPL and
does not imply that ClassicAPI.dll is distributed inside this addon archive.
Users obtain ClassicAPI separately from its upstream project.

## MoveAnything

The supplied MoveAnything source was used as a compatibility/debugging
reference during development. No general project license file was found in the
supplied MoveAnything archive during this audit, and no byte-identical current
Questie-Octo file was identified as an imported MoveAnything file. It is
therefore recorded as reference provenance rather than as a bundled licensed
component.

## Turtle/Tortoise and calendar-derived data

Existing Questie-Octo files explicitly document Turtle/Tortoise server data and
calendar material used to build or verify offline quest/event data. Those
existing generated-data headers and architecture notes are preserved. This
licensing-only packaging pass does not alter, regenerate, remove, or reinterpret
that gameplay data.

## Preservation rule for future contributors and AI tools

Do not remove historical comments, audit notes, source-attribution notes,
generated-data headers, migration explanations, compatibility explanations, or
AI-oriented maintenance notes merely because newer documentation summarizes
them. They are part of the source-provenance trail.

When replacing or substantially rewriting a third-party-derived component,
update the provenance record rather than deleting the earlier history.
