import common from '@ohos.app.ability.common';

export class PathUtils {
  private static context: common.UIAbilityContext | null = null;

  // 获取沙箱根路径
  static get sandboxPath(): string {
    return this.context?.filesDir ?? '';
  }

  static get coverPath(): string {
    return `${this.sandboxPath}/`
  }

  // 获取视频目录路径
  static get videoPath(): string {
    return `${this.sandboxPath}/video/`;
  }

  // 获取图片目录路径
  static get photoPath(): string {
    return `${this.sandboxPath}/photo/`
  }

  // 获取字幕目录路径
  static get subtitlePath(): string {
    return `${this.sandboxPath}/subtitle/`;
  }

  static get appContext(): common.UIAbilityContext | null {
    return PathUtils.context;
  }

  // 初始化上下文（在Ability的onCreate中调用）
  static init(context: common.UIAbilityContext) {
    PathUtils.context = context;
  }
}