import { motion } from '@kit.MultimodalAwarenessKit';
import { salmonLogger } from 'salmonlogger';

const TAG = 'IntellectualGripPostureUtil'

export default class IntellectualGripPostureUtil {
  static isLeftOperateHand(status: motion.OperatingHandStatus | null): boolean {
    if (canIUse("SystemCapability.MultimodalAwareness.Motion")) {
      return IntellectualGripPostureUtil.isLeftHand(status, motion.OperatingHandStatus.LEFT_HAND_OPERATED)
    } else {
      return false
    }
  }

  static isLeftHoldHand(status: motion.HoldingHandStatus | null): boolean {
    if (canIUse("SystemCapability.MultimodalAwareness.Motion")) {
      return IntellectualGripPostureUtil.isLeftHand(status, motion.HoldingHandStatus.LEFT_HAND_HELD)
    } else {
      return false
    }
  }

  static createOperatingHandStatus(callback?: Callback<motion.OperatingHandStatus>) {
    IntellectualGripPostureUtil.createHandStatus(callback, 'operatingHandChanged',
      () => {
      },
      (cb) => {
        if (canIUse("SystemCapability.MultimodalAwareness.Motion")) {
          try {
            motion.on('operatingHandChanged', cb)
          } catch (error) {
            salmonLogger.addLog(TAG, 'operatingHandChanged error' + error, true)
          }
        } else {
          salmonLogger.addLog(TAG, 'unsupported SystemCapability', true)
        }
      })
  }

  static createHoldingHandStatus(callback?: Callback<motion.HoldingHandStatus>) {
    IntellectualGripPostureUtil.createHandStatus(callback, 'holdingHandChanged',
      () => {
      },
      (cb) => {
        if (canIUse("SystemCapability.MultimodalAwareness.Motion")) {
          try {
            motion.on('holdingHandChanged', cb)
          } catch (error) {
            salmonLogger.addLog(TAG, 'holdingHandChanged error' + error, true)
          }
        } else {
          salmonLogger.addLog(TAG, 'unsupported SystemCapability', true)
        }
      })
  }

  static destroyOperatingHandStatus() {
    IntellectualGripPostureUtil.destroyHandStatus('operatingHandChanged',
      () => {
        if (canIUse("SystemCapability.MultimodalAwareness.Motion")) {
          try {
            motion.off('operatingHandChanged')
          } catch (error) {
            salmonLogger.addLog(TAG, 'operatingHandChanged error' + error, true)
          }
        } else {
          salmonLogger.addLog(TAG, 'unsupported SystemCapability', true)
        }
      },
      () => {
      })
  }

  static destroyHoldingHandStatus() {
    IntellectualGripPostureUtil.destroyHandStatus('holdingHandChanged',
      () => {
        if (canIUse("SystemCapability.MultimodalAwareness.Motion")) {
          try {
            motion.off('holdingHandChanged')
          } catch (error) {
            salmonLogger.addLog(TAG, 'holdingHandChanged error' + error, true)
          }
        } else {
          salmonLogger.addLog(TAG, 'unsupported SystemCapability', true)
        }
      },
      () => {
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
