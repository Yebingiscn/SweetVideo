import { abilityAccessCtrl, common, Permissions, wantAgent } from '@kit.AbilityKit'
import { salmonLogger } from 'salmonlogger'
import AVSessionUtil from './AVSessionUtil'
import { Setting } from './ObservedUtil'
import { PathUtils } from './PathUtils'
import json from '@ohos.util.json'
import fileIo from '@ohos.file.fs'
import { fileShare } from '@kit.CoreFileKit'
import { backgroundTaskManager } from '@kit.BackgroundTasksKit'

const TAG = 'PermissionUtil'

//权限类
export default class PermissionUtil {
  public static permissions: Permissions[] = ['ohos.permission.FILE_ACCESS_PERSIST', 'ohos.permission.VIBRATE']
  // 权限缓存：避免重复持久化同一个URI的权限
  private static permissionCache: Set<string> = new Set()

  static async activatePermission(uri: string | undefined): Promise<boolean> {
    if (!uri) {
      return false
    }
    if (PermissionUtil.permissionCache.has(uri)) {
      return true
    }
    try {
      let fd = await fileIo.open(uri)
      await fileIo.close(fd)
      PermissionUtil.permissionCache.add(uri)
      return true
    } catch (error) {
      if (canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')) {
        try {
          const policyInfo: fileShare.PolicyInfo = {
            uri: uri,
            operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE,
          }
          const policies: fileShare.PolicyInfo[] = [policyInfo]
          const results = await fileShare.checkPersistentPermission(policies)
          const permissionsToActivate = results
            .map((needActivate, index) => needActivate ? policies[index] : null)
            .filter(Boolean)
          if (permissionsToActivate.length > 0) {
            await fileShare.activatePermission(permissionsToActivate)
          }
          let fd = await fileIo.open(uri)
          await fileIo.close(fd)
          PermissionUtil.permissionCache.add(uri)
          return true
        } catch (error) {
          salmonLogger.addLog(TAG, 'Permission activation failed:' + error, true)
          return false
        }
      }
      return false
    }
  }

  static applyContinuousTask() {
    if (Setting.allowBackgroundPlay) {
      PermissionUtil.startContinuousTask()
    }
  }

  static applyStopContinuousTask() {
    if (Setting.allowBackgroundPlay) { //若发生错误跳转兜底播放器，确保提前关闭申请防止两个播放器重复申请导致失败
      AVSessionUtil.destroySession()
      PermissionUtil.stopContinuousTask()
    }
  }

  static async startContinuousTask() {
    if (canIUse('SystemCapability.BundleManager.BundleFramework.Core')) {
      let wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          ({
            bundleName: PathUtils.appContext!.abilityInfo.bundleName,
            abilityName: "EntryAbility"
          })
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 114514,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      }
      wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: Object) => {
        try {
          backgroundTaskManager.startBackgroundRunning(PathUtils.appContext!,
            backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, wantAgentObj).then(() => {
          })?.catch((error: BusinessError) => {
            salmonLogger.addLog(TAG, 'background play failed BusinessError: ' + json.stringify(error), true)
          })
        } catch (error) {
          salmonLogger.addLog(TAG, 'getWantAgent error', true)
        }
      })?.catch(() => {
        salmonLogger.addLog(TAG, 'getWantAgent error', true)
      })
    }
  }

  static stopContinuousTask() {
    backgroundTaskManager.stopBackgroundRunning(PathUtils.appContext!)?.catch(() => {
      salmonLogger.addLog(TAG, 'stopBackgroundRunning error', true)
    })
  }

  static async persistPermission(uri: string): Promise<boolean> {
    if (PermissionUtil.permissionCache.has(uri)) {
      return false
    }

    try {
      if (canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')) {
        let policyInfo: fileShare.PolicyInfo = {
          uri: uri,
          operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE,
        }
        let policies: Array<fileShare.PolicyInfo> = [policyInfo]
        fileShare.persistPermission(policies)?.catch(() => {
          salmonLogger.addLog(TAG, 'persistPermission error', true)
        })
        PermissionUtil.permissionCache.add(uri)
      }
    } catch (error) {
      return true
    }
    return false
  }

  // 清空权限缓存（在应用退出或需要刷新时调用）
  static clearPermissionCache() {
    PermissionUtil.permissionCache.clear()
  }

  // 重新申请权限
  static reqPermissionsFromUser(permissions: Permissions[], context: common.UIAbilityContext): void {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager()
    atManager.requestPermissionsFromUser(context, permissions).then((data) => {
      let grantStatus: number[] = data.authResults
      let length: number = grantStatus.length
      for (let i = 0; i < length; i++) {
        if (grantStatus[i] === 0) {
        } else {
          return
        }
      }
    })?.catch(() => {
      salmonLogger.addLog(TAG, 'requestPermissionsFromUser error', true)
    })
  }
}
