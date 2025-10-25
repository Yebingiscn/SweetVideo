import VideoInfoUtil from './VideoInfoUtil';
import ToolsUtil from './ToolsUtil';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PathUtils } from './PathUtils';
import { AssEvent, ParseAss, ParseSrt, ParseVtt, SrtLine, VttLine } from '../modules/subtitles';
import { Parser, SubtitleItem } from '../interfaces/SubtitleInterface';

// 实现 Parser 接口的适配器类
class ParserAdapter<T> implements Parser<T> {
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
    documentSelectOptions.maxSelectNumber = 1
    const documentViewPicker = new picker.DocumentViewPicker(PathUtils.appContext!);
    documentViewPicker.select(documentSelectOptions).then((uris) => {
      if (uris.length > 0) {
        try {
          let file1 = fs.openSync(uris[0], fs.OpenMode.READ_ONLY)
          let file2 = fs.openSync(sandbox_subtitle + date, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
          fs.copyFileSync(file1.fd, file2.fd)
          ToolsUtil.showToast('导入字幕成功: ' + file1.name)
          fs.closeSync(file1.fd)
          fs.closeSync(file2.fd)
        } catch (err) {
          console.error('import failed: ' + err)
          ToolsUtil.showToast('导入字幕失败')
        }
      }
    })
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

  // 解析SRT文件
  async parseSrtFile(filePath: string): Promise<SubtitleItem[]> {
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
    return items;
  }

  // 解析ASS文件
  async parseAssFile(filePath: string): Promise<SubtitleItem[]> {
    const parser = new ParseAss(filePath);

    // 创建适配器实例
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
      })
    );

    this.setSubtitles(items);
    return items;
  }

  // 解析VTT文件
  async parseVttFile(filePath: string): Promise<SubtitleItem[]> {
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
    return items;
  }

  // 获取某个时间点正在显示的字幕
  getSubtitlesAtTime(timestamp: number): SubtitleItem[] {
    if (this.subtitles.length === 0) {
      return [];
    }

    const index = this.findFirstIndexAfter(timestamp);
    const result: SubtitleItem[] = [];

    // 向前查找重叠字幕
    for (let i = index - 1; i >= 0; i--) {
      const sub = this.subtitles[i];
      if (sub.endTimestampMillis < timestamp) {
        break;
      }
      if (sub.startTimestampMillis <= timestamp) {
        result.unshift(sub);
      }
    }

    // 向后查找重叠字幕
    for (let i = index; i < this.subtitles.length; i++) {
      const sub = this.subtitles[i];
      if (sub.startTimestampMillis > timestamp) {
        break;
      }
      if (sub.endTimestampMillis >= timestamp) {
        result.push(sub);
      }
    }

    return result;
  }

  // 统一解析字幕文件
  private async parseSubtitleFile<T>(
    parser: Parser<T>,
    mapper: (item: T) => SubtitleItem
  ): Promise<SubtitleItem[]> {
    try {
      await parser.init();
      const lines = await parser.readLines();
      return lines.map(mapper);
    } catch (error) {
      console.error('解析字幕文件失败:', error instanceof Error ? error.message : error);
      return [];
    }
  }

  // 设置字幕数据
  private setSubtitles(items: SubtitleItem[]) {
    this.subtitles = items.sort((a, b) => a.startTimestampMillis - b.endTimestampMillis);
  }

  // 优化后的二分查找：找到第一个开始时间大于等于目标时间的索引
  private findFirstIndexAfter(time: number): number {
    let low = 0;
    let high = this.subtitles.length - 1;
    let result = this.subtitles.length;

    while (low <= high) {
      const mid = Math.floor((low + high) / 2);
      if (this.subtitles[mid].startTimestampMillis >= time) {
        result = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return result;
  }
}

export default new SubtitleUtil()