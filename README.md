# siku_studio
In-game capture studio for FiveM. Create screenshots, GIFs and video clips of clothing, animations, vehicles and props using customizable backdrops, camera controls and automated capture workflows.

## Requirements

- `siku_core` 1.7.1 or newer, started before this resource.
- The permission `studio.use` on the role allowed to run captures.

## Commands

| Command | Effect |
| --- | --- |
| `/studio probe` | Builds the scene, takes one photo and saves it in `output/probe/`. |
| `/studio bench <variations\|readback\|encode\|upload\|save\|full\|all>` | Runs one benchmark, or all of them, and writes the results in `output/bench/`. |
| `/studio status` | Tells who is running a session and since when. |
| `/studio stop` | Stops the running session. Escape does the same in game. |

Every session, benchmark result and failure is sent to the Control Center under the `studio.*` events. Settings live in `config/studio.lua`.

## Transport

Captures leave the capture page through a NUI callback and reach the server in a latent net event (`transport.mode = 'event'`). NUI pages are served over https, so the browser refuses a plain http request to the FXServer port. The direct `POST` to the FXServer HTTP handler stays available with `transport.mode = 'http'` and an https reverse proxy configured in `http.endpoint`.
