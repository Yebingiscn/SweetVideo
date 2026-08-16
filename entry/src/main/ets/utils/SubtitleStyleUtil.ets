import { MpvSubtitleStyle } from '../controller/MpvController/MpvTypes'
import Preferences from '../database/Preferences'
import { Setting } from './ObservedUtil'
import { PathUtils } from './PathUtils'
import {
  isInitialized as mpvIsInitialized, setSubtitleStyle as mpvSetSubtitleStyle
} from 'libmpvnative.so'

export default class SubtitleStyleUtil {
  static getAppBackgroundColor(): string {
    const alpha = Math.round(Math.max(0, Math.min(100, Setting.subtitleBackgroundOpacity)) * 255 / 100)
    let alphaHex = alpha.toString(16).toUpperCase()
    if (alphaHex.length === 1) {
      alphaHex = `0${alphaHex}`
    }
    return `#${alphaHex}000000`
  }

  static getMpvStyle(positionOverride?: number, sizeOverride?: number,
    playAreaHeight?: number, preserveAssStyle: boolean = false,
    preserveSecondaryAssStyle: boolean = false): MpvSubtitleStyle {
    const arkUiFontSize = sizeOverride ?? Number(Setting.subtitleSize)
    const defaultFontSize = Math.max(1, Number(Setting.subtitleSize))
    return {
      fontSize: SubtitleStyleUtil.getMpvFontSize(arkUiFontSize, playAreaHeight),
      color: Setting.subtitleColor,
      bold: Setting.subtitleBold,
      italic: Setting.subtitleItalic,
      borderSize: Setting.subtitleBorderSize,
      borderColor: Setting.subtitleBorderColor,
      shadowEnabled: Setting.subtitleShadowEnabled,
      shadowOffset: Setting.subtitleShadowSize,
      shadowColor: Setting.subtitleShadowColor,
      backgroundColor: '#000000',
      backgroundOpacity: Setting.subtitleBackgroundOpacity,
      position: positionOverride ?? Setting.subtitlePosition,
      preserveAssStyle: preserveAssStyle,
      preserveSecondaryAssStyle: preserveSecondaryAssStyle,
      scale: Math.max(0.25, Math.min(4, arkUiFontSize / defaultFontSize))
    }
  }

  /**
   * MPV 的 sub-font-size 是以 720 高窗口为基准的缩放像素；ArkUI 字号使用 fp。
   * 将 ArkUI 字号先转换成物理像素，再反算为 MPV 的 720 高基准字号。
   */
  static getMpvFontSize(arkUiFontSize: number, playAreaHeight?: number): number {
    const fallbackHeight = AppStorage.get<number>('screen_height') ?? 360
    const areaHeight = playAreaHeight && playAreaHeight > 0 ? playAreaHeight : fallbackHeight
    const areaHeightPx = vp2px(areaHeight)
    if (areaHeightPx <= 0) {
      return Math.max(10, Math.min(200, Math.round(arkUiFontSize * 2)))
    }
    const arkUiFontSizePx = fp2px(arkUiFontSize)
    return Math.max(10, Math.min(200, Math.round(arkUiFontSizePx * 720 / areaHeightPx * 1.2)))
  }

  static reset(): void {
    Setting.subtitleSize = '22'
    Setting.subtitlePosition = 90
    Setting.subtitleColor = '#F0F0F0'
    Setting.subtitleBold = false
    Setting.subtitleItalic = false
    Setting.subtitleBorderSize = 1
    Setting.subtitleBorderColor = '#000000'
    Setting.subtitleShadowEnabled = true
    Setting.subtitleShadowSize = 6
    Setting.subtitleShadowColor = '#000000'
    Setting.subtitleBackgroundOpacity = 0
    SubtitleStyleUtil.saveAll()
  }

  static applyToActiveMpv(): void {
    if (mpvIsInitialized()) {
      mpvSetSubtitleStyle(0, SubtitleStyleUtil.getMpvStyle())
    }
  }

  static saveAll(): void {
    if (!PathUtils.appContext) {
      return
    }
    Preferences.saveSubtitleSize(PathUtils.appContext, Setting.subtitleSize)
    Preferences.saveSubtitlePosition(PathUtils.appContext, Setting.subtitlePosition)
    Preferences.saveSubtitleColor(PathUtils.appContext, Setting.subtitleColor)
    Preferences.saveSubtitleBold(PathUtils.appContext, Setting.subtitleBold)
    Preferences.saveSubtitleItalic(PathUtils.appContext, Setting.subtitleItalic)
    Preferences.saveSubtitleBorderSize(PathUtils.appContext, Setting.subtitleBorderSize)
    Preferences.saveSubtitleBorderColor(PathUtils.appContext, Setting.subtitleBorderColor)
    Preferences.saveSubtitleShadowEnabled(PathUtils.appContext, Setting.subtitleShadowEnabled)
    Preferences.saveSubtitleShadowSize(PathUtils.appContext, Setting.subtitleShadowSize)
    Preferences.saveSubtitleShadowColor(PathUtils.appContext, Setting.subtitleShadowColor)
    Preferences.saveSubtitleBackgroundOpacity(PathUtils.appContext, Setting.subtitleBackgroundOpacity)
    SubtitleStyleUtil.applyToActiveMpv()
  }
}
