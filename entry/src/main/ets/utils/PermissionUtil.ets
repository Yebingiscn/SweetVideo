import { fileShare, fileIo as fs } from '@kit.CoreFileKit';
import { abilityAccessCtrl, common, Permissions, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PathUtils } from './PathUtils';
import AVSessionUtil from './AVSessionUtil';

//权限类
class PermissionUtil {
  public permissions: Permissions[] = ['ohos.permission.FILE_ACCESS_PERSIST', 'ohos.permission.VIBRATE'];

  async activatePermission(uri: string | undefined): Promise<boolean> {
    if (!uri) {
      return false
    }
    try {
      let fd = fs.openSync(uri);
      fs.closeSync(fd);
      return true
    } catch {
      try {
        if (canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')) {
          let policyInfo: fileShare.PolicyInfo = {
            uri: uri,
            operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE,
          };
          let policies: Array<fileShare.PolicyInfo> = [policyInfo];
          let results = await fileShare.checkPersistentPermission(policies);
          for (let i = 0; i < results.length; i++) {
            if (results[i]) {
              let info: fileShare.PolicyInfo = {
                uri: policies[i].uri,
                operationMode: policies[i].operationMode,
              };
              let policy: Array<fileShare.PolicyInfo> = [info];
              await fileShare.activatePermission(policy);
            }
          }
          let fd = fs.openSync(uri);
          fs.closeSync(fd);
        }
        return true
      } catch (error) {
        return false
      }
    }
  }

  applyContinuousTask(allowBackgroundPlay: boolean) {
    if (allowBackgroundPlay) {
      this.startContinuousTask()
    }
  }

  applyStopContinuousTask(allowBackgroundPlay: boolean) {
    if (allowBackgroundPlay) { //若发生错误跳转FFMpeg播放器，确保提前关闭申请防止两个播放器重复申请导致失败
      AVSessionUtil.destroySession()
      this.stopContinuousTask()
    }
  }

  async startContinuousTask() {
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
            hilog.error(777, 'testFlag', 'background play failed BusinessError: ' + JSON.stringify(error))
          });
        } catch (error) {
          hilog.error(777, 'testFlag', 'background play failed: ' + JSON.stringify(error))
        }
      })?.catch(() => {
        console.error('getWantAgent error')
      })
    }
  }

  stopContinuousTask() {
    backgroundTaskManager.stopBackgroundRunning(PathUtils.appContext!)?.catch(() => {
      console.error('stopBackgroundRunning error')
    })
  }

  async persistPermission(uri: string): Promise<boolean> {
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
  reqPermissionsFromUser(permissions: Permissions[], context: common.UIAbilityContext): void {
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

export default new PermissionUtil();