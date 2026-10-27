import { fileIo as fs, fileUri } from '@kit.CoreFileKit';

export interface BluRayFolderEntry {
  name: string;
  directory: boolean
}

export interface BluRayDisc {
  rootPath: string
  rootUri: string
  indexUri: string
  title: string
}

// A disc is represented by its canonical index URI, not by an arbitrary M2TS clip.
export default class BluRayDirectory {
  static isEntry(uri: string): boolean {
    return (uri.startsWith('file://') || BluRayDirectory.isRemoteEntry(uri)) && /\/BDMV\/index\.bdmv$/i.test(uri)
  }

  static isRemoteEntry(uri: string): boolean {
    return /^(smb|webdav):\/\/[0-9a-f-]{36}\/(?:[^/]+\/)*BDMV\/index\.bdmv$/i.test(uri)
  }

  static networkIndexPath(folder: string, entries: BluRayFolderEntry[]): string | undefined {
    if (entries.some((e: BluRayFolderEntry) => e.directory && e.name === 'BDMV')) {
      return (folder ? folder + '/' : '') + 'BDMV/index.bdmv'
    }
    if (/(^|\/)BDMV$/.test(folder) && entries.some((e: BluRayFolderEntry) => !e.directory && e.name === 'index.bdmv')) {
      return folder + '/index.bdmv'
    }
    return undefined
  }

  static rootUri(uri: string): string {
    return uri.replace(/\/BDMV\/index\.bdmv$/i, '')
  }

  static inspect(uri: string): BluRayDisc | undefined {
    try {
      if (uri.includes('://') && !uri.startsWith('file://')) {
        return undefined
      }
      const local = uri.startsWith('file://') ? new fileUri.FileUri(uri).path : uri
      const path = local.replace(/\/+$/, '')
      const explicit = /\/BDMV(?:\/index\.bdmv)?$/i.test(path)
      const rootPath = path.replace(/\/BDMV(?:\/index\.bdmv)?$/i, '')
      const bdmv = `${rootPath}/BDMV`
      if (!explicit && !fs.accessSync(bdmv)) {
        return undefined
      }
      if (!fs.statSync(bdmv).isDirectory() ||
        !fs.statSync(`${bdmv}/PLAYLIST`).isDirectory() || !fs.statSync(`${bdmv}/STREAM`).isDirectory()) {
        throw new Error('Incomplete Blu-ray directory')
      }
      const index = fs.openSync(`${bdmv}/index.bdmv`, fs.OpenMode.READ_ONLY)
      try {
        const header = new ArrayBuffer(8)
        const read = fs.readSync(index.fd, header)
        const bytes = new Uint8Array(header)
        if (read !== 8 || bytes[0] !== 73 || bytes[1] !== 78 || bytes[2] !== 68 || bytes[3] !== 88) {
          throw new Error('Invalid Blu-ray index')
        }
      } finally {
        fs.closeSync(index)
      }
      // Check native filesystem access to sibling files, not only the selected index URI.
      BluRayDirectory.checkReadableChild(`${bdmv}/PLAYLIST`, '.mpls')
      BluRayDirectory.checkReadableChild(`${bdmv}/STREAM`, '.m2ts')
      const rootUri = uri.startsWith('file://') ? uri.replace(/\/+$/, '')
        .replace(/\/BDMV(?:\/index\.bdmv)?$/i, '') : fileUri.getUriFromPath(rootPath)
      return {
        rootPath: rootPath,
        rootUri: rootUri,
        indexUri: `${rootUri}/BDMV/index.bdmv`,
        title: rootPath.substring(rootPath.lastIndexOf('/') + 1) || 'Blu-ray'
      }
    } catch (error) {
      throw new Error((error as Error).message || 'Failed to inspect Blu-ray directory')
    }
  }

  private static checkReadableChild(directory: string, extension: string): void {
    try {
      const name = fs.listFileSync(directory).find((entry: string) => entry.toLowerCase().endsWith(extension))
      if (!name) {
        throw new Error('Missing Blu-ray playlist or stream')
      }
      const file = fs.openSync(`${directory}/${name}`, fs.OpenMode.READ_ONLY)
      try {
        if (fs.readSync(file.fd, new ArrayBuffer(1)) !== 1) {
          throw new Error('Empty Blu-ray file')
        }
      } finally {
        fs.closeSync(file)
      }
    } catch (error) {
      throw new Error((error as Error).message || 'Failed to read Blu-ray child file')
    }
  }
}
