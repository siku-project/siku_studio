# siku_studio
In-game capture studio for FiveM. Create screenshots, GIFs and video clips of clothing, animations, vehicles and props using customizable backdrops, camera controls and automated capture workflows.

## Requirements

- `siku_core` 1.7.1 or newer, started before this resource.
- The permission `studio.use` on the role allowed to run captures.

## Commands

| Command | Effect |
| --- | --- |
| `/studio capture [target] [from] [to]` | Photographs everything the player's ped model offers, or one target (`component_11`, `prop_0`, `overlay_1`, `haircolor`, `eyecolor`...), optionally between two indexes, into `output/catalog/<model>/` with an `index.json`. Already photographed keys are skipped, so a stopped job resumes where it was. |
| `/studio setup` | Opens the framing tool: the subject is dressed for one target, the camera moves on three axes without turning (arrows, Page Up / Page Down, zoom with the numpad or the wheel), parts of the body can be hidden, and « Générer la configuration » prints the lines to paste in `config/studio.lua` in the F8 console, the server console and the logs. |
| `/studio probe` | Builds the scene, takes one photo and saves it in `output/probe/`. |
| `/studio bench <variations\|readback\|encode\|upload\|save\|full\|all>` | Runs one benchmark, or all of them, and writes the results in `output/bench/`. |
| `/studio status` | Tells who is running a session and since when. |
| `/studio stop` | Stops the running session. Escape does the same in game. |

Every session, benchmark result and failure is sent to the Control Center under the `studio.*` events. Settings live in `config/studio.lua`.

## Catalog

### Framing

`/studio setup` is the way to adjust how a target is photographed. Pick the target, pick an item to look at, move the camera until the framing is right, hide the parts of the body that get in the way (they are hidden again during the capture of that target), then generate the configuration: a `camera.presets` line in the `anchor` form and the `catalog.targets` line to replace. Paste both in `config/studio.lua` and restart the resource.


The targets, their camera framing and the frozen pose live in `config/studio.lua`. The subject is a clone of the player, so the catalog is made for the player's ped model, `mp_m_freemode_01` or `mp_f_freemode_01`. Each item is photographed on a green then a magenta background, and the two readings give an exact alpha: the WebP files are transparent, hair and glasses included.

## CDN

Every photo goes to the Siku CDN: `cdn.url` and `cdn.folder` in `config/studio.lua` name the destination, and the API key comes from the convar `siku_studio_cdn_key` set in `server.cfg` (`set siku_studio_cdn_key "cdn_…"`, a key with the write permission on that folder). Photos are named `1.webp`, `2.webp`… in the order they are taken and each session replaces the photos of the previous one; the catalog index is sent next to them as `<model>.index.json` and maps every number to its item. Without a key the photos stay on disk under `output/`, as before. Bench files always stay on disk.

## Interface

The NUI lives in `web/` (Svelte 5, Vite, `@siku/ui`, Paraglide) and is built into `web/dist/`, the folder the manifest serves. `cd web && bun install && bun run build` before starting the resource from a clone; the release archive ships the build. `bun run dev` opens the dev boilerplate in a browser with mock data, `bun run check` runs locales, format, types and lints, `bun run test:unit` the tests. The interface strings live in the `web` block of `translations/<language>.lua`, the only place a string is written: `bun run locales` derives the Paraglide messages from them. The capture page that reads the game view is part of the same bundle.

## Transport

Captures leave the capture page through a NUI callback and reach the server in a latent net event (`transport.mode = 'event'`). NUI pages are served over https, so the browser refuses a plain http request to the FXServer port. The direct `POST` to the FXServer HTTP handler stays available with `transport.mode = 'http'` and an https reverse proxy configured in `http.endpoint`.
