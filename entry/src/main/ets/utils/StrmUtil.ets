import { fileIo as fs } from '@kit.CoreFileKit'
import { salmonLogger } from 'salmonlogger'
import TextEncodingUtil from './TextEncodingUtil'
import ToolsUtil from './ToolsUtil'

const TAG = 'StrmUtil'
const MAX_STRM_SIZE = 64 * 1024

export interface StrmImportResult {
  name: string
  url: string
}

/** Reads Kodi-style .strm shortcuts that contain one directly playable network URL. */
export default class StrmUtil {
  static async read(uri: string): Promise<StrmImportResult> {
    let file: fs.File | undefined = undefined
    try {
      file = await fs.open(uri, fs.OpenMode.READ_ONLY)
      const stat = await fs.stat(file.fd)
      if (stat.size <= 0) {
        throw new Error('.strm 文件为空')
      }
      if (stat.size > MAX_STRM_SIZE) {
        throw new Error('.strm 文件过大，最大支持 64 KB')
      }
      const buffer = new ArrayBuffer(stat.size)
      await fs.read(file.fd, buffer)
      const content = TextEncodingUtil.decodeMetadata(buffer)
      if (!content) {
        throw new Error('无法读取 .strm 文件内容')
      }
      return {
        name: StrmUtil.getDisplayName(uri),
        url: StrmUtil.parseUrl(content)
      }
    } catch (error) {
      const message = StrmUtil.errorMessage(error)
      salmonLogger.addLog(TAG, `读取 .strm 文件失败: ${message}`, true)
      throw new Error(message)
    } finally {
      if (file) {
        try {
          await fs.close(file)
        } catch (error) {
          salmonLogger.addLog(TAG, `关闭 .strm 文件失败: ${StrmUtil.errorMessage(error)}`, true)
        }
      }
    }
  }

  static parseUrl(content: string): string {
    const lines = content.replace(/^\uFEFF/, '').replace(/\r/g, '').split('\n')
    let unsupportedAddress = ''
    for (const line of lines) {
      const candidate = line.trim()
      if (!candidate || candidate.startsWith('#')) {
        continue
      }
      if (ToolsUtil.isNetworkUrl(candidate)) {
        return candidate
      }
      if (!unsupportedAddress) {
        unsupportedAddress = candidate
      }
    }
    if (unsupportedAddress.toLowerCase().startsWith('plugin://')) {
      throw new Error('暂不支持 plugin:// 类型的 .strm 地址')
    }
    throw new Error('.strm 中没有可播放的网络地址')
  }

  private static getDisplayName(uri: string): string {
    const decodedUri = ToolsUtil.safeDecodeURI(uri)
    const cleanUri = decodedUri.split('?')[0].split('#')[0]
    const fileName = cleanUri.slice(Math.max(cleanUri.lastIndexOf('/'), cleanUri.lastIndexOf('\\')) + 1)
    const displayName = fileName.replace(/\.strm$/i, '').trim()
    return displayName || '网络串流'
  }

  private static errorMessage(error: Object): string {
    if (error instanceof Error) {
      return error.message
    }
    return String(error)
  }
}
