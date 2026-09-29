import { fileIo as fs } from '@kit.CoreFileKit'

/** Bounded reads and atomic replacement for user-selected text sidecars. */
export class LocalSidecarFile {
  private static sequence: number = 0

  static async read(uri: string, maxBytes: number, cancelled: () => boolean): Promise<Uint8Array> {
    const file = await fs.open(uri, fs.OpenMode.READ_ONLY)
    try {
      const stat = await fs.stat(file.fd)
      if (stat.size <= 0 || stat.size > maxBytes) {
        throw new Error('文件为空或过大')
      }
      const bytes = new Uint8Array(stat.size)
      let offset = 0
      while (offset < bytes.length) {
        if (cancelled()) {
          throw new Error('操作已取消')
        }
        const chunk = new ArrayBuffer(Math.min(65536, bytes.length - offset))
        const count = await fs.read(file.fd, chunk)
        if (count <= 0) {
          throw new Error('文件读取不完整')
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
            throw new Error('操作已取消')
          }
          const count = await fs.write(file.fd, bytes.slice(offset).buffer)
          if (count <= 0) {
            throw new Error('文件写入不完整')
          }
          offset += count
        }
      } finally {
        await fs.close(file)
      }
      if (cancelled()) {
        throw new Error('操作已取消')
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
