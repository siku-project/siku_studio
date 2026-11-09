import axios from 'axios'
import type { AxiosInstance } from 'axios'

export const RESOURCE = 'siku_studio'

const resourceName: string =
  (
    (window as unknown as Record<string, unknown>).GetParentResourceName as
      (() => string) | undefined
  )?.() ?? RESOURCE

const nui: AxiosInstance = axios.create({
  baseURL: `https://${resourceName}`,
  timeout: 5000,
  headers: {
    'Content-Type': 'application/json',
  },
})

/** Whether the interface runs inside the game rather than in a browser tab. */
export const inGame: boolean =
  typeof (window as { invokeNative?: unknown }).invokeNative === 'function'

/**
 * Calls a NUI callback registered by the resource and returns its answer.
 * Resolves to null when the game is not there to answer, so the interface
 * keeps working in the browser.
 */
export async function sendNuiCallback<R = unknown, T = unknown>(
  event: string,
  data?: T,
): Promise<R | null> {
  if (!inGame) {
    if (import.meta.env.DEV) {
      console.debug(`[NUI] ${event}`, data ?? {})
    }
    return null
  }

  try {
    const response = await nui.post<R>(`${RESOURCE}:nui:${event}`, data ?? {})
    return response.data
  } catch (error) {
    if (import.meta.env.DEV) {
      console.warn(`[NUI] ${event} failed:`, (error as Error).message)
    }
    return null
  }
}

/** Fires a NUI callback without caring about the answer. */
export async function sendNuiEvent<T = unknown>(event: string, data?: T): Promise<boolean> {
  return (await sendNuiCallback(event, data)) !== null
}
