-- SIKU — pont entre le jeu et l'interface @siku/ui (à garder tel quel dans chaque ressource).
-- 1. Environnement : zone sûre GTA, mini-carte, échelle choisie par le joueur  → message 'siku:env'
-- 2. Manette : lit les contrôles pendant que l'interface a le focus           → message 'siku:nav'

SikuUI = {}

local function minimapRect()
  -- Position de la mini-carte native en fractions d'écran (formule standard, dépend de la zone sûre et du ratio).
  local safe = GetSafeZoneSize()
  local sx, sy = 1.0 / 20.0, 1.0 / 20.0
  local resX, resY = GetActiveScreenResolution()
  local aspect = GetAspectRatio(false)
  local w = sx * 3.6 * (1.778 / aspect) -- largeur relative 16:9 ramenée au ratio réel
  local h = sy * 5.8
  local x = (1.0 - safe) * 0.5 + 0.01
  local y = 1.0 - (1.0 - safe) * 0.5 - h - 0.01
  return { x = x, y = y, w = w, h = h }
end

function SikuUI.sendEnv()
  SendNUIMessage({ type = 'siku:env', data = {
    safeZone = GetSafeZoneSize(),
    minimap = minimapRect(),
    uiScale = GetResourceKvpFloat('siku:uiScale') ~= 0.0 and GetResourceKvpFloat('siku:uiScale') or 1.0,
  } })
end

-- Ouvre/ferme l'interface et gère le focus NUI.
function SikuUI.open(payload)
  SetNuiFocus(true, true)
  SikuUI.sendEnv()
  SendNUIMessage({ type = 'open', data = payload or {} })
  SikuUI.focused = true
end

function SikuUI.close()
  SetNuiFocus(false, false)
  SendNUIMessage({ type = 'close' })
  SikuUI.focused = false
end

RegisterNUICallback('close', function(_, cb) SikuUI.close(); cb({ ok = true }) end)

-- Manette → événements clavier dans l'interface (les composants @siku/ui gèrent le clavier).
local NAV = {
  { 172, 'up' }, { 173, 'down' }, { 174, 'left' }, { 175, 'right' },   -- croix directionnelle
  { 191, 'confirm' }, { 194, 'back' },                                  -- A / B
  { 205, 'prev' }, { 206, 'next' },                                     -- LB / RB
  { 204, 'option' },                                                    -- Y
}
CreateThread(function()
  while true do
    if SikuUI.focused and not IsUsingKeyboard(0) then
      for _, c in ipairs(NAV) do
        if IsDisabledControlJustPressed(0, c[1]) then SendNUIMessage({ type = 'siku:nav', data = { key = c[2] } }) end
      end
      Wait(0)
    else
      Wait(250)
    end
  end
end)

-- Renvoie l'environnement si la résolution change (alt-tab, réglages).
CreateThread(function()
  local last = ''
  while true do
    local x, y = GetActiveScreenResolution()
    local key = x .. 'x' .. y .. ':' .. GetSafeZoneSize()
    if key ~= last then last = key; SikuUI.sendEnv() end
    Wait(2000)
  end
end)
