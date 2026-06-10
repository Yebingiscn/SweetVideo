/**
 * ISO镜像文件处理工具类
 * 支持蓝光(BDMV)和DVD(VIDEO_TS)格式的ISO文件播放
 *
 * 使用方法：
 * MPV播放ISO文件需要使用 bd:// 协议：
 * mpv --bluray-device=/path/to/file.iso bd://longest
 */
import { salmonLogger } from "salmonlogger";
import ToolsUtil from "./ToolsUtil";
import fileIo from "@ohos.file.fs";

const TAG = 'IsoFileUtil';

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

      // 默认返回蓝光类型，MPV会自动检测
      // 如果蓝光播放失败，可以尝试DVD格式
      salmonLogger.addLog(TAG, 'ISO文件将使用bd://协议播放（如失败可尝试dvd://）', false)
      return IsoFileType.BLURAY

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
