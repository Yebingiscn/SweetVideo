import { fileShare, fileIo as fs } from '@kit.CoreFileKit';
import { abilityAccessCtrl, common, Permissions, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PathUtils } from './PathUtils';
import AVSessionUtil from './AVSessionUtil';
import { Setting } from './ObservedUtil';
import json from '@ohos.util.json';

//权限类
export default class PermissionUtil {
  public static permissions: Permissions[] = ['ohos.permission.FILE_ACCESS_PERSIST', 'ohos.permission.VIBRATE'];

  static async activatePermission(uri: string | undefined): Promise<boolean> {
    if (!uri) {
      return false;
    }
    try {
      // 首先尝试直接访问
      let fd = fs.openSync(uri);
      fs.closeSync(fd);
      return true;
    } catch (error) {
      // 直接访问失败，检查是否支持权限管理
      if (!canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')) {
        return false;
      }
      try {
        const policyInfo: fileShare.PolicyInfo = {
          uri: uri,
          operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE,
        };
        const policies: fileShare.PolicyInfo[] = [policyInfo];
        const results = await fileShare.checkPersistentPermission(policies);
        const permissionsToActivate = results
          .map((needActivate, index) => needActivate ? policies[index] : null)
          .filter(Boolean);
        if (permissionsToActivate.length > 0) {
          await fileShare.activatePermission(permissionsToActivate)
        }
        // 验证权限是否真正生效
        let fd = fs.openSync(uri);
        fs.closeSync(fd);
        return true;
      } catch (error) {
        console.error('Permission activation failed:', error);
        return false;
      }
    }
  }

  static applyContinuousTask() {
    if (Setting.allowBackgroundPlay) {
      PermissionUtil.startContinuousTask()
    }
  }

  static applyStopContinuousTask() {
    if (Setting.allowBackgroundPlay) { //若发生错误跳转FFMpeg播放器，确保提前关闭申请防止两个播放器重复申请导致失败
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
      };
      wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: Object) => {
        try {
          backgroundTaskManager.startBackgroundRunning(PathUtils.appContext!,
            backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, wantAgentObj).then(() => {
          })?.catch((error: BusinessError) => {
            hilog.error(777, 'testFlag', 'background play failed BusinessError: ' + json.stringify(error))
          });
        } catch (error) {
          hilog.error(777, 'testFlag', 'background play failed: ' + error)
        }
      })?.catch(() => {
        console.error('getWantAgent error')
      })
    }
  }

  static stopContinuousTask() {
    backgroundTaskManager.stopBackgroundRunning(PathUtils.appContext!)?.catch(() => {
      console.error('stopBackgroundRunning error')
    })
  }

  static async persistPermission(uri: string): Promise<boolean> {
    try {
      if (canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')) {
        let policyInfo: fileShare.PolicyInfo = {
          uri: uri,
          operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE,
        };
        let policies: Array<fileShare.PolicyInfo> = [policyInfo];
        fileShare.persistPermission(policies)?.catch(() => {
          console.error('persistPermission error')
        })
        let fd = await fs.open(uri);
        await fs.close(fd);
      }
    } catch (error) {
      return true
    }
    return false
  }

  // 重新申请权限
  static reqPermissionsFromUser(permissions: Permissions[], context: common.UIAbilityContext): void {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    atManager.requestPermissionsFromUser(context, permissions).then((data) => {
      let grantStatus: number[] = data.authResults;
      let length: number = grantStatus.length;
      for (let i = 0; i < length; i++) {
        if (grantStatus[i] === 0) {
        } else {
          return;
        }
      }
    })?.catch(() => {
      console.error('requestPermissionsFromUser error')
    })
  }
}
