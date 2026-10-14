import { fileIo as fs } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { validateMpvConfig } from 'libmpvnative.so'
import PreferencesUtil from '../database/PreferencesUtil'
import { PathUtils } from './PathUtils'
import { LocalSidecarFile } from './LocalSidecarFile'
import ToolsUtil from './ToolsUtil'
import { salmonLogger } from 'salmonlogger'

export class MpvConfigStore {
  static readonly MAX_BYTES: number = 64 * 1024
  private static readonly ENABLED_KEY: string = 'mpv_custom_conf_enabled'

  private static path(): string {
    const context = PathUtils.appContext
    if (!context) throw new Error('Application context unavailable')
    return `${context.filesDir}/mpv.conf`
  }

  static enabled(): boolean {
    return PreferencesUtil.getPreferencesValue(PathUtils.appContext!, 'sweet_video',
      MpvConfigStore.ENABLED_KEY, false, true) as boolean
  }

  static setEnabled(enabled: boolean): void {
    if (enabled && (!fs.accessSync(MpvConfigStore.path()) || validateMpvConfig(MpvConfigStore.path()) < 0)) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.mpv_conf_invalid').id))
    }
    PreferencesUtil.putPreferencesValue(PathUtils.appContext!, 'sweet_video',
      MpvConfigStore.ENABLED_KEY, enabled, true)
  }

  static activePath(): string {
    try {
      const path = MpvConfigStore.path()
      return MpvConfigStore.enabled() && fs.accessSync(path) ? path : ''
    } catch (_error) {
      salmonLogger.addLog('MpvConf', 'Could not read custom configuration state; using defaults', true)
      return ''
    }
  }

  static read(): string {
    const path = MpvConfigStore.path()
    if (!fs.accessSync(path)) return ''
    if (fs.statSync(path).size > MpvConfigStore.MAX_BYTES) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.mpv_conf_limit').id))
    }
    return fs.readTextSync(path)
  }

  static async importFile(uri: string): Promise<string> {
    const bytes = await LocalSidecarFile.read(uri, MpvConfigStore.MAX_BYTES, () => false)
    return util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(bytes).replace(/^\uFEFF/, '')
  }

  static async save(text: string): Promise<void> {
    const normalized = text.replace(/^\uFEFF/, '')
    const bytes = new util.TextEncoder().encodeInto(normalized)
    if (bytes.length > MpvConfigStore.MAX_BYTES || normalized.includes('\0')) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.mpv_conf_limit').id))
    }
    const path = MpvConfigStore.path()
    const temporary = path + '.pending'
    try {
      await LocalSidecarFile.save(temporary, bytes, () => false)
      if (validateMpvConfig(temporary) < 0) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.mpv_conf_invalid').id))
      }
      // No await between validation and commit. Invalid drafts never replace the saved file.
      fs.renameSync(temporary, path)
    } finally {
      if (fs.accessSync(temporary)) fs.unlinkSync(temporary)
    }
  }
}
