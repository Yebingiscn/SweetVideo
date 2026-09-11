export default class HomeSidebarLayout {
  static readonly minWidth: number = 240
  static readonly maxWidth: number = 360
  static readonly minContentWidth: number = 480

  static isEmbedded(windowWidth: number): boolean {
    return windowWidth >= HomeSidebarLayout.minWidth + HomeSidebarLayout.minContentWidth
  }

  static getWidth(windowWidth: number): number {
    if (!Number.isFinite(windowWidth) || windowWidth <= 0) {
      return HomeSidebarLayout.minWidth
    }
    if (!HomeSidebarLayout.isEmbedded(windowWidth)) {
      // 覆盖式侧栏保留外侧空间，便于点击内容区关闭。
      return Math.round(Math.min(HomeSidebarLayout.maxWidth, windowWidth * 0.60))
    }
    return Math.round(Math.min(HomeSidebarLayout.maxWidth,
      Math.max(HomeSidebarLayout.minWidth, windowWidth * 0.24),
      windowWidth - HomeSidebarLayout.minContentWidth))
  }
}
