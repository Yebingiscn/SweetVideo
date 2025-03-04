import { fileShare, fileIo as fs } from '@kit.CoreFileKit';
import { common, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const context = getContext() as common.UIAbilityContext

class PermissionUtil {
  async activatePermission(uri: string): Promise<boolean> {
    try {
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
      let fd = await fs.open(uri);
      await fs.close(fd);
    } catch (error) {
      return false
    }
    return true;
  }

  startContinuousTask() {
    let wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        ({
          bundleName: context.abilityInfo.bundleName,
          abilityName: "EntryAbility"
        })
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 114514,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: Object) => {
      try {
        backgroundTaskManager.startBackgroundRunning(context,
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
    backgroundTaskManager.stopBackgroundRunning(context)
  }

  async persistPermission(uri: string): Promise<boolean> {
    try {
      let policyInfo: fileShare.PolicyInfo = {
        uri: uri,
        operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE,
      };
      let policies: Array<fileShare.PolicyInfo> = [policyInfo];
      fileShare.persistPermission(policies).then(() => {
      })
      let fd = await fs.open(uri);
      await fs.close(fd);
    } catch (error) {
      return true
    }
    return false
  }

  activePermission(tmp: string[]) {
    for (let uri of tmp) {
      this.activatePermission(uri)
    }
  }
}

export default new PermissionUtil();