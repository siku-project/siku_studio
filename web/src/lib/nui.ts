export const RESOURCE = 'siku_studio'

const resourceName: string =
  (
    (window as unknown as Record<string, unknown>).GetParentResourceName as
      (() => string) | undefined
  )?.() ?? RESOURCE

export const inGame: boolean =
  typeof (window as { invokeNative?: unknown }).invokeNative === 'function'

export function notify(name: string, data: Record<string, unknown> = {}): void {
  if (!inGame) {
    if (import.meta.env.DEV) {
      console.debug(`[NUI] ${name}`, data)
    }

    return
  }

  void fetch(`https://${resourceName}/${RESOURCE}:nui:event`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify({ name, ...data }),
  }).catch(() => {})
}
