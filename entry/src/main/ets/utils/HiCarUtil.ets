import { smartMobilityCommon } from '@kit.CarKit'
import { deviceInfo } from '@kit.BasicServicesKit'
import { salmonLogger } from 'salmonlogger'
import Preferences from '../database/Preferences'
import { common } from '@kit.AbilityKit'

@ObservedV2
export class HiCarState {
  @Trace enabled: boolean = false
  @Trace manual: boolean = false
  @Trace leftInset: number = 0
  @Trace rightInset: number = 0
  @Trace topInset: number = 0
  @Trace bottomInset: number = 0
}

export const HiCar = new HiCarState()

export default class HiCarUtil {
  private static awareness: smartMobilityCommon.SmartMobilityAwareness | undefined = undefined
  private static connected: boolean = false
  private static acceptingStatus: boolean = false

  static start(context: common.UIAbilityContext): void {
    HiCar.manual = Preferences.getHiCarLayout(context)
    HiCarUtil.updateEnabled()
    if (HiCarUtil.awareness) {
      return
    }
    if (canIUse('SystemCapability.CarService.DistributedEngine')) {
      try {
        const awareness = smartMobilityCommon.getSmartMobilityAwareness()
        HiCarUtil.acceptingStatus = true
        awareness.on('smartMobilityStatus', [smartMobilityCommon.SmartMobilityType.HICAR], HiCarUtil.onStatus)
        HiCarUtil.awareness = awareness
        HiCarUtil.refresh()
      } catch (error) {
        HiCarUtil.acceptingStatus = false
        // 权限或能力不可用时仍可从界面设置手动启用布局。
        salmonLogger.addLog('HiCar', `连接状态监听不可用: ${(error as BusinessError).code}`, true)
      }
    }
  }

  static refresh(): void {
    if (canIUse('SystemCapability.CarService.DistributedEngine')) {
      try {
        if (HiCarUtil.awareness) {
          HiCarUtil.onStatus(HiCarUtil.awareness.getSmartMobilityStatus(smartMobilityCommon.SmartMobilityType.HICAR))
        }
      } catch (error) {
        salmonLogger.addLog('HiCar', `读取连接状态失败: ${(error as BusinessError).code}`, true)
      }
    }
  }

  static setManual(context: common.UIAbilityContext, enabled: boolean): void {
    Preferences.saveHiCarLayout(context, enabled)
    HiCar.manual = enabled
    HiCarUtil.updateEnabled()
  }

  static stop(): void {
    if (canIUse('SystemCapability.CarService.DistributedEngine')) {
      HiCarUtil.acceptingStatus = false
      try {
        HiCarUtil.awareness?.off('smartMobilityStatus',
          [smartMobilityCommon.SmartMobilityType.HICAR], HiCarUtil.onStatus)
      } catch (error) {
        salmonLogger.addLog('HiCar', `移除连接状态监听失败: ${(error as BusinessError).code}`, true)
      }
      HiCarUtil.awareness = undefined
      HiCarUtil.connected = false
      HiCarUtil.updateEnabled()
    }
  }

  private static readonly onStatus = (info: smartMobilityCommon.SmartMobilityInfo): void => {
    if (!HiCarUtil.acceptingStatus) {
      return
    }
    if (canIUse('SystemCapability.CarService.DistributedEngine')) {
      HiCarUtil.connected = info.status === smartMobilityCommon.SmartMobilityStatus.RUNNING
      HiCarUtil.updateEnabled()
    }
  }

  private static updateEnabled(): void {
    HiCar.enabled = HiCar.manual || HiCarUtil.connected || deviceInfo.deviceType === 'car'
  }
}
