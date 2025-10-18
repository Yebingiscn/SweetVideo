import VideoInfoUtil from './VideoInfoUtil';
import ToolsUtil from './ToolsUtil';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PathUtils } from './PathUtils';
import { AssEvent, ParseAss } from '@dove/subtitles';

class SubtitleUtil {
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

  async parseSrtFile(filePath: string) {
    // 1. 创建解析器实例
    const parser = new ParseAss(filePath);

    try {
      // 2. 初始化解析器（异步操作）
      await parser.init();
      console.error('test SRT解析器初始化成功');

      // 3. 读取字幕行（异步操作）
      const srtLines: AssEvent[] = await parser.readEvents();
      console.error(`test 成功读取 ${srtLines.length} 条字幕记录`);

      // 4. 处理结果（示例：打印前5条）
      srtLines.slice(0, 5).forEach(line => {
        console.error(`[${line.start} -> ${line.end}] ${line.text}`);
      });

      return srtLines;
    } catch (error) {
      // 错误处理
      console.error('test 解析SRT文件失败:', error instanceof Error ? error.message : error);
      return []
    }
  }
}

export default new SubtitleUtil()