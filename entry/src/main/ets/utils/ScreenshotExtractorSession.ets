import lazy { NetworkPlayback } from './NetworkPlayback'
import ToolsUtil from './ToolsUtil'
import { salmonLogger } from 'salmonlogger'

export interface ScreenshotExtractorFactory {
  create: (source: string, headers: Record<string, string> | undefined) => number
  release: (extractorId: number) => void
}

export interface ScreenshotExtractorOperation<T> {
  extract: (extractorId: number) => Promise<T>
  succeeded: (result: T) => boolean
  discard: (result: T) => Promise<void>
}

// At most one native decoder and one credential-bearing network session. The
// outer save queue releases this batch when empty; there is no idle/global cache.
export class ScreenshotExtractorSession {
  private source: string = ''
  private extractorId: number | undefined = undefined
  private network: NetworkPlayback | undefined = undefined
  private task: Promise<void> = Promise.resolve()
  private version: number = 0
  private factory: ScreenshotExtractorFactory

  constructor(factory: ScreenshotExtractorFactory) {
    this.factory = factory
  }

  async run<T>(uri: string, requestId: number, operation: ScreenshotExtractorOperation<T>): Promise<T> {
    const version = this.version
    const task = this.task.then(async (): Promise<T> => {
      try {
        if (version !== this.version) throw new Error('Screenshot session cancelled')
        const extractorId = await this.prepare(uri, requestId, version)
        if (version !== this.version) throw new Error('Screenshot session cancelled')
        const result = await operation.extract(extractorId)
        if (version !== this.version) {
          await operation.discard(result)
          throw new Error('Screenshot session cancelled')
        }
        if (!operation.succeeded(result)) this.close('extraction_failed', requestId)
        return result
      } catch (error) {
        this.close(version === this.version ? 'failed' : 'cancelled', requestId)
        // The caller records only a fixed error category, never this raw text.
        throw new Error(String(error))
      }
    })
    this.task = task.then((): void => {}, (): void => {})
    return await task
  }

  async release(): Promise<void> {
    // Invalidate work immediately, but do not close a decoder/network session
    // until any in-flight native extraction has settled and discarded its image.
    this.version++
    const task = this.task.then((): void => { this.close('batch_finished', 0) })
    this.task = task.then((): void => {}, (): void => {})
    await task
  }

  private async prepare(uri: string, requestId: number, version: number): Promise<number> {
    if (this.extractorId !== undefined && this.source === uri) {
      salmonLogger.addLog('FramePreviewSession', `[Screenshot#${requestId}] session=reuse extractor=${this.extractorId}`, false)
      return this.extractorId
    }
    this.close('source_changed', requestId)
    const network = new NetworkPlayback()
    this.network = network
    const startedAt = Date.now()
    salmonLogger.addLog('FramePreviewSession', `[Screenshot#${requestId}] stage=resolve_source event=begin ` +
      `network=${ToolsUtil.isNetworkUrl(uri)}`, false)
    const source = await network.resolve(uri)
    if (version !== this.version) throw new Error('Screenshot session cancelled')
    salmonLogger.addLog('FramePreviewSession', `[Screenshot#${requestId}] stage=resolve_source event=end ` +
      `elapsedMs=${Date.now() - startedAt}`, false)
    const createStartedAt = Date.now()
    salmonLogger.addLog('FramePreviewSession', `[Screenshot#${requestId}] stage=create_extractor event=begin ` +
      `network=${ToolsUtil.isNetworkUrl(source)}`, false)
    const extractorId = this.factory.create(source, network.headers())
    this.extractorId = extractorId
    this.source = uri
    salmonLogger.addLog('FramePreviewSession', `[Screenshot#${requestId}] stage=create_extractor event=end ` +
      `extractor=${extractorId}, elapsedMs=${Date.now() - createStartedAt}`, false)
    return extractorId
  }

  private close(reason: string, requestId: number): void {
    const extractorId = this.extractorId
    const network = this.network
    this.extractorId = undefined
    this.network = undefined
    this.source = ''
    if (extractorId === undefined && !network) return
    const startedAt = Date.now()
    salmonLogger.addLog('FramePreviewSession', `[Screenshot#${requestId}] stage=release_extractor event=begin ` +
      `extractor=${extractorId ?? 0}, reason=${reason}`, false)
    try {
      if (extractorId !== undefined) this.factory.release(extractorId)
    } catch (_) {
      salmonLogger.addLog('FramePreviewSession', `[Screenshot#${requestId}] native extractor release failed`, true)
    } finally {
      try {
        network?.close()
      } catch (_) {
        salmonLogger.addLog('FramePreviewSession', `[Screenshot#${requestId}] network session release failed`, true)
      }
    }
    salmonLogger.addLog('FramePreviewSession', `[Screenshot#${requestId}] stage=release_extractor event=end ` +
      `extractor=${extractorId ?? 0}, elapsedMs=${Date.now() - startedAt}`, false)
  }
}
