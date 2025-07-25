import { fileShare, fileIo as fs } from '@kit.CoreFileKit';
import { wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PathUtils } from './PathUtils';

//权限类
class PermissionUtil {
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

  async startContinuousTask() {
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
        }).catch((error: BusinessError) => {
          hilog.error(777, 'testFlag', 'background play failed BusinessError: ' + JSON.stringify(error))
        });
      } catch (error) {
        hilog.error(777, 'testFlag', 'background play failed: ' + JSON.stringify(error))
      }
    });
  }

  stopContinuousTask() {
    backgroundTaskManager.stopBackgroundRunning(PathUtils.appContext!)
  }

  async persistPermission(uri: string): Promise<boolean> {
    try {
      if (canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')) {
        let policyInfo: fileShare.PolicyInfo = {
          uri: uri,
          operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE,
        };
        let policies: Array<fileShare.PolicyInfo> = [policyInfo];
        fileShare.persistPermission(policies).then(() => {
        })
        let fd = await fs.open(uri);
        await fs.close(fd);
      }
    } catch (error) {
      return true
    }
    return false
  }
}

export default new PermissionUtil();