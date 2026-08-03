/**
 * ISO镜像文件处理工具类
 * 支持蓝光(BDMV)和DVD(VIDEO_TS)格式的ISO文件播放
 *
 * 使用方法：
 * MPV播放ISO文件需要使用 bd:// 协议：
 * mpv --bluray-device=/path/to/file.iso bd://longest
 */
import { salmonLogger } from 'salmonlogger';
import ToolsUtil from './ToolsUtil';
import fileIo from '@ohos.file.fs';

const TAG = 'IsoFileUtil';
const ISO_SCAN_CHUNK_SIZE: number = 1024 * 1024;
const ISO_SCAN_LIMIT: number = 64 * 1024 * 1024;

/**
 * ISO文件类型枚举
 */
export enum IsoFileType {
  BLURAY = 'bluray', // 蓝光光盘 (BDMV)
  DVD = 'dvd', // DVD光盘 (VIDEO_TS)
  UNKNOWN = 'unknown' // 未知类型
}

/**
 * ISO文件信息接口
 */
export interface IsoFileInfo {
  type: IsoFileType // ISO类型
  originalPath: string // 原始ISO文件路径
  playablePath: string // 可播放路径 (bd://longest)
  title?: string // 光盘标题
  hasMenu: boolean // 是否有菜单
}

/**
 * ISO文件处理工具类
 */
export default class IsoFileUtil {
  /**
   * 在ISO/UDF目录数据中匹配ASCII标记。返回-1表示已经完整匹配。
   * matched参数用于保留跨读取块的部分匹配状态。
   */
  private static scanMarker(bytes: Uint8Array, length: number, marker: string, matched: number): number {
    for (let index = 0; index < length; index++) {
      let value = bytes[index]
      if (value >= 97 && value <= 122) {
        value -= 32
      }

      const expected = marker.charCodeAt(matched)
      if (value === expected) {
        matched++
        if (matched === marker.length) {
          return -1
        }
      } else {
        matched = value === marker.charCodeAt(0) ? 1 : 0
      }
    }
    return matched
  }

  /**
   * 同步识别ISO镜像类型。
   *
   * UDF/ISO目录记录会保存BDMV或VIDEO_TS名称。这里只扫描镜像前64 MiB，
   * 避免为了识别类型读取整个大型镜像。
   */
  static detectIsoTypeSync(isoPath: string): IsoFileType {
    let file: fileIo.File | undefined
    try {
      salmonLogger.addLog(TAG, `开始识别ISO类型: ${isoPath}`, false)
      file = fileIo.openSync(isoPath, fileIo.OpenMode.READ_ONLY)
      const fileSize = fileIo.statSync(file.fd).size
      const scanSize = Math.min(fileSize, ISO_SCAN_LIMIT)
      const buffer = new ArrayBuffer(ISO_SCAN_CHUNK_SIZE)
      const bytes = new Uint8Array(buffer)
      let scanned = 0
      let blurayMatched = 0
      let dvdMatched = 0

      while (scanned < scanSize) {
        const requested = Math.min(ISO_SCAN_CHUNK_SIZE, scanSize - scanned)
        const bytesRead = fileIo.readSync(file.fd, buffer, { length: requested })
        if (bytesRead <= 0) {
          break
        }

        blurayMatched = IsoFileUtil.scanMarker(bytes, bytesRead, 'BDMV', blurayMatched)
        if (blurayMatched === -1) {
          salmonLogger.addLog(TAG, `ISO识别为Blu-ray，找到BDMV标记，已扫描${scanned + bytesRead}字节`, false)
          return IsoFileType.BLURAY
        }

        dvdMatched = IsoFileUtil.scanMarker(bytes, bytesRead, 'VIDEO_TS', dvdMatched)
        if (dvdMatched === -1) {
          salmonLogger.addLog(TAG, `ISO识别为DVD，找到VIDEO_TS标记，已扫描${scanned + bytesRead}字节`, false)
          return IsoFileType.DVD
        }
        scanned += bytesRead
      }

      const lowerPath = isoPath.toLowerCase()
      if (lowerPath.includes('dvd') || lowerPath.includes('video_ts')) {
        salmonLogger.addLog(TAG, 'ISO目录标记未找到，根据文件名识别为DVD', true)
        return IsoFileType.DVD
      }
      if (lowerPath.includes('bluray') || lowerPath.includes('blu-ray') || lowerPath.includes('bdmv')) {
        salmonLogger.addLog(TAG, 'ISO目录标记未找到，根据文件名识别为Blu-ray', true)
        return IsoFileType.BLURAY
      }

      salmonLogger.addLog(TAG, `扫描${scanned}字节后仍无法识别ISO类型`, true)
      return IsoFileType.UNKNOWN
    } catch (error) {
      salmonLogger.addLog(TAG, `读取ISO并识别类型失败: ${error}`, true)
      return IsoFileType.UNKNOWN
    } finally {
      if (file) {
        try {
          fileIo.closeSync(file)
        } catch (error) {
          salmonLogger.addLog(TAG, `关闭ISO文件失败: ${error}`, true)
        }
      }
    }
  }

