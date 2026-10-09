import { fileIo as fs } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { BusinessError, zlib } from '@kit.BasicServicesKit'
import { salmonLogger } from 'salmonlogger'
import { PathUtils } from './PathUtils'
import PermissionUtil from './PermissionUtil'
import ToolsUtil from './ToolsUtil'
import TextEncodingUtil from './TextEncodingUtil'

const TAG = 'IPTVSourceReader'
export default class IPTVSourceReader {
  static async requestText(url: string, userAgent: string | undefined, maxSize: number): Promise<string> {
    if (!/^https?:\/\//i.test(url.trim())) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.iptv_source_type_unsupported').id))
    }
    return new Promise((resolve, reject) => {
      const request = http.createHttp()
      const headers: Record<string, string> = {}
      if (userAgent?.trim()) {
        headers['User-Agent'] = userAgent.trim()
      }
      request.request(url.trim(), {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 10000,
        readTimeout: 15000
      }, (error: BusinessError, response: http.HttpResponse) => {
        if (error) {
          request.destroy()
          reject(new Error(ToolsUtil.getStringResourceArgs($r('app.string.request_failed').id, error.message || error.code)))
          return
        }
        const code = response.responseCode
        if (code < 200 || code >= 300) {
          request.destroy()
          reject(new Error(`HTTP ${code}`))
          return
        }
        const buffer = response.result as ArrayBuffer
        if (buffer.byteLength > maxSize) {
          request.destroy()
          reject(new Error(ToolsUtil.getStringResource($r('app.string.file_too_large_stop').id)))
          return
        }
        IPTVSourceReader.decodeBuffer(buffer, maxSize).then((text: string) => {
          resolve(text)
        }).catch((decodeError: Error) => {
          reject(decodeError)
        }).finally(() => {
          request.destroy()
        })
      })
    })
  }

  static async readLocalText(uri: string, maxSize: number): Promise<string> {
    await PermissionUtil.activatePermission(uri)
    let file: fs.File | undefined = undefined
    try {
      file = await fs.open(uri, fs.OpenMode.READ_ONLY)
      const stat = await fs.stat(file.fd)
      const size = stat.size
      if (size > maxSize) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.file_too_large_stop').id))
      }
      const buffer = new ArrayBuffer(size)
      await fs.read(file.fd, buffer)
      return await IPTVSourceReader.decodeBuffer(buffer, maxSize)
    } catch (error) {
      salmonLogger.addLog(TAG, `readLocalText failed: ${IPTVSourceReader.errorMessage(error)}`, true)
      return ''
    } finally {
      if (file) {
        try {
          await fs.close(file)
        } catch (error) {
          salmonLogger.addLog(TAG, `Close local file failed: ${IPTVSourceReader.errorMessage(error)}`, true)
        }
      }
    }
  }

  private static async decodeBuffer(buffer: ArrayBuffer, maxSize: number): Promise<string> {
    const decodedBuffer = IPTVSourceReader.isGzipBuffer(buffer) ? await IPTVSourceReader.gunzipBuffer(buffer, maxSize) : buffer
    if (decodedBuffer.byteLength > maxSize) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.unzipped_too_large_stop').id))
    }
    const bytes = new Uint8Array(decodedBuffer)
    const detectedEncoding = TextEncodingUtil.detectBufferEncoding(decodedBuffer)
    const encoding = detectedEncoding || 'UTF-8'
    try {
      const decoder = util.TextDecoder.create(encoding, { ignoreBOM: true })
      return decoder.decodeToString(bytes, { stream: false })
    } catch (error) {
      salmonLogger.addLog(TAG, `Decode ${encoding} text failed, fallback to UTF-8: ${IPTVSourceReader.errorMessage(error)}`, true)
      const fallbackDecoder = util.TextDecoder.create('UTF-8', { ignoreBOM: true })
      return fallbackDecoder.decodeToString(bytes, { stream: false })
    }
  }

  private static isGzipBuffer(buffer: ArrayBuffer): boolean {
    const bytes = new Uint8Array(buffer)
    return bytes.length >= 2 && bytes[0] === 0x1F && bytes[1] === 0x8B
  }

  private static async gunzipBuffer(buffer: ArrayBuffer, maxSize: number): Promise<ArrayBuffer> {
    if (!PathUtils.tempPath) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.epg_cache_create_failed').id))
    }
    const tempPath = `${PathUtils.tempPath}/iptv_epg_${Date.now()}_${Math.floor(Math.random() * 1000000)}.gz`
    let gzip: zlib.GZip | undefined = undefined
    let opened = false
    try {
      const file = await fs.open(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      try {
        await fs.write(file.fd, buffer)
      } finally {
        try {
          await fs.close(file)
        } catch (error) {
          salmonLogger.addLog(TAG, `Close temp gzip file failed: ${IPTVSourceReader.errorMessage(error)}`, true)
        }
      }

      gzip = await zlib.createGZip()
      await gzip.gzopen(tempPath, 'rb')
      opened = true
      const chunks: ArrayBuffer[] = []
      let totalSize = 0
      const chunkSize = 64 * 1024
      while (true) {
        const chunk = new ArrayBuffer(chunkSize)
        const readSize = await gzip.gzfread(chunk, 1, chunkSize)
        if (readSize > 0) {
          totalSize += readSize
          if (totalSize > maxSize) {
            throw new Error(ToolsUtil.getStringResource($r('app.string.unzipped_too_large_stop').id))
          }
          chunks.push(chunk.slice(0, readSize))
        }
        if (readSize < chunkSize) {
          if (await gzip.gzeof() !== 0) {
            break
          }
          const gzipError = await gzip.gzerror()
          throw new Error(ToolsUtil.getStringResourceArgs($r('app.string.iptv_gzip_failed').id, gzipError.statusMsg || gzipError.status))
        }
      }

      const result = new ArrayBuffer(totalSize)
      const resultBytes = new Uint8Array(result)
      let offset = 0
      chunks.forEach(chunk => {
        const chunkBytes = new Uint8Array(chunk)
        resultBytes.set(chunkBytes, offset)
        offset += chunkBytes.length
      })
      salmonLogger.addLog(TAG, `Gzip decompressed: ${buffer.byteLength} -> ${result.byteLength} bytes`, false)
      return result
    } catch (error) {
      const message = IPTVSourceReader.errorMessage(error)
      salmonLogger.addLog(TAG, `Gzip decompressed error: ${message}`, true)
      throw new Error(message)
    } finally {
      if (opened && gzip) {
        try {
          await gzip.gzcloser()
        } catch (error) {
          salmonLogger.addLog(TAG, `Close gzip failed: ${IPTVSourceReader.errorMessage(error)}`, true)
        }
      }
      try {
        await fs.access(tempPath)
        await fs.unlink(tempPath)
      } catch (error) {
        salmonLogger.addLog(TAG, `Remove temp gzip file failed: ${IPTVSourceReader.errorMessage(error)}`, true)
      }
    }
  }

  private static errorMessage(error: Object): string {
    if (error instanceof Error) {
      return error.message
    }
    return String(error)
  }
}
