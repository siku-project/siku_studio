# siku_studio
In-game capture studio for FiveM. Create screenshots, GIFs and video clips of clothing, animations, vehicles and props using customizable backdrops, camera controls and automated capture workflows.

## Requirements

- `siku_core` 1.7.1 or newer, started before this resource.
- The permission `studio.use` on the role allowed to run captures.

## Commands

| Command | Effect |
| --- | --- |
| `/studio capture [target] [from] [to]` | Photographs everything the player's ped model offers, or one target (`component_11`, `prop_0`, `overlay_1`, `haircolor`, `eyecolor`...), optionally between two indexes, into `output/catalog/<model>/` with an `index.json`. Already photographed keys are skipped, so a stopped job resumes where it was. |
| `/studio probe` | Builds the scene, takes one photo and saves it in `output/probe/`. |
| `/studio bench <variations\|readback\|encode\|upload\|save\|full\|all>` | Runs one benchmark, or all of them, and writes the results in `output/bench/`. |
| `/studio status` | Tells who is running a session and since when. |
| `/studio stop` | Stops the running session. Escape does the same in game. |

Every session, benchmark result and failure is sent to the Control Center under the `studio.*` events. Settings live in `config/studio.lua`.

## Catalog

The targets, their camera framing and the frozen pose live in `config/studio.lua`. The subject is a clone of the player, so the catalog is made for the player's ped model, `mp_m_freemode_01` or `mp_f_freemode_01`. Each item is photographed on a green then a magenta background, and the two readings give an exact alpha: the WebP files are transparent, hair and glasses included.

## Transport

Captures leave the capture page through a NUI callback and reach the server in a latent net event (`transport.mode = 'event'`). NUI pages are served over https, so the browser refuses a plain http request to the FXServer port. The direct `POST` to the FXServer HTTP handler stays available with `transport.mode = 'http'` and an https reverse proxy configured in `http.endpoint`.
