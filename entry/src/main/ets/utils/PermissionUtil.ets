import { fileShare, fileUri, fileIo as fs, hash, picker } from '@kit.CoreFileKit';
import { common, WantAgent, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';

const context = getContext() as common.UIAbilityContext

class Permission {
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
          bundleName: "com.example.sweetvideo",
          abilityName: "EntryAbility"
        })
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 114514,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: WantAgent) => {
      backgroundTaskManager.startBackgroundRunning(context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, wantAgentObj).then(() => {
      })
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
      PermissionUtil.activatePermission(uri)
    }
  }
}

const PermissionUtil = new Permission();

export default PermissionUtil;