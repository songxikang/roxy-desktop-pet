# Generation notes

The artwork was generated with built-in image generation and assembled with
deterministic extraction, registration, and transparent sprite-sheet tooling.
Generation requires an image-generation environment; installation does not.

Use `assets/reference.png` as the approved pixel-art **belly-down,
chin-on-hands** reference. Keep its large rounded head, compact short body,
blue twin braids, cream-and-brown mage outfit, and tiny boots curled behind her.
The default anatomy is prone, not upright. Use the current
`assets/spritesheet.png` when editing an existing pet. The guides under
`layout-guides/` are spacing references only; visible guide marks must never be
copied into artwork.

- `base-pet.md`: canonical character brief.
- `rows/`: standard and look-row generation instructions, including the prone
  action requirements for each state.
- `look-cardinals.md`: up/right/down/left anchor generation.
- `refinement-prompts.json`: gesture refinement notes; apply the current prone
  anatomy and state-row instructions throughout.
- `../docs/look-mechanics.md`: pet-specific gaze behavior.

Generate individual state strips and assemble the exact grid afterward. Do not
ask an image model to draw a complete final atlas. Keep one scale per row,
preserve actual jump height, and keep all unused cells transparent.

Idle, waiting, working, waving, and review gestures keep her belly-down. Drag
movement uses a low prone glide with alternating hands and boots; jumping lifts
the whole prone body and returns to the same resting line. For look directions,
anchor the body, elbows, and boots while the head, face, eyes, hat, and braid
roots follow the gaze naturally. Do not rotate or flip a standing sprite to
imitate these poses.