  /**
   * 检测ISO文件类型
   * @param isoPath ISO文件路径
   * @returns ISO文件类型
   */
  static async detectIsoType(isoPath: string): Promise<IsoFileType> {
    try {
      salmonLogger.addLog(TAG, `检测ISO文件类型: ${isoPath}`, false)

      // 获取文件扩展名
      const extension = isoPath.toLowerCase().split('.').pop()
      if (extension !== 'iso') {
        salmonLogger.addLog(TAG, '文件不是ISO格式', true)
        return IsoFileType.UNKNOWN
      }

      return IsoFileUtil.detectIsoTypeSync(isoPath)

    } catch (error) {
      salmonLogger.addLog(TAG, `检测ISO类型失败: ${error}`, true)
      return IsoFileType.UNKNOWN
    }
  }

  /**
   * 获取ISO文件的可播放路径
   * @param isoPath ISO文件路径
   * @param type ISO文件类型（可选）
   * @returns 可播放路径 (bd://longest 或 dvd://)
   */
  static async getPlayablePath(isoPath: string, type?: IsoFileType): Promise<string> {
    try {
      salmonLogger.addLog(TAG, `获取ISO可播放路径: ${isoPath}`, false)

      // 根据类型选择协议
      const isoType = type || await IsoFileUtil.detectIsoType(isoPath)

      let playablePath: string
      if (isoType === IsoFileType.DVD) {
        // DVD使用 dvd:// 协议
        playablePath = 'dvd://'
        salmonLogger.addLog(TAG, `使用DVD协议: ${playablePath}`, false)
      } else {
        // 蓝光使用 bd:// 协议
        // bd://longest 表示播放最长的标题（通常是主电影）
        playablePath = 'bd://longest'
        salmonLogger.addLog(TAG, `使用蓝光协议: ${playablePath}`, false)
      }

      return playablePath

    } catch (error) {
      salmonLogger.addLog(TAG, `获取ISO可播放路径失败: ${error}`, true)
      return 'bd://longest'
    }
  }

  /**
   * 获取ISO文件信息
   * @param isoPath ISO文件路径
   * @returns ISO文件信息
   */
  static async getIsoInfo(isoPath: string): Promise<IsoFileInfo | null> {
    try {
      const type = await IsoFileUtil.detectIsoType(isoPath);
      const playablePath = await IsoFileUtil.getPlayablePath(isoPath);

      // 从文件名提取标题
      const fileName = isoPath.split('/').pop() || ''
      const title = fileName.replace(/\.[^/.]+$/, '') // 移除扩展名

      return {
        type: type,
        originalPath: isoPath,
        playablePath: playablePath,
        title: title,
        hasMenu: true // 假设光盘都有菜单
      };

    } catch (error) {
      salmonLogger.addLog(TAG, `获取ISO信息失败: ${error}`, true)
      return null
    }
  }

  /**
   * 检查文件是否为ISO文件
   * @param filePath 文件路径
   * @returns 是否为ISO文件
   */
  static isIsoFile(filePath: string): boolean {
    const extension = filePath.toLowerCase().split('.').pop()
    return extension === 'iso'
  }

  /**
   * 获取ISO文件大小
   * @param isoPath ISO文件路径
   * @returns 文件大小(字节)
   */
  static async getIsoSize(isoPath: string): Promise<number> {
    try {
      const stat = await fileIo.stat(isoPath)
      return stat.size
    } catch (error) {
      salmonLogger.addLog(TAG, `获取ISO文件大小失败: ${error}`, true)
      return 0
    }
  }

  /**
   * 格式化ISO文件大小显示
   * @param bytes 字节数
   * @returns 格式化字符串
   */
  static formatIsoSize(bytes: number): string {
    return ToolsUtil.formatFileSize(bytes)
  }
}
