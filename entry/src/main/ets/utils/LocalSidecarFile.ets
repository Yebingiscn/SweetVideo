import { fileIo as fs } from '@kit.CoreFileKit'
import ToolsUtil from './ToolsUtil.ets'

/** Bounded text reads, streaming copies and atomic replacement for local sidecars. */
export class LocalSidecarFile {
  private static sequence: number = 0

  static async copy(uri: string, path: string, cancelled: () => boolean): Promise<void> {
    const directory = path.substring(0, path.lastIndexOf('/'))
    if (!fs.accessSync(directory)) fs.mkdirSync(directory, true)
    const temporary = `${path}.${Date.now()}-${++LocalSidecarFile.sequence}.tmp`
    try {
      const source = await fs.open(uri, fs.OpenMode.READ_ONLY)
      try {
        const stat = await fs.stat(source.fd)
        if (stat.size <= 0) throw new Error(ToolsUtil.getStringResource($r('app.string.audio_external_empty').id))
        const target = await fs.open(temporary, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
        try {
          let copied = 0
          while (copied < stat.size) {
            if (cancelled()) throw new Error(ToolsUtil.getStringResource($r('app.string.operation_cancelled').id))
            const chunk = new ArrayBuffer(Math.min(262144, stat.size - copied))
            const count = await fs.read(source.fd, chunk)
            if (count <= 0) throw new Error(ToolsUtil.getStringResource($r('app.string.sidecar_read_incomplete').id))
            let written = 0
            while (written < count) {
              if (cancelled()) throw new Error(ToolsUtil.getStringResource($r('app.string.operation_cancelled').id))
              const length = await fs.write(target.fd, chunk.slice(written, count))
              if (length <= 0) throw new Error(ToolsUtil.getStringResource($r('app.string.sidecar_write_incomplete').id))
              written += length
            }
            copied += count
          }
        } finally { await fs.close(target) }
      } finally { await fs.close(source) }
      if (cancelled()) throw new Error(ToolsUtil.getStringResource($r('app.string.operation_cancelled').id))
      fs.renameSync(temporary, path)
    } finally {
      if (fs.accessSync(temporary)) fs.unlinkSync(temporary)
    }
  }

  static async read(uri: string, maxBytes: number, cancelled: () => boolean): Promise<Uint8Array> {
    const file = await fs.open(uri, fs.OpenMode.READ_ONLY)
    try {
      const stat = await fs.stat(file.fd)
      if (stat.size <= 0 || stat.size > maxBytes) {
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
      return bytes
    } finally {
      await fs.close(file)
    }
  }

  static async save(path: string, bytes: Uint8Array, cancelled: () => boolean): Promise<void> {
    const directory = path.substring(0, path.lastIndexOf('/'))
    if (!fs.accessSync(directory)) {
      fs.mkdirSync(directory, true)
    }
    const temporary = `${path}.${Date.now()}-${++LocalSidecarFile.sequence}.tmp`
    try {
      const file = await fs.open(temporary, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
      try {
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
      } finally {
        await fs.close(file)
      }
      if (cancelled()) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.operation_cancelled').id))
      }
      // No await between the final session check and the atomic commit.
      fs.renameSync(temporary, path)
    } finally {
      if (fs.accessSync(temporary)) {
        fs.unlinkSync(temporary)
      }
    }
  }
}
