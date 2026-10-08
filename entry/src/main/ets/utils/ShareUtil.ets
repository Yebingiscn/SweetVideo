import { systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor } from '@kit.ArkData'
import { PathUtils } from './PathUtils'
import ToolsUtil from './ToolsUtil'
import PermissionUtil from './PermissionUtil'

export default class ShareUtil {
  static async shareVideo(uri: string, title: string) {
    if (canIUse('SystemCapability.Collaboration.SystemShare')) {
      try {
        const activated = await PermissionUtil.activatePermission(uri)
        if (!activated) {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.share_failed_permission').id))
          return
        }
        let shareData = new systemShare.SharedData({
          utd: uniformTypeDescriptor.UniformDataType.VIDEO,
          uri: uri,
          title: title,
          description: ToolsUtil.getStringResource($r('app.string.share_description').id)
        })
        let controller = new systemShare.ShareController(shareData)
        await controller.show(PathUtils.appContext!, {
          previewMode: systemShare.SharePreviewMode.DETAIL,
          selectionMode: systemShare.SelectionMode.SINGLE
        })
      } catch (error) {
        const err = error as BusinessError
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.share_failed_prefix').id) + err.message)
      }
    } else {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.device_not_supported').id))
    }
  }
}