import { util } from '@kit.ArkTS'
import { LocalSidecarFile } from './LocalSidecarFile'
import ToolsUtil from './ToolsUtil'
import TextEncodingUtil from './TextEncodingUtil'
import { fileIo as fs, picker } from '@kit.CoreFileKit'
import { PathUtils } from './PathUtils'
import { Parser, SubtitleItem } from '../interfaces/SubtitleInterface'
import SubtitleFormat from '../common/SubtitleFormatConfig'
import lazy { ParseAss } from '../modules/subtitles/src/main/ets/ParseAss'
import lazy { ParseSrt } from '../modules/subtitles/src/main/ets/ParseSrt'
import lazy { ParseVtt } from '../modules/subtitles/src/main/ets/ParseVtt'
import type { AssEvent } from '../modules/subtitles/src/main/ets/models/AssEvent'
import type { SrtLine } from '../modules/subtitles/src/main/ets/models/SrtLine'
import type { VttLine } from '../modules/subtitles/src/main/ets/models/VttLine'
import { salmonLogger } from 'salmonlogger'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { SUPPORT_SUBTITLE_FORMAT } from '../common/Constants'
import { Subtitle3DMode, SubtitleMode } from '../common/enum/SubtitleMode'

const TAG = 'SubtitleUtil'

// 实现 Parser 接口的适配器类
export class ParserAdapter<T> implements Parser<T> {
  private initFn: () => Promise<void>
  private readLinesFn: () => Promise<T[]>

  constructor(
    initFn: () => Promise<void>,
    readLinesFn: () => Promise<T[]>
  ) {
    this.initFn = initFn
    this.readLinesFn = readLinesFn
  }

  async init(): Promise<void> {
    return this.initFn()
  }

  async readLines(): Promise<T[]> {
    return this.readLinesFn()
  }
}

export default class SubtitleUtil {
  public static offsetMillis: number = 0
  private static subtitles: SubtitleItem[] = []
  private static subtitleMaxEnds: Float64Array = new Float64Array(0)
  private static subtitleTexts: string[] = []
  private static subtitleCacheFrom: number = -1
  private static subtitleCacheUntil: number = -1
  private static subtitleCacheValue: string = ''

  // 存储所有字幕项（已按开始时间排序）

  static normalizeSubtitleMode(subtitleMode?: SubtitleMode): SubtitleMode {
    return SubtitleUtil.normalizeEnum(subtitleMode,
      [SubtitleMode.NONE, SubtitleMode.INNER_SUBTITLE, SubtitleMode.EXTERNAL_SUBTITLE, SubtitleMode.AI_SUBTITLE],
      SubtitleMode.NONE)
  }

  static normalizeSubtitle3DMode(subtitle3DMode?: Subtitle3DMode): Subtitle3DMode {
    return SubtitleUtil.normalizeEnum(subtitle3DMode,
      [Subtitle3DMode.SIDE_BY_SIDE, Subtitle3DMode.TOP_AND_BOTTOM], Subtitle3DMode.DISABLED)
  }

  static hasSubtitlePreferenceMetadata(nowPlaying: VideoMetadata): boolean {
    return nowPlaying.subtitle_mode != undefined ||
      nowPlaying.subtitle_visible != undefined ||
      nowPlaying.subtitle_ai_asr_shown != undefined ||
      nowPlaying.subtitle_3d_mode != undefined ||
      nowPlaying.subtitle_offset_millis != undefined ||
      nowPlaying.subtitle_track_id != undefined
  }

  // Presentation metadata alone is not a selection. Keep explicit off, and
  // support legacy positive track IDs / AI selections without inventing an off.
  static getSubtitleSelectionMode(nowPlaying: VideoMetadata): SubtitleMode | undefined {
    const mode = nowPlaying.subtitle_mode
    if (mode !== undefined &&
      [SubtitleMode.NONE, SubtitleMode.INNER_SUBTITLE, SubtitleMode.EXTERNAL_SUBTITLE, SubtitleMode.AI_SUBTITLE]
        .includes(mode)) {
      return mode as SubtitleMode
    }
    if (nowPlaying.subtitle_ai_asr_shown === true) return SubtitleMode.AI_SUBTITLE
    if (nowPlaying.subtitle_track_id !== undefined && nowPlaying.subtitle_track_id >= 0) {
      return SubtitleMode.INNER_SUBTITLE
    }
    return undefined
  }

