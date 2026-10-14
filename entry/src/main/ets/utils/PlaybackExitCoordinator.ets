// 退场后的恢复方向、保存和释放完成前，首页只记录尺寸，不重建列表。
export default class PlaybackExitCoordinator {
  private static sequence: number = 0
  private static exits: Set<number> = new Set()
  private static waiters: Array<() => void> = []

  static beginExit(): number {
    const token = ++PlaybackExitCoordinator.sequence
    PlaybackExitCoordinator.exits.add(token)
    return token
  }

  static get isExiting(): boolean {
    return PlaybackExitCoordinator.exits.size > 0
  }

  static waitForExit(): Promise<void> {
    if (!PlaybackExitCoordinator.isExiting) return Promise.resolve()
    return new Promise<void>(resolve => PlaybackExitCoordinator.waiters.push(resolve))
  }

  static finishExit(token: number): void {
    if (!PlaybackExitCoordinator.exits.delete(token) || PlaybackExitCoordinator.isExiting) return
    const waiters = PlaybackExitCoordinator.waiters
    PlaybackExitCoordinator.waiters = []
    waiters.forEach(resolve => resolve())
  }
}
