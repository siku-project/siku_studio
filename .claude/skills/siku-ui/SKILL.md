---
name: siku-ui
description: Construire ou modifier une interface NUI d'une ressource FiveM SIKU (Svelte 5, dossier web/) avec le design system officiel @siku/ui. À utiliser pour tout écran, HUD, menu, inventaire, banque, téléphone, notification ou composant d'interface SIKU.
---

# Interfaces SIKU avec @siku/ui

1. Lis `web/node_modules/@siku/ui/ai/SIKU.md` (règles), puis cherche le besoin dans `web/node_modules/@siku/ui/ai/components.md`. Les tokens sont dans `web/node_modules/@siku/ui/ai/tokens.md`.
2. Choisis la famille d'interface (écran plein, fenêtre, flottant, HUD, appareil) — section 3 de SIKU.md.
3. Compose avec les composants existants (`import { … } from '@siku/ui'`). Si un composant manque, compose à partir des existants et signale la proposition de variante ; ne recrée jamais un composant SIKU.
4. Styles : tokens seulement (`var(--…)`, preset Tailwind, styles `t-*`). Pas de couleur, police ni taille en dur. Pas de flou, `:has()`, `@container`, `color-mix()`, `dvh` (CEF = Chromium 103).
5. Clavier/manette : touches visibles, focus visible, rien d'indispensable au survol. Utilise `fetchNui` / `onNuiMessage` pour Lua.
6. Lance `bun run check` dans `web/` et corrige jusqu'à 0 erreur. Pour un rendu visuel, `bun run dev` puis vérifie à 1920×1080 et 1280×720 (densité compacte).
