import { salmonLogger } from 'salmonlogger'

export type AppForegroundListener = (foreground: boolean) => void

// Only UIAbility lifecycle callbacks update this state. NavDestination visibility
// and window focus can also change when an in-app/system modal covers the player.
export class AppForegroundState {
  private static foreground: boolean = false
  private static version: number = 0
  private static nextId: number = 0
  private static listeners: Map<number, AppForegroundListener> = new Map()

  static get isForeground(): boolean { return AppForegroundState.foreground }

  static subscribe(listener: AppForegroundListener): number {
    const id = ++AppForegroundState.nextId
    AppForegroundState.listeners.set(id, listener)
    return id
  }

  static unsubscribe(id: number): void {
    AppForegroundState.listeners.delete(id)
  }

  static setForeground(foreground: boolean): void {
    if (AppForegroundState.foreground === foreground) return
    AppForegroundState.foreground = foreground
    const version = ++AppForegroundState.version
    const subscriptions = Array.from(AppForegroundState.listeners.entries())
    for (const subscription of subscriptions) {
      if (version !== AppForegroundState.version) break
      if (AppForegroundState.listeners.get(subscription[0]) !== subscription[1]) continue
      try {
        subscription[1](foreground)
      } catch (_) {
        salmonLogger.addLog('AppForegroundState', '应用前后台监听执行失败', true)
      }
    }
  }

  static reset(): void {
    AppForegroundState.foreground = false
    AppForegroundState.version++
    AppForegroundState.listeners.clear()
  }
}
