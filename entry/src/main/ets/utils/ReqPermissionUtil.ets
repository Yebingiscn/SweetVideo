import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { fileShare, fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

class ReqPermission {
  public permissions: Permissions[] = ['ohos.permission.FILE_ACCESS_PERSIST', 'ohos.permission.VIBRATE'];

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
    })
  }

  async persistPermission(uri: string): Promise<boolean> {
    try {
      let policyInfo: fileShare.PolicyInfo = {
        uri: uri,
        operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE,
      };
      let policies: Array<fileShare.PolicyInfo> = [policyInfo];
      fileShare.persistPermission(policies).then(() => {
      }).catch((err: BusinessError<Array<fileShare.PolicyErrorResult>>) => {
        hilog.info(0xFF00, "testTag", String(err));
      });
      let fd = await fs.open(uri);
      await fs.close(fd);
    } catch (error) {
      return true
    }
    return false
  }
}

export default new ReqPermission()