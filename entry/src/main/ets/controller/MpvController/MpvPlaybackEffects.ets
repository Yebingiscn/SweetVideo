import { command as mpvCommand, setGlslShaders as mpvSetGlslShaders } from 'libmpvnative.so'
import { fileIo } from '@kit.CoreFileKit'
import { salmonLogger } from 'salmonlogger'
import { AudioEffectConfig } from '../../interfaces/AudioEffectInterface'
import { PathUtils } from '../../utils/PathUtils'
import { Setting } from '../../utils/ObservedUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { MpvDecodingMethod } from './MpvTypes'

const TAG = 'MpvController'

interface MpvCommandResult {
  success: boolean
  code: number
  error?: string
}

class AudioEffectOption {
  name: string
  value: string

  constructor(name: string, value: string) {
    this.name = name
    this.value = value
  }
}

class ShaderConfig {
  rawDir: string
  files: string[]

  constructor(rawDir: string, files: string[]) {
    this.rawDir = rawDir
    this.files = files
  }
}

// 着色器链准备与音效命令批量应用；不持有原生播放器或注册回调。
export class MpvPlaybackEffects {
  private static readonly SHADER_MODE_NAMES: string[] = ['关闭', 'Anime4K (动漫)', 'ArtCNN (通用)']
  private static readonly SHADER_CONFIGS: Map<number, ShaderConfig> = new Map<number, ShaderConfig>([
    [1, new ShaderConfig(
      'shaders/Anime4K',
      [
        'Anime4K_Clamp_Highlights.glsl',
        'Anime4K_Restore_CNN_M.glsl',
        'Anime4K_Upscale_CNN_x2_M.glsl',
        'Anime4K_AutoDownscalePre_x2.glsl',
        'Anime4K_AutoDownscalePre_x4.glsl',
      ]
    )],
    [2, new ShaderConfig(
      'shaders/ArtCNN',
      ['ArtCNN_C4F16.glsl']
    )]
  ])
  private preparedShaderPaths: Map<number, string[]> = new Map()

  static getShaderModeNames(): string[] {
    return MpvPlaybackEffects.SHADER_MODE_NAMES
  }

