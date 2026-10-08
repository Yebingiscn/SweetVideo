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
        throw new Error(ToolsUtil.getStringResource($r('app.string.strm_empty').id))
      }
      if (stat.size > MAX_STRM_SIZE) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.strm_too_large').id))
      }
      const buffer = new ArrayBuffer(stat.size)
      await fs.read(file.fd, buffer)
      const content = TextEncodingUtil.decodeMetadata(buffer)
      if (!content) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.strm_read_failed').id))
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
      throw new Error(ToolsUtil.getStringResource($r('app.string.strm_plugin_unsupported').id))
    }
    throw new Error(ToolsUtil.getStringResource($r('app.string.strm_no_playable_url').id))
  }

  private static getDisplayName(uri: string): string {
    const decodedUri = ToolsUtil.safeDecodeURI(uri)
    const cleanUri = decodedUri.split('?')[0].split('#')[0]
    const fileName = cleanUri.slice(Math.max(cleanUri.lastIndexOf('/'), cleanUri.lastIndexOf('\\')) + 1)
    const displayName = fileName.replace(/\.strm$/i, '').trim()
    return displayName || ToolsUtil.getStringResource($r('app.string.network_stream_title').id)
  }

  private static errorMessage(error: Object): string {
    if (error instanceof Error) {
      return error.message
    }
    return String(error)
  }
}