  // Share the bounded read, charset conversion and atomic save for manual/automatic import.
  static async importSubtitleFile(uri: string, target: string,
    cancelled: () => boolean = (): boolean => false): Promise<void> {
    const bytes = await LocalSidecarFile.read(uri, 32 * 1024 * 1024, cancelled)
    const encoding = TextEncodingUtil.detectBufferEncoding(bytes.buffer as ArrayBuffer) || 'utf-8'
    const text = util.TextDecoder.create(encoding).decodeToString(bytes)
    const utf8 = new util.TextEncoder().encodeInto(text)
    await LocalSidecarFile.save(target, utf8, cancelled)
  }

  // 获取外挂字幕
  static async selectExternalSubtitles(sandbox_subtitle: string, date: string,
    cancelled: () => boolean = (): boolean => false): Promise<string> {
    const options = new picker.DocumentSelectOptions()
    options.fileSuffixFilters = ToolsUtil.localizeSuffixFilter(SUPPORT_SUBTITLE_FORMAT, $r('app.string.filter_subtitle'))
    options.maxSelectNumber = 1
    try {
      const uris = await new picker.DocumentViewPicker(PathUtils.appContext!).select(options)
      if (uris.length === 0 || cancelled()) {
        return ''
      }
      const name = decodeURIComponent(uris[0].split('/').pop() || '')
      const format = name.split('.').pop()?.toLowerCase() || ''
      if (![SubtitleFormat.SRT, SubtitleFormat.ASS, SubtitleFormat.VTT].includes(format)) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.select_subtitle_file').id))
        return ''
      }
      await SubtitleUtil.importSubtitleFile(uris[0], `${sandbox_subtitle}${date}`, cancelled)
      if (cancelled()) {
        return ''
      }
      ToolsUtil.showToast(ToolsUtil.getStringResourceArgs($r('app.string.subtitle_import_success').id, name))
      return name
    } catch (error) {
      if (!cancelled()) {
        salmonLogger.addLog(TAG, '字幕导入或保存失败', true)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.subtitle_import_failed').id))
      }
      return ''
    }
  }
  // 检查字幕是否存在
  static async isSubtitleExist(sandbox_subtitle: string, date: string): Promise<boolean> {
    return new Promise((resolve) => {
      fs.access(sandbox_subtitle + date).then((res: boolean) => {
        if (res) {
          resolve(true)
        } else {
          resolve(false)
        }
      })?.catch((err: BusinessError) => {
        salmonLogger.addLog(TAG, "access failed with error message: " + err.message + ", error code: " + err.code, true)
        salmonLogger.addLog('subtitle', 'delete failed: ' + err.code + ':' + err.message, false)
        resolve(false)
      })
    })
  }

  // 删除字幕
  static async deleteSubtitle(sandboxDir: string, fileName: string, silent: boolean = false) {
    try {
      await fs.unlink(sandboxDir + fileName)
      if (!silent) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.delete_success').id))
      }
    } catch (error) {
      if (error.code === 13900002) {
        // 清理是幂等操作，字幕不存在已满足删除目标。
        return
      } else {
        if (!silent) {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.delete_failed').id))
        }
        salmonLogger.addLog(TAG, 'delete failed: ' + error.code + ':' + error.message, true)
        throw new Error('delete failed: ' + error.code + ':' + error.message)
      }
    }
  }

  static async importOrDeleteSubtitleProcess(item: VideoMetadata) {
    if (await SubtitleUtil.isSubtitleExist(PathUtils.subtitlePath, item?.date!)) {
      await SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, item?.date!)
      item!.external_subtitle_format = ''
    } else {
      const subtitleName = await SubtitleUtil.selectExternalSubtitles(PathUtils.subtitlePath, item?.date!)
      const subtitleNameFormat = subtitleName?.match(/[^.]+$/)?.[0]?.toLowerCase() || ''
      switch (subtitleNameFormat) {
        case SubtitleFormat.SRT:
          item!.external_subtitle_format = SubtitleFormat.SRT
          break
        case SubtitleFormat.ASS:
          item!.external_subtitle_format = SubtitleFormat.ASS
          break
        case SubtitleFormat.VTT:
          item!.external_subtitle_format = SubtitleFormat.VTT
          break
        default:
          item!.external_subtitle_format = ''
      }
    }
  }

  static async parseSubtitleProcess(path: string, format: string | undefined,
    cancelled: () => boolean = (): boolean => false) {
    if (!format) {
      SubtitleUtil.offsetMillis = 0
      const ext = path.split('.').pop()?.toLowerCase()
      switch (ext) {
        case 'srt':
          return await SubtitleUtil.parseSrtFile(path, cancelled)
        case 'ass':
        case 'ssa':
          return await SubtitleUtil.parseAssFile(path, cancelled)
        case 'vtt':
          return await SubtitleUtil.parseVttFile(path, cancelled)
        default:
          break
      }
      const formats = [SubtitleFormat.SRT, SubtitleFormat.ASS, SubtitleFormat.VTT]
      for (const fmt of formats) {
        let result = false
        switch (fmt) {
          case SubtitleFormat.SRT:
            result = await SubtitleUtil.parseSrtFile(path, cancelled)
            break
          case SubtitleFormat.ASS:
            result = await SubtitleUtil.parseAssFile(path, cancelled)
            break
          case SubtitleFormat.VTT:
            result = await SubtitleUtil.parseVttFile(path, cancelled)
            break
          default:
            continue
        }
        if (result) {
          return result
        }
      }
      if (!cancelled()) { SubtitleUtil.setSubtitles([]) }
      return false
    }
    switch (format) {
      case SubtitleFormat.SRT:
        return await SubtitleUtil.parseSrtFile(path, cancelled)
      case SubtitleFormat.ASS:
        return await SubtitleUtil.parseAssFile(path, cancelled)
      case SubtitleFormat.VTT:
        return await SubtitleUtil.parseVttFile(path, cancelled)
      default:
        if (!cancelled()) { SubtitleUtil.setSubtitles([]) }
        return false
    }
  }

  // 解析SRT文件
  static async parseSrtFile(filePath: string, cancelled: () => boolean = (): boolean => false): Promise<boolean> {
    try {
      const parser = new ParseSrt(filePath)
      const items = await SubtitleUtil.parseSubtitleFile<SrtLine>(
        parser,
        (line: SrtLine) => ({
          startTimestampMillis: line.startTimestampMillis,
          endTimestampMillis: line.endTimestampMillis,
          text: line.text
        })
      )
      if (cancelled()) {
        return false
      }
      SubtitleUtil.setSubtitles(items)
      return true
    } catch (e) {
      const error: string = e
      salmonLogger.addLog(TAG, `SRT 外挂字幕加载失败，原因是：${error}`, true)
      return false
    }
  }

  // 解析ASS文件
  static async parseAssFile(filePath: string, cancelled: () => boolean = (): boolean => false): Promise<boolean> {
    try {
      const parser = new ParseAss(filePath)
      const parserAdapter = new ParserAdapter<AssEvent>(
        async () => await parser.init(),
        async () => await parser.readEvents()
      )
      const items = await SubtitleUtil.parseSubtitleFile<AssEvent>(
        parserAdapter,
        (line: AssEvent) => ({
          startTimestampMillis: line.startTimestampMillis,
          endTimestampMillis: line.endTimestampMillis,
          text: line.text
        }))
      if (cancelled()) {
        return false
      }
      SubtitleUtil.setSubtitles(items)
      return true
    } catch (e) {
      const error: string = e
      salmonLogger.addLog(TAG, `ASS 外挂字幕加载失败，原因是：${error}`, true)
      return false
    }
  }

  // 解析VTT文件
  static async parseVttFile(filePath: string, cancelled: () => boolean = (): boolean => false): Promise<boolean> {
    try {
      const parser = new ParseVtt(filePath)
      const items = await SubtitleUtil.parseSubtitleFile<VttLine>(
        parser,
        (line: VttLine) => ({
          startTimestampMillis: line.startTimestampMillis,
          endTimestampMillis: line.endTimestampMillis,
          text: line.text
        })
      )
      if (cancelled()) {
        return false
      }
      SubtitleUtil.setSubtitles(items)
      return true
    } catch (e) {
      const error: string = e
      salmonLogger.addLog(TAG, `VTT 外挂字幕加载失败，原因是：${error}`, true)
      return false
    }
  }

  static getSubtitlesAtTime(timestamp: number, offsetOverride?: number): string {
    const subtitles = SubtitleUtil.subtitles
    if (subtitles.length === 0) return ''
    const effectiveOffset = offsetOverride ?? SubtitleUtil.offsetMillis
    const searchTimestamp = Math.max(timestamp - effectiveOffset, 0)
    if (searchTimestamp >= SubtitleUtil.subtitleCacheFrom && searchTimestamp < SubtitleUtil.subtitleCacheUntil) {
      return SubtitleUtil.subtitleCacheValue
    }
    const nextIndex = SubtitleUtil.findFirstStartGreaterThan(searchTimestamp)
    let cacheUntil = nextIndex < subtitles.length ? subtitles[nextIndex].startTimestampMillis : Infinity
    const result: string[] = []
    const maxEnds = SubtitleUtil.subtitleMaxEnds
    const texts = SubtitleUtil.subtitleTexts
    // 按最大结束时间跳过整段已结束字幕；长字幕与多条短字幕重叠时也无需逐条回扫。
    const collect = (node: number, start: number, end: number): void => {
      if (start >= nextIndex || maxEnds[node] <= searchTimestamp) return
      if (end - start === 1) {
        result.push(texts[start])
        cacheUntil = Math.min(cacheUntil, subtitles[start].endTimestampMillis)
        return
      }
      const middle = Math.floor((start + end) / 2)
      collect(node * 2, start, middle)
      collect(node * 2 + 1, middle, end)
    }
    collect(1, 0, maxEnds.length / 2)
    const value = result.join('\n')
    SubtitleUtil.subtitleCacheFrom = searchTimestamp
    SubtitleUtil.subtitleCacheUntil = cacheUntil
    SubtitleUtil.subtitleCacheValue = value
    return value
  }

  static getAdjacentSubtitleOffset(
    playbackTimestamp: number,
    currentOffsetMillis: number,
    direction: 'prev' | 'next'
  ): number | undefined {
    if (SubtitleUtil.subtitles.length === 0) {
      return undefined
    }
    const searchTimestamp = Math.max(playbackTimestamp - currentOffsetMillis, 0)
    const nextIndex = SubtitleUtil.findFirstStartGreaterThan(searchTimestamp)
    const activeIndex = (nextIndex > 0 && SubtitleUtil.subtitles[nextIndex - 1].endTimestampMillis > searchTimestamp)
      ? nextIndex - 1
      : -1

    let targetIndex = -1
    if (direction === 'prev') {
      targetIndex = activeIndex >= 0 ? activeIndex - 1 : nextIndex - 1
    } else {
      targetIndex = activeIndex >= 0 ? activeIndex + 1 : nextIndex
    }

    if (targetIndex < 0 || targetIndex >= SubtitleUtil.subtitles.length) {
      return undefined
    }
    return playbackTimestamp - SubtitleUtil.subtitles[targetIndex].startTimestampMillis
  }

  // 统一解析字幕文件
  static async parseSubtitleFile<T>(
    parser: Parser<T>,
    mapper: (item: T) => SubtitleItem
  ): Promise<SubtitleItem[]> {
    await parser.init()
    const lines = await parser.readLines()
    return lines.map(mapper)
  }

  static findFirstStartGreaterThan(timestamp: number): number {
    let left = 0
    let right = SubtitleUtil.subtitles.length
    while (left < right) {
      const mid = Math.floor((left + right) / 2)
      if (SubtitleUtil.subtitles[mid].startTimestampMillis > timestamp) {
        right = mid
      } else {
        left = mid + 1
      }
    }
    return left
  }

  private static normalizeEnum<T>(value: T | undefined, validValues: T[], defaultValue: T): T {
    if (value !== undefined && validValues.includes(value)) {
      return value
    }
    return defaultValue
  }

  // 设置字幕数据
  private static setSubtitles(items: SubtitleItem[]) {
    let needsSort = false
    for (let i = 1; i < items.length; i++) {
      if (items[i].startTimestampMillis < items[i - 1].startTimestampMillis) {
        needsSort = true
        break
      }
    }
    const subtitles = needsSort
      ? items.sort((a, b) => a.startTimestampMillis - b.startTimestampMillis)
      : items
    let leafCount = 1
    while (leafCount < subtitles.length) leafCount *= 2
    const maxEnds = new Float64Array(leafCount * 2)
    maxEnds.fill(-Infinity)
    const texts: string[] = []
    for (let i = 0; i < subtitles.length; i++) {
      const subtitle = subtitles[i]
      maxEnds[leafCount + i] = Number.isNaN(subtitle.endTimestampMillis) ? -Infinity : subtitle.endTimestampMillis
      texts.push(subtitle.text.replace(/\\[Nn]/g, '\n').replace(/\{[^}]*\}/g, '').replace(/<[^>]*>/g, ''))
    }
    for (let i = leafCount - 1; i > 0; i--) maxEnds[i] = Math.max(maxEnds[i * 2], maxEnds[i * 2 + 1])
    SubtitleUtil.subtitles = subtitles
    SubtitleUtil.subtitleMaxEnds = maxEnds
    SubtitleUtil.subtitleTexts = texts
    SubtitleUtil.subtitleCacheFrom = -1
    SubtitleUtil.subtitleCacheUntil = -1
    SubtitleUtil.subtitleCacheValue = ''
  }
}
