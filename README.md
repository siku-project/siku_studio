# siku_studio
In-game capture studio for FiveM. Create screenshots, GIFs and video clips of clothing, animations, vehicles and props using customizable backdrops, camera controls and automated capture workflows.

## Requirements

- `siku_core` 1.7.1 or newer, started before this resource.
- The permission `studio.use` on the role allowed to run captures.

## Commands

| Command | Effect |
| --- | --- |
| `/studio capture [target] [from] [to]` | Photographs everything both catalog models offer, `mp_m_freemode_01` then `mp_f_freemode_01`, a named set of targets from `catalog.sets` (`multicharacter`: what the character creator shows), or one target by its name (`hair`, `top`, `pants`, `hat`, `beard`... the `name` of each target in `catalog.targets`; its `id` such as `component_11` works too), optionally between two indexes. Colours (hair, eyes, overlays) are never photographed: shapes come out in the base colour and the interfaces show colours as swatches. Photos go to the CDN (see below), or into `output/catalog/<male|female>/` with one `<target name>.index.json` per target when no key is set; on disk, already photographed keys are skipped so a stopped job resumes where it was. An item that never finishes loading (`catalog.changeTimeoutMs`) is logged as `studio.photo_skipped` and left out, the capture goes on; the session only gives up after `catalog.failuresInARow` failures one after the other. |
| `/studio setup` | Opens the framing tool: the subject is dressed for one target, the camera moves on three axes without turning (arrows, Page Up / Page Down, zoom with the numpad or the wheel), parts of the body can be hidden, and « Générer la configuration » prints the lines to paste in `config/studio.lua` in the F8 console, the server console and the logs. |
| `/studio probe` | Builds the scene, takes one photo and saves it in `output/probe/` (or `probe/` on the CDN), with the two raw readings next to it (`<key>_green.webp`, `<key>_magenta.webp`) when the double matte is on, to judge the cut on real pictures. |
| `/studio bench <variations\|readback\|encode\|upload\|save\|full\|all>` | Runs one benchmark, or all of them, and writes the results in `output/bench/`. |
| `/studio status` | Tells who is running a session and since when. |
| `/studio stop` | Stops the running session. Escape does the same in game. |

Every session, benchmark result and failure is sent to the Control Center under the `studio.*` events. Settings live in `config/studio.lua`.

## Catalog

### Framing

`/studio setup` is the way to adjust how a target is photographed. Pick the model (male or female), pick the target, pick an item to look at, move the camera until the framing is right, turn the subject on itself for what sits on its back, hide the parts of the body that get in the way (they are hidden again during the capture of that target), then generate the configuration: a line for the `camera.models.<model>` block in the `anchor` form and the `catalog.targets` line to replace. Paste both in `config/studio.lua` and restart the resource. Each model has its own framings; the targets and their hidden parts are shared.


The targets, their camera framing and the frozen pose live in `config/studio.lua`. The subject is a clone of the player when they wear the model being photographed, so their own look is the base; for the other model a bare ped is created with a neutral face. Each item is photographed on a green then a magenta background, and the two readings give an exact alpha: the WebP files are transparent, hair and glasses included. The two backgrounds share the same luminance so the exposure and the glow of the game react alike to both, the page waits for the picture to stop changing before each reading, and the colour of every pixel is unmixed from both readings, so what the game adds around the subject ends up as a neutral shade rather than a green or magenta tint.

## CDN

Every photo goes to the Siku CDN: `cdn.url` in `config/studio.lua` names it, `cdn.folder` the folder under which everything is filed (`''` for the root), and the API key comes from the convar `siku_studio_cdn_key` set in `server.cfg` (`set siku_studio_cdn_key "cdn_…"`, a key with the write permission there). Each target gets its own folder named after what it is (`hair`, `top`, `pants`, `shoes`, `hat`, `glasses`, `beard`, `eyebrows`… the `name` of each target in `catalog.targets`) with one folder per model inside, `male` or `female` (`catalog.folders`), so the photos of the male hairstyles are in `hair/male/`. Folders are created on the first photo, so the CDN setting that creates missing folders must be on. Photos are named after what they show: `top_12_0.webp` is the top drawable 12 with texture 0; `hat_5_1.webp` the hat drawable 5 with texture 1; `beard_7.webp` the beard shape 7. Each session replaces the photos of the previous one, and every folder carries an `index.json` mapping each photo to its CDN link. Without a key the photos stay on disk under `output/`, as before. Bench files always stay on disk.

## Interface

The NUI lives in `web/` (Svelte 5, Vite, `@siku/ui`, Paraglide) and is built into `web/dist/`, the folder the manifest serves. `cd web && bun install && bun run build` before starting the resource from a clone; the release archive ships the build. `bun run dev` opens the dev boilerplate in a browser with mock data, `bun run check` runs locales, format, types and lints, `bun run test:unit` the tests. The interface strings live in the `web` block of `translations/<language>.lua`, the only place a string is written: `bun run locales` derives the Paraglide messages from them. The capture page that reads the game view is part of the same bundle.

## Transport

Captures leave the capture page through a NUI callback and reach the server in a latent net event (`transport.mode = 'event'`). NUI pages are served over https, so the browser refuses a plain http request to the FXServer port. The direct `POST` to the FXServer HTTP handler stays available with `transport.mode = 'http'` and an https reverse proxy configured in `http.endpoint`.
