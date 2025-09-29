/**
 * 视频播放循环模式枚举
 */
export enum RepeatMode {
  /**
   * 列表循环模式
   */
  LIST_LOOP = 0,

  /**
   * 单曲循环模式
   */
  SINGLE_LOOP = 1,

  /**
   * 随机播放模式
   */
  RANDOM = 2,
  /**
   * 仅播放一次后退出
   */
  SINGLE_PLAY = 3
}