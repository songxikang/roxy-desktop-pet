# Generation notes

The artwork was generated with built-in image generation and assembled with
deterministic extraction, registration, and transparent sprite-sheet tooling.
Generation requires an image-generation environment; installation does not.

Use `assets/reference.png` as the canonical identity reference. Use the current
`assets/spritesheet.png` when editing an existing pet. The guides under
`layout-guides/` are spacing references only; visible guide marks must never be
copied into artwork.

- `base-pet.md`: canonical character brief.
- `rows/`: standard and look-row generation instructions.
- `look-cardinals.md`: up/right/down/left anchor generation.
- `refinement-prompts.json`: final changes to working and review states.
- `../docs/look-mechanics.md`: pet-specific gaze behavior.

Generate individual state strips and assemble the exact grid afterward. Do not
ask an image model to draw a complete final atlas. Keep one scale per row,
preserve actual jump height, and keep all unused cells transparent.
