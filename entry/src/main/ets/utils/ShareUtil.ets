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
          ToolsUtil.showToast('分享失败: 无法获取文件权限')
          return
        }
        let shareData = new systemShare.SharedData({
          utd: uniformTypeDescriptor.UniformDataType.VIDEO,
          uri: uri,
          title: title,
          description: '流心播放器分享'
        })
        let controller = new systemShare.ShareController(shareData)
        await controller.show(PathUtils.appContext!, {
          previewMode: systemShare.SharePreviewMode.DETAIL,
          selectionMode: systemShare.SelectionMode.SINGLE
        })
      } catch (error) {
        const err = error as BusinessError
        ToolsUtil.showToast('分享失败: ' + err.message)
      }
    } else {
      ToolsUtil.showToast('设备不支持')
    }
  }
}