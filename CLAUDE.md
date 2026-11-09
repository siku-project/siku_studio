# CLAUDE.md

<!-- siku:begin -->
<!-- Généré par « bunx siku ai sync » (@siku/ui 1.19.0). Ne pas modifier entre les marqueurs. -->
## Design system SIKU (@siku/ui 1.19.0) — obligatoire pour toute interface

Cette ressource utilise le design system officiel SIKU. Avant de créer ou modifier une interface (dossier `web/`) :

1. Lire `web/node_modules/@siku/ui/ai/SIKU.md` (règles, architecture, interdits), puis `ai/components.md` (composants, props, exemples) et `ai/tokens.md` (tokens).
2. **Réutiliser** les composants de `@siku/ui` (`import { Button, SlotGrid } from '@siku/ui'`). Ne jamais recréer un composant qui existe ; si une variante manque, la proposer (voir « Faire évoluer » dans SIKU.md) au lieu de la coder localement.
3. Styles : uniquement des tokens (`var(--bg-base)`, classes Tailwind du preset SIKU, styles `t-*`). Aucune couleur, police ou taille de texte codée en dur.
4. Cible : CEF FiveM (Chromium 103). Aucun `backdrop-filter`/flou, pas de `:has()`, `@container`, `color-mix()`, `dvh`.
5. Après chaque modification d’interface : `bun run check` dans `web/` (lance `siku check` + `siku doctor`) doit passer.

@web/node_modules/@siku/ui/ai/SIKU.md
<!-- siku:end -->
