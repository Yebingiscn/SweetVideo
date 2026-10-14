// 尺寸均为当前窗口的 vp，不以手机默认屏幕或物理像素推断车机。
export default class HiCarLayout {
  static readonly touchSize: number = 56
  static readonly gap: number = 12

  static isEmbedded(width: number): boolean {
    return Number.isFinite(width) && width >= 640
  }

  static sidebarWidth(width: number): number {
    if (!Number.isFinite(width) || width <= 0) { return 200 }
    if (!HiCarLayout.isEmbedded(width)) {
      return Math.round(Math.min(280, Math.max(120, width * 0.8), Math.max(0, width - 16)))
    }
    return Math.round(Math.min(280, Math.max(200, width * 0.24), Math.max(0, width - 320)))
  }

  static controlWidth(width: number): number {
    if (!Number.isFinite(width)) { return 0 }
    return Math.min(Math.max(0, width - 32), 560)
  }
}
