export interface AICaptionSettingsValue {
  sourceLanguage: string
  targetLanguage: string
  fontSize: number
  fontColor: string
  backgroundOpacity: number
}

// 与普通字幕样式独立；所有写入和启动读取使用同一套参数约束。
export default class AICaptionSettings {
  static defaults(): AICaptionSettingsValue {
    return {
      sourceLanguage: 'zh',
      targetLanguage: 'zh',
      fontSize: 2,
      fontColor: '#FFFFFFFF',
      backgroundOpacity: 50
    }
  }

  static normalize(value: AICaptionSettingsValue): AICaptionSettingsValue {
    if (!value) {
      return AICaptionSettings.defaults()
    }
    const sourceLanguage = value.sourceLanguage === 'en' ? 'en' : 'zh'
    const targetLanguage = sourceLanguage === 'en' &&
      (value.targetLanguage === 'en' || value.targetLanguage === 'zh-en') ? value.targetLanguage : 'zh'
    return {
      sourceLanguage,
      targetLanguage,
      fontSize: Number.isInteger(value.fontSize) && value.fontSize >= 1 && value.fontSize <= 4 ? value.fontSize : 2,
      fontColor: typeof value.fontColor === 'string' && /^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(value.fontColor) ?
        value.fontColor.toUpperCase() : '#FFFFFFFF',
      backgroundOpacity: AICaptionSettings.normalizeBackgroundOpacity(value.backgroundOpacity)
    }
  }

  static getInitialOpacity(backgroundOpacity: number, deviceType: string): number {
    const opacity = AICaptionSettings.normalizeBackgroundOpacity(backgroundOpacity) / 100
    // 2in1 的 SDK 只接受全透明、半透明和不透明三档。
    return deviceType === '2in1' ? Math.round(opacity * 2) / 2 : opacity
  }

  private static normalizeBackgroundOpacity(value: number): number {
    return typeof value === 'number' && Number.isFinite(value) ? Math.max(0, Math.min(100, Math.round(value))) : 50
  }
}
