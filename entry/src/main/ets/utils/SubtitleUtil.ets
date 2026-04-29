import ToolsUtil from './ToolsUtil'
import { fileIo as fs, picker } from '@kit.CoreFileKit'
import { PathUtils } from './PathUtils'
import { Parser, SubtitleItem } from '../interfaces/SubtitleInterface'
import SubtitleFormat from '../common/SubtitleFormatConfig'
import { AssEvent, ParseAss, ParseSrt, ParseVtt, SrtLine, VttLine } from '../modules/subtitles'
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

  // 存储所有字幕项（已按开始时间排序）

  static normalizeSubtitleMode(subtitleMode?: SubtitleMode): SubtitleMode {
    if (subtitleMode === SubtitleMode.EXTERNAL_SUBTITLE || subtitleMode === SubtitleMode.AI_SUBTITLE) {
      return subtitleMode
    }
    return SubtitleMode.INNER_SUBTITLE
  }

  static normalizeSubtitle3DMode(subtitle3DMode?: Subtitle3DMode): Subtitle3DMode {
    if (subtitle3DMode === Subtitle3DMode.SIDE_BY_SIDE || subtitle3DMode === Subtitle3DMode.TOP_AND_BOTTOM) {
      return subtitle3DMode
    }
    return Subtitle3DMode.DISABLED
  }

  static hasSubtitlePreferenceMetadata(nowPlaying: VideoMetadata): boolean {
    return nowPlaying.subtitle_mode !== undefined ||
      nowPlaying.subtitle_visible !== undefined ||
      nowPlaying.subtitle_ai_asr_shown !== undefined ||
      nowPlaying.subtitle_3d_mode !== undefined ||
      nowPlaying.subtitle_offset_millis !== undefined ||
      nowPlaying.subtitle_track_id !== undefined
  }

  // 获取外挂字幕
  static async selectExternalSubtitles(sandbox_subtitle: string, date: string) {
    const documentSelectOptions = new picker.DocumentSelectOptions()
    documentSelectOptions.fileSuffixFilters = SUPPORT_SUBTITLE_FORMAT
    documentSelectOptions.maxSelectNumber = 1
    const documentViewPicker = new picker.DocumentViewPicker(PathUtils.appContext!)
    try {
      const uris = await documentViewPicker.select(documentSelectOptions)
      if (uris.length === 0) {
        return ''
      }
      let sourceFile: fs.File | null = null
      let targetFile: fs.File | null = null
      try {
        sourceFile = fs.openSync(uris[0], fs.OpenMode.READ_ONLY)
        targetFile = fs.openSync(`${sandbox_subtitle}${date}`, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
        await fs.copyFile(sourceFile.fd, targetFile.fd)?.catch(() => {
          salmonLogger.addLog(TAG, 'copy 失败', true)
        })
        const encode = await ToolsUtil.detectFileDecoder(targetFile.path)
        if (encode.length > 0 && encode.toLowerCase() !== 'utf-8') {
          ToolsUtil.transFileDecodeAsUTF8(targetFile.path, encode)
        }
        ToolsUtil.showToast(`导入字幕成功: ${sourceFile.name}`)
        return sourceFile.name
      } catch (error) {
        salmonLogger.addLog(TAG, 'import failed: ' + error, true)
        return ''
      } finally {
        // 确保文件描述符总是被关闭
        if (sourceFile) {
          fs.closeSync(sourceFile.fd)
        }
        if (targetFile) {
          fs.closeSync(targetFile.fd)
        }
      }
    } catch (error) {
      salmonLogger.addLog(TAG, 'import failed: ' + error, true)
      salmonLogger.addLog('subtitle', 'import failed: ' + error.code + ':' + error.message, true)
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
  static async deleteSubtitle(sandboxDir: string, fileName: string) {
    try {
      await fs.unlink(sandboxDir + fileName)
      ToolsUtil.showToast('删除成功')
    } catch (err) {
      const error = err as BusinessError
      if (error.code === 13900002) { // 文件或目录不存在错误码
        salmonLogger.addLog(TAG, '文件不存在')
      } else {
        ToolsUtil.showToast('删除失败')
        salmonLogger.addLog(TAG, 'delete failed: ' + error.code + ':' + error.message, true)
        salmonLogger.addLog('subtitle', 'delete failed: ' + error.code + ':' + error.message, true)
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

  static async parseSubtitleProcess(path: string, format: string | undefined) {
    if (!format) {
      SubtitleUtil.offsetMillis = 0
      // 逐一尝试 SRT、ASS、VTT 解析
      const formats = [SubtitleFormat.SRT, SubtitleFormat.ASS, SubtitleFormat.VTT]
      for (const fmt of formats) {
        let result = false
        switch (fmt) {
          case SubtitleFormat.SRT:
            result = await SubtitleUtil.parseSrtFile(path)
            break
          case SubtitleFormat.ASS:
            result = await SubtitleUtil.parseAssFile(path)
            break
          case SubtitleFormat.VTT:
            result = await SubtitleUtil.parseVttFile(path)
            break
          default:
            continue
        }
        if (result) { // 假设解析成功返回真值
          return result
        }
      }
      // 所有尝试都失败
      SubtitleUtil.subtitles = [];
      return false
    }
    switch (format) {
      case SubtitleFormat.SRT:
        return await SubtitleUtil.parseSrtFile(path)
      case SubtitleFormat.ASS:
        return await SubtitleUtil.parseAssFile(path)
      case SubtitleFormat.VTT:
        return await SubtitleUtil.parseVttFile(path)
      default:
        SubtitleUtil.subtitles = []
        return false
    }
  }

  // 解析SRT文件
  static async parseSrtFile(filePath: string) {
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
      SubtitleUtil.setSubtitles(items)
      return true
    } catch (e) {
      const error: string = e
      salmonLogger.addLog(TAG, `SRT 外挂字幕加载失败，原因是：${error}`, true)
      return false
    }
  }

  // 解析ASS文件
  static async parseAssFile(filePath: string) {
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
      SubtitleUtil.setSubtitles(items)
      return true
    } catch (e) {
      const error: string = e
      salmonLogger.addLog(TAG, `ASS 外挂字幕加载失败，原因是：${error}`, true)
      return false
    }
  }

  // 解析VTT文件
  static async parseVttFile(filePath: string) {
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
      SubtitleUtil.setSubtitles(items)
      return true
    } catch (e) {
      const error: string = e
      salmonLogger.addLog(TAG, `VTT 外挂字幕加载失败，原因是：${error}`, true)
      return false
    }
  }

  static getSubtitlesAtTime(timestamp: number, offsetOverride?: number): string {
    if (SubtitleUtil.subtitles.length === 0) {
      return ""
    }
    // 应用偏移量：将播放器时间转换为字幕时间
    const effectiveOffset = offsetOverride ?? SubtitleUtil.offsetMillis
    const adjustedTimestamp = timestamp - effectiveOffset
    // 如果偏移后的时间可能为负数，可以酌情处理
    // 这里简单的将负数视为0，避免越界错误
    const searchTimestamp = Math.max(adjustedTimestamp, 0)
    const result: SubtitleItem[] = []
    let left = 0
    let right = SubtitleUtil.subtitles.length - 1
    let startIndex = -1
    // 二分查找（使用调整后的时间戳）
    while (left <= right) {
      const mid = Math.floor((left + right) / 2)
      const sub = SubtitleUtil.subtitles[mid]
      if (sub.startTimestampMillis <= searchTimestamp &&
        sub.endTimestampMillis > searchTimestamp) {
        startIndex = mid
        break;
      } else if (sub.startTimestampMillis > searchTimestamp) {
        right = mid - 1
      } else {
        left = mid + 1
      }
    }
    if (startIndex === -1) {
      return ""
    }
    // 收集重叠字幕（逻辑保持不变）
    result.push(SubtitleUtil.subtitles[startIndex])
    // 向左查找
    for (let i = startIndex - 1; i >= 0; i--) {
      if (SubtitleUtil.subtitles[i].endTimestampMillis > searchTimestamp) {
        result.unshift(SubtitleUtil.subtitles[i])
      } else {
        break
      }
    }
    // 向右查找
    for (let i = startIndex + 1; i < SubtitleUtil.subtitles.length; i++) {
      if (SubtitleUtil.subtitles[i].startTimestampMillis <= searchTimestamp) {
        result.push(SubtitleUtil.subtitles[i])
      } else {
        break
      }
    }
    // 格式化返回
    return result.map(sub =>
    sub.text
      .replace(/\\[Nn]/g, '\n')
      .replace(/\{[^}]*\}/g, '')
      .replace(/<[^>]*>/g, '')
    ).join('\n')
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

  // 设置字幕数据
  private static setSubtitles(items: SubtitleItem[]) {
    SubtitleUtil.subtitles = items.sort((a, b) => a.startTimestampMillis - b.startTimestampMillis)
  }
}
