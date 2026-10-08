import { fileIo as fs, picker } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { PathUtils } from './PathUtils'
import { DANMAKU_MAX_BYTES, DanmakuItem, DanmakuParser } from './DanmakuCore'
import ToolsUtil from './ToolsUtil'
import { salmonLogger } from 'salmonlogger'
import { LocalSidecarFile } from './LocalSidecarFile'
import { DanmakuStorage } from './DanmakuStorage'
import { Setting } from './ObservedUtil'

/** Playback state backed by a sandbox XML file keyed by the video's stable ID. */
@ObservedV2
export class DanmakuSession {
  @Trace items: DanmakuItem[] = []
  @Trace enabled: boolean = true
  @Trace loading: boolean = false
  @Trace name: string = ''
  @Trace fontSize: number = Math.max(14, Math.min(48, Number(Setting.subtitleSize) || 22))
  @Trace opacity: number = 0.8
  @Trace area: number = 1
  @Trace offsetMs: number = 0
  private media: string = ''
  private generation: number = 0
  private disposed: boolean = false

  setMedia(media: string): void {
    if (this.media !== media) {
      this.media = media
      this.clear()
      if (media && !this.disposed) {
        this.restore(media, this.generation)
      }
    }
  }

  private async restore(media: string, generation: number): Promise<void> {
    const cancelled = (): boolean => this.disposed || this.generation !== generation || this.media !== media
    this.loading = true
    try {
      const path = DanmakuStorage.path(media)
      if (!fs.accessSync(path)) {
        return
      }
      const bytes = await LocalSidecarFile.read(path, DANMAKU_MAX_BYTES, cancelled)
      const text = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(bytes)
      const result = await DanmakuParser.parse(text, cancelled)
      if (!cancelled()) {
        this.items = result.items
        this.name = ToolsUtil.getStringResource($r('app.string.saved_danmaku_file_name').id)
      }
    } catch (error) {
      if (!cancelled()) {
        salmonLogger.addLog('Danmaku', '读取已保存的弹幕失败', true)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.saved_danmaku_read_failed').id))
      }
    } finally {
      if (!cancelled()) {
        this.loading = false
      }
    }
  }

  clear(): void {
    this.generation++
    this.loading = false
    this.items = []
    this.name = ''
    this.offsetMs = 0
  }

  dispose(): void {
    this.disposed = true
    this.clear()
  }

  async importFile(currentMedia: () => string): Promise<void> {
    if (this.disposed || this.loading || !currentMedia()) {
      return
    }
    const media = currentMedia()
    this.setMedia(media)
    const generation = ++this.generation
    this.loading = true
    const cancelled = (): boolean => this.disposed || generation !== this.generation || currentMedia() !== media
    try {
      const options = new picker.DocumentSelectOptions()
      options.fileSuffixFilters = [ToolsUtil.getStringResource($r('app.string.danmaku_filter_xml').id) + '|.xml']
      options.maxSelectNumber = 1
      const uris = await new picker.DocumentViewPicker(PathUtils.appContext!).select(options)
      if (uris.length === 0 || cancelled()) {
        return
      }
      const bytes = await LocalSidecarFile.read(uris[0], DANMAKU_MAX_BYTES, cancelled)
      const text = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(bytes)
      const result = await DanmakuParser.parse(text, cancelled)
      if (cancelled()) {
        return
      }
      await LocalSidecarFile.save(DanmakuStorage.path(media), bytes, cancelled)
      if (cancelled()) {
        return
      }
      this.items = result.items
      this.name = decodeURIComponent(uris[0].split('/').pop() || ToolsUtil.getStringResource($r('app.string.local_xml').id))
      this.offsetMs = 0
      this.enabled = true
      ToolsUtil.showToast(ToolsUtil.getStringResourceArgs($r('app.string.danmaku_imported_count').id, result.items.length) +
        (result.skipped > 0 ? ToolsUtil.getStringResourceArgs($r('app.string.danmaku_skipped_count').id, result.skipped) : ''))
    } catch (error) {
      if (!cancelled()) {
        // Do not expose a picked file URI or raw platform errors in logs/toasts.
        salmonLogger.addLog('Danmaku', '本地弹幕导入失败', true)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.danmaku_import_failed_format').id))
      }
    } finally {
      if (generation === this.generation) {
        this.loading = false
      }
    }
  }
}
