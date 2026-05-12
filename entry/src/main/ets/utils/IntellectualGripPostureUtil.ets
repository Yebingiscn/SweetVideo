import { motion } from '@kit.MultimodalAwarenessKit';

export default class IntellectualGripPostureUtil {
  private static operatingHandCallback: Callback<motion.OperatingHandStatus> | null = null
  private static holdingHandCallback: Callback<motion.HoldingHandStatus> | null = null

  static isLeftOperateHand(status: motion.OperatingHandStatus | null): boolean {
    return IntellectualGripPostureUtil.isLeftHand(status, motion.OperatingHandStatus.LEFT_HAND_OPERATED)
  }

  static isLeftHoldHand(status: motion.HoldingHandStatus | null): boolean {
    return IntellectualGripPostureUtil.isLeftHand(status, motion.HoldingHandStatus.LEFT_HAND_HELD)
  }

  static createOperatingHandStatus(callback?: Callback<motion.OperatingHandStatus>) {
    IntellectualGripPostureUtil.createHandStatus(callback, 'operatingHandChanged',
      (cb) => {
        IntellectualGripPostureUtil.operatingHandCallback = cb
      },
      (cb) => {
        motion.on('operatingHandChanged', cb)
      })
  }

  static createHoldingHandStatus(callback?: Callback<motion.HoldingHandStatus>) {
    IntellectualGripPostureUtil.createHandStatus(callback, 'holdingHandChanged',
      (cb) => {
        IntellectualGripPostureUtil.holdingHandCallback = cb
      },
      (cb) => {
        motion.on('holdingHandChanged', cb)
      })
  }

  static destroyOperatingHandStatus() {
    IntellectualGripPostureUtil.destroyHandStatus('operatingHandChanged',
      () => {
        motion.off('operatingHandChanged')
      },
      () => {
        IntellectualGripPostureUtil.operatingHandCallback = null
      })
  }

  static destroyHoldingHandStatus() {
    IntellectualGripPostureUtil.destroyHandStatus('holdingHandChanged',
      () => {
        motion.off('holdingHandChanged')
      },
      () => {
        IntellectualGripPostureUtil.holdingHandCallback = null
      })
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

  private static isLeftHand<T>(status: T | null, leftValue: T): boolean {
    if (status === null) {
      return false
    }
    if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      return status === leftValue
    }
    return false
  }

  private static createHandStatus<T>(callback: Callback<T> | undefined, defaultLog: string,
    callbackSetter: (cb: Callback<T> | null) => void, register: (cb: Callback<T>) => void) {
    if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      const cb = callback ?? ((data: T) => {
        console.info(`${defaultLog}: ` + data)
      })
      callbackSetter(cb)
      try {
        register(cb)
        console.info(`${defaultLog} on succeeded`)
      } catch (err) {
        let error = err as BusinessError
        console.error("Failed on and err code is " + error.code)
      }
    }
  }

  private static destroyHandStatus(logName: string, unregister: () => void, callbackSetter: () => void) {
    if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      try {
        unregister()
        callbackSetter()
        console.info(`${logName} off succeeded`)
      } catch (err) {
        let error = err as BusinessError
        console.error("Failed off and err code is " + error.code)
      }
    }
  }
}