  applyShaderMode(mode: number, handle: number | null): void {
    if (!handle) {
      return
    }
    if (mode > 0 && (Setting.mpvDecodingMethod === MpvDecodingMethod.HARDWARE_SURFACE ||
      Setting.mpvDecodingMethod === MpvDecodingMethod.SOFTWARE)) {
      Setting.mpvShaderMode = 0
      mpvSetGlslShaders([])
      return
    }
    if (mode === 0) {
      mpvSetGlslShaders([])
      return
    }
    const config = MpvPlaybackEffects.SHADER_CONFIGS.get(mode)
    if (!config) {
      return
    }
    const prepared = this.preparedShaderPaths.get(mode)
    let preparedAvailable = false
    try {
      preparedAvailable = prepared !== undefined && prepared.every((path: string) => fileIo.accessSync(path))
    } catch (_) {
      this.preparedShaderPaths.delete(mode)
    }
    if (prepared && preparedAvailable) {
      if (!mpvSetGlslShaders(prepared)) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.shader_load_failed_buffer_mode').id))
      }
      return
    }
    // Separate asset revision from legacy extracted shaders. Only prepare the
    // selected chain; changing modes must not eagerly compile every network.
    const sandboxDir = PathUtils.sandboxPath + '/shaders/gpu-v2/'
    try {
      fileIo.mkdirSync(sandboxDir, true)
    } catch (_) {
    }
    const shaderPaths: string[] = []
    for (const file of config.files) {
      const targetPath = sandboxDir + file
      let targetFd: fileIo.File | undefined = undefined
      try {
        const content = PathUtils.appContext!.resourceManager.getRawFileContentSync(config.rawDir + '/' + file)
        targetFd =
          fileIo.openSync(targetPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.READ_WRITE)
        const bytes = content.buffer.slice(content.byteOffset, content.byteOffset + content.byteLength)
        if (fileIo.writeSync(targetFd.fd, bytes) !== content.byteLength) {
          throw new Error('Incomplete shader write')
        }
        fileIo.closeSync(targetFd)
        targetFd = undefined
        shaderPaths.push(targetPath!)
      } catch (e) {
        salmonLogger.addLog(TAG, `Shader copy failed: ${file} ${e}`, true)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.shader_copy_failed').id))
        return // Never replace the active chain with a partially copied chain.
      } finally {
        if (targetFd) {
          try { fileIo.closeSync(targetFd) } catch (_) {}
        }
      }
    }
    if (shaderPaths.length > 0) {
      this.preparedShaderPaths.set(mode, shaderPaths)
      const result = mpvSetGlslShaders(shaderPaths)
      if (!result) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.shader_load_failed_buffer_mode').id))
      }
    } else {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.shader_copy_failed').id))
    }
  }

  static applyAudioEffect(handle: number, config: AudioEffectConfig): boolean {
    const options: AudioEffectOption[] = [
      new AudioEffectOption('ohaudio-suite-eq-preset', config.eqPreset),
      new AudioEffectOption('ohaudio-suite-eq-31', config.eqGains[0].toFixed(0)),
      new AudioEffectOption('ohaudio-suite-eq-62', config.eqGains[1].toFixed(0)),
      new AudioEffectOption('ohaudio-suite-eq-125', config.eqGains[2].toFixed(0)),
      new AudioEffectOption('ohaudio-suite-eq-250', config.eqGains[3].toFixed(0)),
      new AudioEffectOption('ohaudio-suite-eq-500', config.eqGains[4].toFixed(0)),
      new AudioEffectOption('ohaudio-suite-eq-1k', config.eqGains[5].toFixed(0)),
      new AudioEffectOption('ohaudio-suite-eq-2k', config.eqGains[6].toFixed(0)),
      new AudioEffectOption('ohaudio-suite-eq-4k', config.eqGains[7].toFixed(0)),
      new AudioEffectOption('ohaudio-suite-eq-8k', config.eqGains[8].toFixed(0)),
      new AudioEffectOption('ohaudio-suite-eq-16k', config.eqGains[9].toFixed(0)),
      new AudioEffectOption('ohaudio-suite-sound-field', config.soundField),
      new AudioEffectOption('ohaudio-suite-environment', config.environment),
      new AudioEffectOption('ohaudio-suite-beautifier', config.beautifier),
      new AudioEffectOption('ohaudio-suite-space-mode', config.spaceMode),
      new AudioEffectOption('ohaudio-suite-space-x', config.spaceX.toFixed(1)),
      new AudioEffectOption('ohaudio-suite-space-y', config.spaceY.toFixed(1)),
      new AudioEffectOption('ohaudio-suite-space-z', config.spaceZ.toFixed(1)),
      new AudioEffectOption('ohaudio-suite-space-time', config.spaceTime.toFixed(0)),
      new AudioEffectOption('ohaudio-suite-space-direction', config.spaceDirection),
      new AudioEffectOption('ohaudio-suite-space-radius', config.spaceRadius.toFixed(1)),
      new AudioEffectOption('ohaudio-suite-space-angle', config.spaceAngle.toFixed(0)),
      new AudioEffectOption('ohaudio-suite-pure-gender', config.pureGender),
      new AudioEffectOption('ohaudio-suite-pure-type', config.pureType),
      new AudioEffectOption('ohaudio-suite-pure-pitch', config.purePitch.toFixed(1)),
      new AudioEffectOption('ohaudio-suite-general-type', config.generalType),
      new AudioEffectOption('ohaudio-suite-tempo', config.tempo.toFixed(1)),
      new AudioEffectOption('ohaudio-suite-pitch', config.pitch.toFixed(1)),
      new AudioEffectOption('ohaudio-suite-separation-output', config.separationOutput),
      new AudioEffectOption('ohaudio-suite-hoa-layout', config.hoaLayout),
      // Set the selected effect last so an older libmpv fails before the AO is reloaded.
      new AudioEffectOption('ohaudio-suite-effect', config.effect)
    ]

    for (const option of options) {
      const result = mpvCommand(handle,
        ['set', `options/${option.name}`, option.value]) as MpvCommandResult
      if (!result?.success) {
        salmonLogger.addLog(TAG,
          `设置声音效果失败: ${option.name}=${option.value}, ${result?.error ?? result?.code ?? 'unknown'}`, true)
        return false
      }
    }

    const reloadResult = mpvCommand(handle, ['ao-reload']) as MpvCommandResult
    if (!reloadResult?.success) {
      salmonLogger.addLog(TAG, `重新加载音频输出失败: ${reloadResult?.error ?? reloadResult?.code ?? 'unknown'}`, true)
      return false
    }

    return true
  }
}
