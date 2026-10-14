import ImageStorage from './ImageStorage'
import { LoginWithHWErrorCode } from '../common/Constants'
import { userData } from '../component/common/UserLoginComponent'
import Preferences from '../database/Preferences'
import { IapVerifyUtil } from './IapVerifyUtil'
import { PathUtils } from './PathUtils'
import ToolsUtil from './ToolsUtil'
import { fileIo } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { http } from '@kit.NetworkKit'
import { authentication } from '@kit.AccountKit'
import { util } from '@kit.ArkTS'
import { salmonLogger } from 'salmonlogger'

const TAG = 'AccountUtil'

export default class AccountUtil {
  // 错误处理
  static dealAllError(error: BusinessError): void {
    // 在应用登录涉及UI交互场景下，建议按照如下错误码指导提示用户
    if (error.code === LoginWithHWErrorCode.ERROR_CODE_LOGIN_OUT) {
      // 用户未登录华为账号，请登录华为账号并重试
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.huawei_account_login_required').id))
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_NETWORK_ERROR) {
      // 网络异常，请检查当前网络状态并重试或者尝试使用其他方式登录
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.network_error_retry').id))
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_INTERNAL_ERROR) {
      // 登录失败，请尝试使用其他方式登录
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.huawei_account_server_error').id))
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_USER_CANCEL) {
      // 用户取消授权
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.user_cancelled_authorization').id))
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_SYSTEM_SERVICE) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.system_service_error').id))
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_REQUEST_REFUSE) {
      // 重复请求，应用无需处理
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_AGREEMENT_STATUS_NOT_ACCEPTED) {
      // 用户未同意协议
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.agree_huawei_agreement').id))
      // this.startAnimation()
    } else {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.app_login_failed').id))
    }
  }

  static async getAvatarFromHuaweiAccount(): Promise<void> {
    const context = PathUtils.appContext
    if (!context || !userData.isLogin) { return }
    const openID = userData.openID
    let pixelMap: image.PixelMap | undefined = undefined
    try {
      const authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest()
      authRequest.scopes = ['profile']
      authRequest.permissions = ['serviceauthcode']
      authRequest.forceAuthorization = true
      authRequest.state = util.generateRandomUUID()
      const controller = new authentication.AuthenticationController(context)
      const response = await controller.executeRequest(authRequest) as authentication.AuthorizationWithHuaweiIDResponse
      if ((response?.state ?? '') !== authRequest.state) {
        salmonLogger.addLog(TAG, '头像昵称授权响应 state 不匹配', true)
        return
      }
      if (!userData.isLogin || userData.openID !== openID) { return }
      const credential = response.data
      const nickName = credential?.nickName
      if (nickName) {
        userData.nickName = nickName
        Preferences.saveUserNickName(context, nickName)
      }
      const avatarUri = credential?.avatarUri
      if (!avatarUri) { return }
      pixelMap = await AccountUtil.requestImage(avatarUri)
      if (!userData.isLogin || userData.openID !== openID) { return }
      const localAvatarUri = await ImageStorage.savePixelMapToFile(PathUtils.photoPath!, 'avatar', pixelMap)
      if (!localAvatarUri) { throw new Error('Avatar save failed') }
      if (!userData.isLogin || userData.openID !== openID) { return }
      userData.userAvatar = AccountUtil.ISHasAvatar(localAvatarUri)
      Preferences.saveUserAvatar(context, localAvatarUri)
    } catch (error) {
      // 登录凭据已经获取成功，资料授权、头像下载或保存失败不能报成登录失败。
      salmonLogger.addLog(TAG, `加载华为账号头像昵称失败: ${error.code ?? 'unknown'}`, true)
    } finally {
      await ImageStorage.releaseImageSafely(pixelMap, '账号头像')
    }
  }

  static async requestImage(url: string): Promise<image.PixelMap> {
    const httpRequest = http.createHttp()
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      })
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`Avatar HTTP status: ${response.responseCode}`)
      }
      return await AccountUtil.bufferToPixelMap(response.result as ArrayBuffer)
    } finally {
      httpRequest.destroy()
    }
  }

  static async bufferToPixelMap(imgData: ArrayBuffer): Promise<PixelMap> {
    const imageSource = image.createImageSource(imgData)
    const options: image.DecodingOptions = {
      desiredSize: { width: 512, height: 512 },
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    }
    try {
      return await imageSource.createPixelMap(options)
    } finally {
      await ImageStorage.releaseImageSafely(imageSource, '账号头像图片源')
    }
  }

  static initAccount() {
    userData.isLogin = Preferences.getUserIsLogin(PathUtils.appContext!)
    userData.isVip = Preferences.getUserIsVip(PathUtils.appContext!)
    IapVerifyUtil.verifyPurchaseStatus(PathUtils.appContext!)
    if (userData.isLogin) {
      userData.userAvatar = AccountUtil.ISHasAvatar(Preferences.getUserAvatar(PathUtils.appContext!))
      userData.nickName = Preferences.getUserNickName(PathUtils.appContext!)
      userData.unionID = Preferences.getUserUnionID(PathUtils.appContext!)
      userData.idToken = Preferences.getUserIdToken(PathUtils.appContext!)
      userData.authorizationCode = Preferences.getUserAuthorizationCode(PathUtils.appContext!)
      userData.openID = Preferences.getUserOpenID(PathUtils.appContext!)
    }
  }

  static ISHasAvatar(avatarPath: string): ResourceStr {
    try {
      return fileIo.accessSync(avatarPath) ? PathUtils.pathToUri(avatarPath) : ''
    } catch (error) {
      return ''
    }
  }

  static async fileToPixelMap(url: string): Promise<PixelMap> {
    let file: fileIo.File | undefined = undefined
    try {
      file = fileIo.openSync(url!, fileIo.OpenMode.READ_ONLY)
      const imageSource: image.ImageSource = image.createImageSource(file.fd)
      const pixelMap = await imageSource.createPixelMap()
      await imageSource.release()
      fileIo.closeSync(file)
      return pixelMap
    } catch (error) {
      if (file) {
        try {
          fileIo.closeSync(file)
        } catch (_e) {
        }
      }
      return Promise.reject(error)
    }
  }
}
