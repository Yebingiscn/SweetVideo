import { SubtitlePreferredLanguage } from '../common/enum/SubtitleLanguage'
import { SubtitleTrack } from '../interfaces/AudioTrackInterface'

export default class SubtitleLanguageUtil {
  static normalizeLanguage(language: number): SubtitlePreferredLanguage {
    if (language === SubtitlePreferredLanguage.TRADITIONAL_CHINESE ||
      language === SubtitlePreferredLanguage.ENGLISH) {
      return language as SubtitlePreferredLanguage
    }
    return SubtitlePreferredLanguage.SIMPLIFIED_CHINESE
  }

  static selectPreferredTrack(tracks: SubtitleTrack[], language: SubtitlePreferredLanguage): SubtitleTrack | undefined {
    if (tracks.length === 0) {
      return undefined
    }

    const normalizedLanguage = SubtitleLanguageUtil.normalizeLanguage(language)
    let selectedTrack: SubtitleTrack | undefined = undefined
    let selectedScore = 0
    for (const track of tracks) {
      const score = SubtitleLanguageUtil.getMatchScore(track, normalizedLanguage)
      if (score > selectedScore) {
        selectedTrack = track
        selectedScore = score
      }
    }
    // 轨道没有语言标识，或没有所选语言时，保持媒体中的首轨顺序。
    return selectedTrack ?? tracks[0]
  }

  private static getMatchScore(track: SubtitleTrack, language: SubtitlePreferredLanguage): number {
    const lang = (track.lang ?? '').trim().toLowerCase().replace(/_/g, '-')
    const title = (track.title ?? '').trim().toLowerCase()
    const isSimplified = SubtitleLanguageUtil.isSimplifiedChinese(lang, title)
    const isTraditional = SubtitleLanguageUtil.isTraditionalChinese(lang, title)
    const isGenericChinese = !isSimplified && !isTraditional && SubtitleLanguageUtil.isChinese(lang, title)

    if (language === SubtitlePreferredLanguage.SIMPLIFIED_CHINESE) {
      return isSimplified ? 2 : (isGenericChinese ? 1 : 0)
    }
    if (language === SubtitlePreferredLanguage.TRADITIONAL_CHINESE) {
      return isTraditional ? 2 : (isGenericChinese ? 1 : 0)
    }
    return SubtitleLanguageUtil.isEnglish(lang, title) ? 2 : 0
  }

  private static isSimplifiedChinese(lang: string, title: string): boolean {
    return lang === 'chs' || lang === 'sc' || lang === 'simplified' || lang === 'zh-cn' || lang === 'zh-sg' ||
      lang.startsWith('zh-hans') || SubtitleLanguageUtil.containsAny(title,
        ['简体', '簡體', '简中', '簡中', 'simplified', 'chs'])
  }

  private static isTraditionalChinese(lang: string, title: string): boolean {
    return lang === 'cht' || lang === 'tc' || lang === 'traditional' || lang === 'zh-tw' || lang === 'zh-hk' ||
      lang === 'zh-mo' || lang.startsWith('zh-hant') || SubtitleLanguageUtil.containsAny(title,
        ['繁体', '繁體', '繁中', '正体', '正體', 'traditional', 'cht', 'big5'])
  }

  private static isChinese(lang: string, title: string): boolean {
    return lang === 'zh' || lang === 'chi' || lang === 'zho' || lang === 'cn' || lang.startsWith('zh-') ||
      SubtitleLanguageUtil.containsAny(title, ['中文', 'chinese'])
  }

  private static isEnglish(lang: string, title: string): boolean {
    return lang === 'en' || lang === 'eng' || lang.startsWith('en-') ||
      SubtitleLanguageUtil.containsAny(title, ['english', '英文', '英语', '英語'])
  }

  private static containsAny(value: string, markers: string[]): boolean {
    for (const marker of markers) {
      if (value.includes(marker)) {
        return true
      }
    }
    return false
  }
}
