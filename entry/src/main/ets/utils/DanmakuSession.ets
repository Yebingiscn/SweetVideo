import { fileIo as fs, picker } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { PathUtils } from './PathUtils'
import { DanmakuItem, DanmakuParser, DANMAKU_MAX_BYTES } from './DanmakuCore'
import ToolsUtil from './ToolsUtil'
import { salmonLogger } from 'salmonlogger'
import { LocalSidecarFile } from './LocalSidecarFile'
import { DanmakuStorage } from './DanmakuStorage'

/** Playback state backed by a sandbox XML file keyed by the video's stable ID. */
@ObservedV2
export class DanmakuSession {
  @Trace items: DanmakuItem[] = []
  @Trace enabled: boolean = true
  @Trace loading: boolean = false
  @Trace name: string = ''
  @Trace fontSize: number = 22
  @Trace opacity: number = 0.8
  @Trace area: number = 0.5
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
        this.name = '已保存的弹幕.xml'
      }
    } catch (error) {
      if (!cancelled()) {
        salmonLogger.addLog('Danmaku', '读取已保存的弹幕失败', true)
        ToolsUtil.showToast('已保存的弹幕读取失败，请重新导入')
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
      options.fileSuffixFilters = ['XML 弹幕|.xml']
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
      this.name = decodeURIComponent(uris[0].split('/').pop() || '本地 XML')
      this.offsetMs = 0
      this.enabled = true
      ToolsUtil.showToast(`已导入 ${result.items.length} 条弹幕` +
        (result.skipped > 0 ? `，跳过 ${result.skipped} 条不支持或无效弹幕` : ''))
    } catch (error) {
      if (!cancelled()) {
        // Do not expose a picked file URI or raw platform errors in logs/toasts.
        salmonLogger.addLog('Danmaku', '本地弹幕导入失败', true)
        ToolsUtil.showToast('导入失败，请选择 UTF-8 的 B 站 XML 弹幕（最多 50000 条）')
      }
    } finally {
      if (generation === this.generation) {
        this.loading = false
      }
    }
  }
}
