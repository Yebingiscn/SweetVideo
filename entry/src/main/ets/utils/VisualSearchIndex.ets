import { textSearchImage } from '@kit.CoreVisionKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { taskpool } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { VisualSearchHit, VisualSearchResult } from './GlobalSearchModel'

interface IndexedCover {
  path: string
  signature: string
}

class VisualSearchError extends Error {
  code: number

  constructor(error: BusinessError) {
    super(error.message)
    this.code = error.code
  }
}

// Worker-only module: no UI, Context, or application singletons.
export class VisualSearchIndex {
  static readonly scope: string = 'SweetVideoHome'

  static readManifest(path: string): IndexedCover[] {
    try {
      return JSON.parse(fs.readTextSync(path)) as IndexedCover[]
    } catch {
      return []
    }
  }

  static saveManifest(path: string, records: IndexedCover[]): void {
    const file = fs.openSync(path + '.tmp', fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
    try {
      fs.writeSync(file.fd, JSON.stringify(records))
    } finally {
      fs.closeSync(file)
    }
    fs.renameSync(path + '.tmp', path)
  }

  static signature(path: string): string {
    try {
      if (path.length > 128) {
        return ''
      }
      const stat = fs.statSync(path)
      return `${stat.size}:${stat.mtime}:${stat.ctime}`
    } catch {
      return ''
    }
  }

  static async validSize(path: string): Promise<boolean> {
    let source: image.ImageSource | undefined = undefined
    try {
      source = image.createImageSource(path)
      const info = await source.getImageInfo()
      return info.size.width > 100 && info.size.width < 10000 &&
        info.size.height > 100 && info.size.height < 10000
    } catch {
      return false
    } finally {
      source?.release()
    }
  }

  static async run(paths: string[], manifestPath: string, query: string): Promise<VisualSearchResult> {
    if (!await textSearchImage.init()) {
      throw new Error('画面搜索暂不可用，请稍后重试或使用按名称搜索')
    }
    try {
      // A model upgrade requires rebuilding features. Retry at most once.
      for (let attempt = 0; attempt < 2; attempt++) {
        try {
          return await VisualSearchIndex.synchronizeAndSearch(paths, manifestPath, query)
        } catch (error) {
          if ((error as BusinessError).code !== 1013100003 || attempt > 0) {
            throw new VisualSearchError(error as BusinessError)
          }
          if (!await textSearchImage.clearData()) {
            throw new Error('画面搜索更新失败，请稍后重试')
          }
          VisualSearchIndex.saveManifest(manifestPath, [])
        }
      }
      throw new Error('画面搜索更新失败')
    } finally {
      try {
        await textSearchImage.release()
      } catch {
        // Preserve the original search error if service teardown also fails.
      }
    }
  }

  static async synchronizeAndSearch(paths: string[], manifestPath: string,
    query: string): Promise<VisualSearchResult> {
    const previous = VisualSearchIndex.readManifest(manifestPath)
    const wanted = new Set<string>(paths)
    const records: IndexedCover[] = []
    const old = new Map<string, string>()
    for (const record of previous) {
      if (!wanted.has(record.path) || VisualSearchIndex.signature(record.path) !== record.signature) {
        if (!await textSearchImage.deleteImage(record.path, VisualSearchIndex.scope)) {
          throw new Error('画面索引更新失败，请重试')
        }
      } else {
        old.set(record.path, record.signature)
      }
    }
    // Persist removed records before processing replacements, so retries reinsert them.
    old.forEach((signature, path) => records.push({ path: path, signature: signature }))
    VisualSearchIndex.saveManifest(manifestPath, records)
    let skipped = 0
    for (let index = 0; index < paths.length; index++) {
      const path = paths[index]
      if (!old.has(path)) {
        const signature = VisualSearchIndex.signature(path)
        if (!signature || !await VisualSearchIndex.validSize(path)) {
          skipped++
        } else {
          try {
            if (await textSearchImage.insertImage(path, VisualSearchIndex.scope)) {
              records.push({ path: path, signature: signature })
            } else {
              skipped++
            }
          } catch (error) {
            if ((error as BusinessError).code !== 1013100001) {
              throw new VisualSearchError(error as BusinessError)
            }
            skipped++
          }
        }
      }
      if ((index + 1) % 10 === 0 || index === paths.length - 1) {
        VisualSearchIndex.saveManifest(manifestPath, records)
        taskpool.Task.sendData(index + 1, paths.length)
      }
    }
    if (records.length === 0) {
      return { hits: [], indexed: 0, skipped: skipped }
    }
    const results = await textSearchImage.search(query, VisualSearchIndex.scope, 100)
    return {
      hits: results.filter(hit => wanted.has(hit.imagePath))
        .sort((a, b) => b.similarity - a.similarity)
        .map((hit): VisualSearchHit => ({ imagePath: hit.imagePath, similarity: hit.similarity })),
      indexed: records.length,
      skipped: skipped
    }
  }
}
