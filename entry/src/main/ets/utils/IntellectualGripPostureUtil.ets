import { motion } from '@kit.MultimodalAwarenessKit';
import { salmonLogger } from 'salmonlogger';
import { Setting } from './ObservedUtil';

const TAG = 'IntellectualGripPostureUtil'

export default class IntellectualGripPostureUtil {
  private static unsupportedEvents: Set<string> = new Set()
  private static holdingCallbacks: Set<Callback<motion.HoldingHandStatus>> = new Set()
  private static holdingHandRegistered: boolean = false
  private static lastHoldingHandStatus: motion.HoldingHandStatus | null = null
  private static operatingHandRegistered: boolean = false

  private static dispatchHoldingHandStatus: Callback<motion.HoldingHandStatus> =
    (status: motion.HoldingHandStatus): void => {
      if (!Setting.gripPostureEnabled || IntellectualGripPostureUtil.holdingCallbacks.size === 0) {
        return
      }
      IntellectualGripPostureUtil.lastHoldingHandStatus = status
      const callbacks = Array.from(IntellectualGripPostureUtil.holdingCallbacks)
      for (const callback of callbacks) {
        if (IntellectualGripPostureUtil.holdingCallbacks.has(callback)) {
          callback(status)
        }
      }
    }

  static isLeftOperateHand(status: motion.OperatingHandStatus | null): boolean {
    if (!Setting.gripPostureEnabled) {
      return false
    }
    if (canIUse("SystemCapability.MultimodalAwareness.Motion")) {
      return IntellectualGripPostureUtil.isLeftHand(status, motion.OperatingHandStatus.LEFT_HAND_OPERATED)
    } else {
      return false
    }
  }

  static isLeftHoldHand(status: motion.HoldingHandStatus | null): boolean {
    if (!Setting.gripPostureEnabled) {
      return false
    }
    if (canIUse("SystemCapability.MultimodalAwareness.Motion")) {
      return IntellectualGripPostureUtil.isLeftHand(status, motion.HoldingHandStatus.LEFT_HAND_HELD)
    } else {
      return false
    }
  }

  static createOperatingHandStatus(callback?: Callback<motion.OperatingHandStatus>) {
    const onChanged = callback ?? ((status: motion.OperatingHandStatus) => {
      console.info('operatingHandChanged: ' + status)
    })
    if (IntellectualGripPostureUtil.registerMotionEvent('operatingHandChanged', () => {
      motion.on('operatingHandChanged', onChanged)
    })) {
      IntellectualGripPostureUtil.operatingHandRegistered = true
    }
  }

  static createHoldingHandStatus(callback: Callback<motion.HoldingHandStatus>) {
    if (!Setting.gripPostureEnabled || IntellectualGripPostureUtil.holdingCallbacks.has(callback)) {
      return
    }
    IntellectualGripPostureUtil.holdingCallbacks.add(callback)
    if (IntellectualGripPostureUtil.holdingHandRegistered) {
      const status = IntellectualGripPostureUtil.lastHoldingHandStatus
      if (status !== null) {
        callback(status)
      }
      return
    }
    IntellectualGripPostureUtil.holdingHandRegistered =
      IntellectualGripPostureUtil.registerMotionEvent('holdingHandChanged', () => {
        motion.on('holdingHandChanged', IntellectualGripPostureUtil.dispatchHoldingHandStatus)
      })
    if (!IntellectualGripPostureUtil.holdingHandRegistered) {
      IntellectualGripPostureUtil.holdingCallbacks.delete(callback)
    }
  }

  static destroyOperatingHandStatus() {
    if (IntellectualGripPostureUtil.operatingHandRegistered &&
      IntellectualGripPostureUtil.unregisterMotionEvent('operatingHandChanged', () => {
        motion.off('operatingHandChanged')
      })) {
      IntellectualGripPostureUtil.operatingHandRegistered = false
    }
  }

  static destroyHoldingHandStatus(callback: Callback<motion.HoldingHandStatus>) {
    IntellectualGripPostureUtil.holdingCallbacks.delete(callback)
    if (IntellectualGripPostureUtil.holdingCallbacks.size > 0 || !IntellectualGripPostureUtil.holdingHandRegistered) {
      return
    }
    IntellectualGripPostureUtil.lastHoldingHandStatus = null
    if (IntellectualGripPostureUtil.unregisterMotionEvent('holdingHandChanged', () => {
      motion.off('holdingHandChanged', IntellectualGripPostureUtil.dispatchHoldingHandStatus)
    })) {
      IntellectualGripPostureUtil.holdingHandRegistered = false
    }
  }

  static getOperatingHandStatus(): motion.OperatingHandStatus | null {
    if (!Setting.gripPostureEnabled) {
      return null
    }
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

  private static registerMotionEvent(eventName: string, register: () => void): boolean {
    if (!Setting.gripPostureEnabled || IntellectualGripPostureUtil.unsupportedEvents.has(eventName) ||
      !canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      return false
    }
    try {
      register()
      console.info(`${eventName} on succeeded`)
      return true
    } catch (error) {
      if (error.code === 801) {
        IntellectualGripPostureUtil.unsupportedEvents.add(eventName)
        salmonLogger.addLog(TAG, eventName + ': 设备不支持，已跳过')
      } else {
        salmonLogger.addLog(TAG, eventName + ' 注册失败，code=' + error.code, true)
      }
      return false
    }
  }

  private static unregisterMotionEvent(eventName: string, unregister: () => void): boolean {
    try {
      unregister()
      console.info(`${eventName} off succeeded`)
      return true
    } catch (error) {
      salmonLogger.addLog(TAG, eventName + ' 注销失败，code=' + error.code, true)
      return false
    }
  }
}
