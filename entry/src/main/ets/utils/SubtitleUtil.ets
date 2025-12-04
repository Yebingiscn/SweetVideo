import VideoInfoUtil from './VideoInfoUtil';
import ToolsUtil from './ToolsUtil';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PathUtils } from './PathUtils';
import { Parser, SubtitleItem } from '../interfaces/SubtitleInterface';
import SubtitleFormat from '../common/SubtitleFormatConfig';
import { AssEvent, ParseAss, ParseSrt, ParseVtt, SrtLine, VttLine } from '../modules/subtitles';

// 实现 Parser 接口的适配器类
export class ParserAdapter<T> implements Parser<T> {
  private initFn: () => Promise<void>;
  private readLinesFn: () => Promise<T[]>;

  constructor(
    initFn: () => Promise<void>,
    readLinesFn: () => Promise<T[]>
  ) {
    this.initFn = initFn;
    this.readLinesFn = readLinesFn;
  }

  async init(): Promise<void> {
    return this.initFn();
  }

  async readLines(): Promise<T[]> {
    return this.readLinesFn();
  }
}

class SubtitleUtil {
  private subtitles: SubtitleItem[] = []; // 存储所有字幕项（已按开始时间排序）

  // 获取外挂字幕
  async selectExternalSubtitles(sandbox_subtitle: string, date: string) {
    const documentSelectOptions = new picker.DocumentSelectOptions();
    documentSelectOptions.fileSuffixFilters = VideoInfoUtil.support_subtitle_format;
    documentSelectOptions.maxSelectNumber = 1;
    const documentViewPicker = new picker.DocumentViewPicker(PathUtils.appContext!);
    try {
      const uris = await documentViewPicker.select(documentSelectOptions);
      if (uris.length === 0) {
        return '';
      }
      let sourceFile: fs.File | null = null;
      let targetFile: fs.File | null = null;
      try {
        sourceFile = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
        targetFile = fs.openSync(`${sandbox_subtitle}${date}`, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        await fs.copyFile(sourceFile.fd, targetFile.fd).catch(() => {
          console.error('copy 失败')
        });
        const encode = await ToolsUtil.detectFileDecoder(targetFile.path)
        if (encode.length > 0 && encode.toLowerCase() !== 'utf-8') {
          ToolsUtil.transFileDecodeAsUTF8(targetFile.path, encode)
        }
        ToolsUtil.showToast(`导入字幕成功: ${sourceFile.name}`);
        return sourceFile.name;
      } catch (error) {
        console.error('import failed: ', error);
        return ''
      } finally {
        // 确保文件描述符总是被关闭
        if (sourceFile) {
          fs.closeSync(sourceFile.fd);
        }
        if (targetFile) {
          fs.closeSync(targetFile.fd);
        }
      }
    } catch (error) {
      console.error('import failed: ', error);
      return '';
    }
  }

  // 检查字幕是否存在
  async isSubtitleExist(sandbox_subtitle: string, date: string): Promise<boolean> {
    return new Promise((resolve) => {
      fs.access(sandbox_subtitle + date).then((res: boolean) => {
        if (res) {
          resolve(true);
        } else {
          resolve(false);
        }
      }).catch((err: BusinessError) => {
        console.error("access failed with error message: " + err.message + ", error code: " + err.code);
        resolve(false);
      });
    })
  }

  // 删除字幕
  async deleteSubtitle(sandboxDir: string, fileName: string) {
    try {
      await fs.unlink(sandboxDir + fileName);
      ToolsUtil.showToast('删除成功');
    } catch (err) {
      const error = err as BusinessError;
      if (error.code === 13900002) { // 文件或目录不存在错误码
        console.warn('文件不存在');
      } else {
        ToolsUtil.showToast('删除失败');
        console.error('delete failed: ' + error.code + ':' + error.message)
      }
    }
  }

  async parseSubtitleProcess(path: string, format: string | undefined) {
    if (!format) {
      return await this.parseSrtFile(path)
    }
    switch (format) {
      case SubtitleFormat.SRT:
        return await this.parseSrtFile(path)
      case SubtitleFormat.ASS:
        return await this.parseAssFile(path)
      case SubtitleFormat.VTT:
        return await this.parseVttFile(path)
      default:
        this.subtitles = []
        return false
    }
  }

  // 解析SRT文件
  async parseSrtFile(filePath: string) {
    try {
      const parser = new ParseSrt(filePath);
      const items = await this.parseSubtitleFile<SrtLine>(
        parser,
        (line: SrtLine) => ({
          startTimestampMillis: line.startTimestampMillis,
          endTimestampMillis: line.endTimestampMillis,
          text: line.text
        })
      );
      this.setSubtitles(items);
      return true
    } catch (e) {
      console.error('test' + e)
      return false
    }
  }

  // 解析ASS文件
  async parseAssFile(filePath: string) {
    try {
      const parser = new ParseAss(filePath);
      const parserAdapter = new ParserAdapter<AssEvent>(
        async () => await parser.init(),
        async () => await parser.readEvents()
      );
      const items = await this.parseSubtitleFile<AssEvent>(
        parserAdapter,
        (line: AssEvent) => ({
          startTimestampMillis: line.startTimestampMillis,
          endTimestampMillis: line.endTimestampMillis,
          text: line.text
        }))
      this.setSubtitles(items);
      return true;
    } catch (e) {
      console.error('testASS解析诊断失败:', e);
      return false;
    }
  }

  // 解析VTT文件
  async parseVttFile(filePath: string) {
    try {
      const parser = new ParseVtt(filePath);
      const items = await this.parseSubtitleFile<VttLine>(
        parser,
        (line: VttLine) => ({
          startTimestampMillis: line.startTimestampMillis,
          endTimestampMillis: line.endTimestampMillis,
          text: line.text
        })
      );
      this.setSubtitles(items);
      return true
    } catch (e) {
      console.error('test' + e)
      return false
    }
  }

  getSubtitlesAtTime(timestamp: number): string {
    if (this.subtitles.length === 0) {
      return "";
    }
    const result: SubtitleItem[] = [];
    let left = 0;
    let right = this.subtitles.length - 1;
    let startIndex = -1;
    // 二分查找可能包含时间戳的字幕范围
    while (left <= right) {
      const mid = Math.floor((left + right) / 2);
      const sub = this.subtitles[mid];
      if (sub.startTimestampMillis <= timestamp && sub.endTimestampMillis >= timestamp) {
        startIndex = mid;
        break;
      } else if (sub.startTimestampMillis > timestamp) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }
    if (startIndex === -1) {
      return ""; // 没有找到包含该时间点的字幕
    }
    // 从找到的位置向两边扩展，收集所有重叠的字幕
    result.push(this.subtitles[startIndex]);
    // 向左查找
    for (let i = startIndex - 1; i >= 0; i--) {
      if (this.subtitles[i].endTimestampMillis >= timestamp) {
        result.unshift(this.subtitles[i]);
      } else {
        break;
      }
    }
    // 向右查找
    for (let i = startIndex + 1; i < this.subtitles.length; i++) {
      if (this.subtitles[i].startTimestampMillis <= timestamp) {
        result.push(this.subtitles[i]);
      } else {
        break;
      }
    }
    return result.map(sub => sub.text.replace(/<[^>]*>/g, '')).join('\n');
  }

  // 统一解析字幕文件
  private async parseSubtitleFile<T>(
    parser: Parser<T>,
    mapper: (item: T) => SubtitleItem
  ): Promise<SubtitleItem[]> {
    await parser.init();
    const lines = await parser.readLines();
    return lines.map(mapper);
  }

  // 设置字幕数据
  private setSubtitles(items: SubtitleItem[]) {
    this.subtitles = items.sort((a, b) => a.startTimestampMillis - b.startTimestampMillis);
  }
}

export default new SubtitleUtil()