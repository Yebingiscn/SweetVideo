import { motion } from '@kit.MultimodalAwarenessKit';

export default class IntellectualGripPostureUtil {
  private static operatingHandCallback: Callback<motion.OperatingHandStatus> | null = null
  private static holdingHandCallback: Callback<motion.HoldingHandStatus> | null = null

  static createOperatingHandStatus(callback?: Callback<motion.OperatingHandStatus>) {
    if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      IntellectualGripPostureUtil.operatingHandCallback = callback ?? ((data: motion.OperatingHandStatus) => {
        console.info('operatingHandChanged: ' + data)
      })
      try {
        motion.on('operatingHandChanged', IntellectualGripPostureUtil.operatingHandCallback)
        console.info("operatingHandChanged on succeeded")
      } catch (err) {
        let error = err as BusinessError
        console.error("Failed on and err code is " + error.code)
      }
    }
  }

  static destroyOperatingHandStatus() {
    if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      try {
        motion.off('operatingHandChanged')
        IntellectualGripPostureUtil.operatingHandCallback = null
        console.info("operatingHandChanged off succeeded")
      } catch (err) {
        let error = err as BusinessError
        console.error("Failed off and err code is " + error.code)
      }
    }
  }

  static getOperatingHandStatus(): motion.OperatingHandStatus | null {
    if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      try {
        let data: motion.OperatingHandStatus = motion.getRecentOperatingHandStatus()
        console.info('getOperatingHandStatus: ' + data)
        return data
      } catch (err) {
        let error = err as BusinessError
        console.error("Failed get and err code is " + error.code)
        return null
      }
    }
    return null
  }

  static createHoldingHandStatus(callback?: Callback<motion.HoldingHandStatus>) {
    if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      IntellectualGripPostureUtil.holdingHandCallback = callback ?? ((data: motion.HoldingHandStatus) => {
        console.info('holdingHandChanged: ' + data)
      })
      try {
        motion.on('holdingHandChanged', IntellectualGripPostureUtil.holdingHandCallback)
        console.info("holdingHandChanged on succeeded")
      } catch (err) {
        let error = err as BusinessError
        console.error("Failed on and err code is " + error.code)
      }
    }
  }

  static destroyHoldingHandStatus() {
    if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      try {
        motion.off('holdingHandChanged')
        IntellectualGripPostureUtil.holdingHandCallback = null
        console.info("holdingHandChanged off succeeded")
      } catch (err) {
        let error = err as BusinessError
        console.error("Failed off and err code is " + error.code)
      }
    }
  }
}