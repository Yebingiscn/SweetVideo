import { abilityAccessCtrl, common, Permissions } from "@kit.AbilityKit";

class ReqPermission{
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
}
const reqPermission = new ReqPermission()
export default reqPermission as ReqPermission