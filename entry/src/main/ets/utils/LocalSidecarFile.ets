import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { salmonLogger } from 'salmonlogger'
import ToolsUtil from './ToolsUtil'

/** Bounded text reads, streaming copies and atomic replacement for local sidecars. */
export class LocalSidecarFile {
  private static sequence: number = 0

  static async copy(uri: string, path: string, cancelled: () => boolean): Promise<void> {
    let temporary: string | undefined
    let sourceToClose: fs.File | undefined
    let targetToClose: fs.File | undefined
    try {
      const directory = path.substring(0, path.lastIndexOf('/'))
      if (!LocalSidecarFile.directoryExists(directory)) {
        fs.mkdirSync(directory, true)
      }
      const source = await fs.open(uri, fs.OpenMode.READ_ONLY)
      sourceToClose = source
      const stat = await fs.stat(source.fd)
      if (stat.size <= 0) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.audio_external_empty').id))
      }
      temporary = `${path}.${Date.now()}-${++LocalSidecarFile.sequence}.tmp`
      const target = await fs.open(temporary, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
      targetToClose = target
      let copied = 0
      while (copied < stat.size) {
        if (cancelled()) {
          throw new Error(ToolsUtil.getStringResource($r('app.string.operation_cancelled').id))
        }
        const chunk = new ArrayBuffer(Math.min(262144, stat.size - copied))
        const count = await fs.read(source.fd, chunk)
        if (count <= 0) {
          throw new Error(ToolsUtil.getStringResource($r('app.string.sidecar_read_incomplete').id))
        }
        let written = 0
        while (written < count) {
          if (cancelled()) {
            throw new Error(ToolsUtil.getStringResource($r('app.string.operation_cancelled').id))
          }
          const length = await fs.write(target.fd, chunk.slice(written, count))
          if (length <= 0) {
            throw new Error(ToolsUtil.getStringResource($r('app.string.sidecar_write_incomplete').id))
          }
          written += length
        }
        copied += count
      }
      targetToClose = undefined
      await fs.close(target)
      sourceToClose = undefined
      await fs.close(source)
      if (cancelled()) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.operation_cancelled').id))
      }
      fs.renameSync(temporary, path)
    } catch (error) {
      await LocalSidecarFile.closeAfterFailure(targetToClose)
      await LocalSidecarFile.closeAfterFailure(sourceToClose)
      LocalSidecarFile.removeTemporary(temporary)
      throw error instanceof Error ? error : new Error(String(error))
    }
  }

  static async read(uri: string, maxBytes: number, cancelled: () => boolean,
    allowEmpty: boolean = false): Promise<Uint8Array> {
    let fileToClose: fs.File | undefined
    try {
      const file = await fs.open(uri, fs.OpenMode.READ_ONLY)
      fileToClose = file
      const stat = await fs.stat(file.fd)
      if (stat.size > maxBytes || (!allowEmpty && stat.size === 0)) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.sidecar_file_empty_or_large').id))
      }
      const bytes = new Uint8Array(stat.size)
      let offset = 0
      while (offset < bytes.length) {
        if (cancelled()) {
          throw new Error(ToolsUtil.getStringResource($r('app.string.operation_cancelled').id))
        }
        const chunk = new ArrayBuffer(Math.min(65536, bytes.length - offset))
        const count = await fs.read(file.fd, chunk)
        if (count <= 0) {
          throw new Error(ToolsUtil.getStringResource($r('app.string.sidecar_read_incomplete').id))
        }
        bytes.set(new Uint8Array(chunk, 0, count), offset)
        offset += count
      }
      fileToClose = undefined
      await fs.close(file)
      return bytes
    } catch (error) {
      await LocalSidecarFile.closeAfterFailure(fileToClose)
      throw error instanceof Error ? error : new Error(String(error))
    }
  }

  static async save(path: string, bytes: Uint8Array, cancelled: () => boolean): Promise<void> {
    let temporary: string | undefined
    let fileToClose: fs.File | undefined
    try {
      const directory = path.substring(0, path.lastIndexOf('/'))
      if (!LocalSidecarFile.directoryExists(directory)) {
        fs.mkdirSync(directory, true)
      }
      temporary = `${path}.${Date.now()}-${++LocalSidecarFile.sequence}.tmp`
      const file = await fs.open(temporary, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
      fileToClose = file
      let offset = 0
      while (offset < bytes.length) {
        if (cancelled()) {
          throw new Error(ToolsUtil.getStringResource($r('app.string.operation_cancelled').id))
        }
        const count = await fs.write(file.fd, bytes.slice(offset).buffer)
        if (count <= 0) {
          throw new Error(ToolsUtil.getStringResource($r('app.string.sidecar_write_incomplete').id))
        }
        offset += count
      }
      fileToClose = undefined
      await fs.close(file)
      if (cancelled()) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.operation_cancelled').id))
      }
      // No await between the final session check and the atomic commit.
      fs.renameSync(temporary, path)
    } catch (error) {
      await LocalSidecarFile.closeAfterFailure(fileToClose)
      LocalSidecarFile.removeTemporary(temporary)
      throw error instanceof Error ? error : new Error(String(error))
    }
  }

  private static directoryExists(path: string): boolean {
    try {
      return fs.accessSync(path)
    } catch (error) {
      if ((error as BusinessError)?.code === 13900002) {
        return false
      }
      throw error instanceof Error ? error : new Error(String(error))
    }
  }

  // Only handles that have not gone through close() reach this cleanup path.
  private static async closeAfterFailure(file: fs.File | undefined): Promise<void> {
    if (!file) {
      return
    }
    try {
      await fs.close(file)
    } catch (error) {
      const code = (error as BusinessError)?.code ?? 'unknown'
      salmonLogger.addLog('LocalSidecarFile', `关闭附件文件失败，错误码 ${code}`, true)
    }
  }

  private static removeTemporary(path: string | undefined): void {
    if (!path) {
      return
    }
    try {
      fs.unlinkSync(path)
    } catch (error) {
      const code = (error as BusinessError)?.code
      if (code !== 13900002) {
        salmonLogger.addLog('LocalSidecarFile', `清理临时附件失败，错误码 ${code ?? 'unknown'}`, true)
      }
    }
  }
}
