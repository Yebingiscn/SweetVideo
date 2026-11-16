// 尺寸均为当前窗口的 vp，不以手机默认屏幕或物理像素推断车机。
export default class HiCarLayout {
  static readonly touchSize: number = 56
  static readonly gap: number = 12

  // 原有 40 vp 按钮，左右各留 8 vp；常规车载窗口每排 4 个。
  static buttonWidth(width: number): number {
    return Math.min(224, HiCarLayout.controlWidth(width))
  }

  static controlWidth(width: number): number {
    if (!Number.isFinite(width)) { return 0 }
    return Math.min(Math.max(0, width - 32), 560)
  }
}
