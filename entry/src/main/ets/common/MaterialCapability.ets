import { uiMaterial } from '@kit.ArkUI'
import { deviceInfo, SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import { hdsMaterial } from '@kit.UIDesignKit'
import { salmonLogger } from 'salmonlogger'

const TAG = 'MaterialCapability'

// 两套材质能力独立判断；设备能力固定，避免在组件构建时重复查询。
export class MaterialCapability {
  private static arkUICached: boolean | undefined = undefined
  private static hdsCached: boolean | undefined = undefined

  static get arkUISupported(): boolean {
    if (MaterialCapability.arkUICached === undefined) {
      MaterialCapability.arkUICached = false
      try {
        if (deviceInfo.apiAvailable('26.0.0')) {
          MaterialCapability.arkUICached = uiMaterial.isImmersiveMaterialSupported()
        }
      } catch (_error) {
        salmonLogger.addLog(TAG, '查询 ArkUI 沉浸材质能力失败，使用兼容样式', true)
      }
    }
    return MaterialCapability.arkUICached
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  static get hdsSupported(): boolean {
    if (MaterialCapability.hdsCached === undefined) {
      MaterialCapability.hdsCached = false
      try {
        if (deviceInfo.apiAvailable(23)) {
          MaterialCapability.hdsCached =
            hdsMaterial.getSystemMaterialTypes().includes(hdsMaterial.MaterialType.IMMERSIVE)
        }
      } catch (_error) {
        salmonLogger.addLog(TAG, '查询 HDS 沉浸材质能力失败，使用兼容样式', true)
      }
    }
    return MaterialCapability.hdsCached
  }
}
