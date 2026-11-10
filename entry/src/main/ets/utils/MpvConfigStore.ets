import { BusinessError } from '@kit.BasicServicesKit'
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
  private static saveSequence: number = 0

  private static path(): string {
    const context = PathUtils.appContext
    if (!context) {
      throw new Error('Application context unavailable')
    }
    return `${context.filesDir}/mpv.conf`
  }

  static enabled(): boolean {
    return PreferencesUtil.getPreferencesValue(PathUtils.appContext!, 'sweet_video',
      MpvConfigStore.ENABLED_KEY, false, true) as boolean
  }

  static setEnabled(enabled: boolean): void {
    try {
      if (enabled) {
        const path = MpvConfigStore.path()
        if (!fs.accessSync(path) || (fs.statSync(path).size > 0 && validateMpvConfig(path) < 0)) {
          throw new Error(ToolsUtil.getStringResource($r('app.string.mpv_conf_invalid').id))
        }
      }
      PreferencesUtil.putPreferencesValue(PathUtils.appContext!, 'sweet_video',
        MpvConfigStore.ENABLED_KEY, enabled, true)
    } catch (error) {
      throw error instanceof Error ? error : new Error(String(error))
    }
  }

  static activePath(): string {
    try {
      const path = MpvConfigStore.path()
      return MpvConfigStore.enabled() && fs.accessSync(path) && fs.statSync(path).size > 0 ? path : ''
    } catch (_error) {
      salmonLogger.addLog('MpvConf', 'Could not read custom configuration state; using defaults', true)
      return ''
    }
  }

  static read(): string {
    try {
      const path = MpvConfigStore.path()
      if (!fs.accessSync(path)) {
        return ''
      }
      const size = fs.statSync(path).size
      if (size === 0) {
        return ''
      }
      if (size > MpvConfigStore.MAX_BYTES) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.mpv_conf_limit').id))
      }
      return fs.readTextSync(path)
    } catch (error) {
      if ((error as BusinessError)?.code === 13900002) {
        return ''
      }
      throw error instanceof Error ? error : new Error(String(error))
    }
  }

  static async importFile(uri: string): Promise<string> {
    const bytes = await LocalSidecarFile.read(uri, MpvConfigStore.MAX_BYTES, () => false, true)
    if (bytes.length === 0) {
      return ''
    }
    return util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(bytes).replace(/^\uFEFF/, '')
  }

  static async save(text: string): Promise<void> {
    const normalized = text.replace(/^\uFEFF/, '')
    // HarmonyOS TextEncoder.encodeInto returns undefined for an empty string.
    const bytes = normalized.length === 0 ? new Uint8Array(0) : new util.TextEncoder().encodeInto(normalized)
    if (bytes.length > MpvConfigStore.MAX_BYTES || normalized.includes('\0')) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.mpv_conf_limit').id))
    }
    const path = MpvConfigStore.path()
    const temporary = `${path}.${Date.now()}-${++MpvConfigStore.saveSequence}.pending`
    try {
      await LocalSidecarFile.save(temporary, bytes, () => false)
      if (bytes.length > 0 && validateMpvConfig(temporary) < 0) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.mpv_conf_invalid').id))
      }
      // No await between validation and commit. Invalid drafts never replace the saved file.
      fs.renameSync(temporary, path)
    } catch (error) {
      try {
        fs.unlinkSync(temporary)
      } catch (cleanupError) {
        const code = (cleanupError as BusinessError)?.code
        if (code !== 13900002) {
          salmonLogger.addLog('MpvConf', `Could not remove pending configuration, code=${code ?? 'unknown'}`, true)
        }
      }
      throw error instanceof Error ? error : new Error(String(error))
    }
  }
}
