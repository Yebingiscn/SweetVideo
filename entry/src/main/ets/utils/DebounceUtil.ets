/**
 * 防抖工具类
 * 用于延迟执行函数，避免频繁调用
 */
export class DebounceUtil {
  private static timers: Map<string, number> = new Map()

  /**
   * 防抖执行函数
   * @param key 唯一标识键
   * @param func 要执行的函数
   * @param delay 延迟时间（毫秒）
   */
  static debounce(key: string, func: Function, delay: number = 300): void {
    const existingTimer = DebounceUtil.timers.get(key)
    if (existingTimer !== undefined) {
      clearTimeout(existingTimer)
    }
    const timer = setTimeout(() => {
      func()
      DebounceUtil.timers.delete(key)
    }, delay)
    DebounceUtil.timers.set(key, timer)
  }

  /**
   * 立即执行并取消待执行的防抖
   * @param key 唯一标识键
   * @param func 要执行的函数
   */
  static immediate(key: string, func: Function): void {
    DebounceUtil.cancel(key)
    func()
  }

  /**
   * 取消防抖
   * @param key 唯一标识键
   */
  static cancel(key: string): void {
    const existingTimer = DebounceUtil.timers.get(key)
    if (existingTimer !== undefined) {
      clearTimeout(existingTimer)
      DebounceUtil.timers.delete(key)
    }
  }

  /**
   * 清除所有防抖
   */
  static clearAll(): void {
    DebounceUtil.timers.forEach((timer) => {
      clearTimeout(timer)
    })
    DebounceUtil.timers.clear()
  }
}

/**
 * 节流工具类
 * 用于限制函数执行频率
 */
export class ThrottleUtil {
  private static lastExecuteTime: Map<string, number> = new Map()

  /**
   * 节流执行函数
   * @param key 唯一标识键
   * @param func 要执行的函数
   * @param interval 执行间隔（毫秒）
   * @returns 是否执行了函数
   */
  static throttle(key: string, func: Function, interval: number = 100): boolean {
    const now = Date.now()
    const lastTime = ThrottleUtil.lastExecuteTime.get(key) || 0

    if (now - lastTime >= interval) {
      func()
      ThrottleUtil.lastExecuteTime.set(key, now)
      return true
    }
    return false
  }

  /**
   * 重置节流状态
   * @param key 唯一标识键
   */
  static reset(key: string): void {
    ThrottleUtil.lastExecuteTime.delete(key)
  }

  /**
   * 清除所有节流状态
   */
  static clearAll(): void {
    ThrottleUtil.lastExecuteTime.clear()
  }
}
