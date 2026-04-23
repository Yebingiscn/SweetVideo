import { dlpAntiPeep } from '@kit.DeviceSecurityKit'
import { salmonLogger } from 'salmonlogger'
import { WindowUtil } from './WindowUtil'
import { window } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'

const TAG = 'DlpAntiPeepUtil'

export default class DlpAntiPeepUtil {
  // 标识当前是否激活 AI 防窥
  private static isDlpAntiPeepStatus: boolean = false
  // 防窥状态变化回调
  private static onStatusChange = async (status: dlpAntiPeep.DlpAntiPeepStatus): Promise<void> => {
    if (canIUse('SystemCapability.Security.DlpAntiPeep')) {
      if (status === dlpAntiPeep.DlpAntiPeepStatus.PASS) { // 表示当前状态为无人窥视
        // 重置状态,允许下次窥屏时设置蒙层
        DlpAntiPeepUtil.isDlpAntiPeepStatus = false
      } else if (status === dlpAntiPeep.DlpAntiPeepStatus.HIDE) { // 表示有人在窥屏，应用可以进行隐私保护操作。
        // 只在未设置蒙层时调用一次,避免频繁调用影响用户体验
        if (!DlpAntiPeepUtil.isDlpAntiPeepStatus) {
          await this.setMaskLayer() // 拉起系统蒙层
        }
      }
    }
  }

  // 检查防窥保护开关并订阅通知
  static async checkDlpAntiPeepStatus() {
    if (canIUse('SystemCapability.Security.DlpAntiPeep')) {
      try {
        // 先取消之前的订阅,避免重复订阅
        try {
          dlpAntiPeep.off('dlpAntiPeep', DlpAntiPeepUtil.onStatusChange)
        } catch {
          // 忽略取消订阅时的错误
        }

        const isOpen = await dlpAntiPeep.isDlpAntiPeepSwitchOn()
        if (isOpen) {
          dlpAntiPeep.on('dlpAntiPeep', DlpAntiPeepUtil.onStatusChange)
        } else {
          // 开关未开启，引导用户设置
          if (!WindowUtil.windowClass) {
            salmonLogger.addLog(TAG, 'WindowUtil.windowClass is null', true)
            return
          }
          const context = WindowUtil.windowClass.getUIContext().getHostContext() as common.UIAbilityContext
          if (!context) {
            salmonLogger.addLog(TAG, 'Failed to get UIAbilityContext', true)
            return
          }
          const result = await dlpAntiPeep.requestAntiPeepOptions(context)
          if (result === dlpAntiPeep.AntiPeepOptionsResult.SUCCESS ||
            result === dlpAntiPeep.AntiPeepOptionsResult.ALREADY_ON) { // 表示防窥保护开关开启成功或已开启
            dlpAntiPeep.on('dlpAntiPeep', DlpAntiPeepUtil.onStatusChange)
          }
        }
      } catch (error) {
        salmonLogger.addLog(TAG, `Failed to init DlpAntiPeep. Code: ${error.code}, message: ${error.message}`, true)
      }
    }
  }

  // 取消订阅防窥保护通知
  static closeDlpAntiPeepStatus() {
    if (canIUse('SystemCapability.Security.DlpAntiPeep')) {
      try {
        dlpAntiPeep.off('dlpAntiPeep', DlpAntiPeepUtil.onStatusChange)
        DlpAntiPeepUtil.isDlpAntiPeepStatus = false
      } catch (error) {
        salmonLogger.addLog(TAG, `Failed to off DlpAntiPeep. Code: ${error.code}, message: ${error.message}`, true)
      }
    }
  }

  private static async setMaskLayer(): Promise<void> {
    if (canIUse("SystemCapability.Security.DlpAntiPeep")) {
      try {
        if (!WindowUtil.windowClass) {
          salmonLogger.addLog(TAG, 'WindowUtil.windowClass is null', true)
          return
        }
        const context = WindowUtil.windowClass.getUIContext().getHostContext() as common.UIAbilityContext
        if (!context) {
          salmonLogger.addLog(TAG, 'Failed to get UIAbilityContext', true)
          return
        }
        const windowClass = await window.getLastWindow(context)
        const windowId = windowClass.getWindowProperties().id
        await dlpAntiPeep.setAntiPeepMaskLayer(windowId)
        DlpAntiPeepUtil.isDlpAntiPeepStatus = true
      } catch (error) {
        salmonLogger.addLog(TAG, `Failed to set AntiPeep MaskLayer. Code: ${error.code}, message: ${error.message}`,
          true)
      }
    } else {
      // Fallback: 系统不支持防窥功能,可以考虑其他保护方案
      salmonLogger.addLog(TAG, 'SystemCapability.Security.DlpAntiPeep not supported', false)
    }
  }
}