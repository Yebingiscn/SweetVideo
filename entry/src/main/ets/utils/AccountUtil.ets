import { LoginWithHWErrorCode } from "../common/Constants"
import { userData } from "../component/common/UserLoginComponent"
import Preferences from "../database/Preferences"
import { IapVerifyUtil } from "./IapVerifyUtil"
import { PathUtils } from "./PathUtils"
import SelectFileUtil from "./SelectFileUtil"
import ToolsUtil from "./ToolsUtil"
import { fileIo } from "@kit.CoreFileKit"
import { image } from "@kit.ImageKit"
import { http } from "@kit.NetworkKit"
import { authentication } from "@kit.AccountKit"
import { util } from "@kit.ArkTS"

export default class AccountUtil {
  // 错误处理
  static dealAllError(error: BusinessError): void {
    // 在应用登录涉及UI交互场景下，建议按照如下错误码指导提示用户
    if (error.code === LoginWithHWErrorCode.ERROR_CODE_LOGIN_OUT) {
      // 用户未登录华为账号，请登录华为账号并重试
      ToolsUtil.showToast('用户未登录华为账号，请登录华为账号并重试')
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_NETWORK_ERROR) {
      // 网络异常，请检查当前网络状态并重试或者尝试使用其他方式登录
      ToolsUtil.showToast('网络异常，请检查当前网络状态并重试')
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_INTERNAL_ERROR) {
      // 登录失败，请尝试使用其他方式登录
      ToolsUtil.showToast('华为账号服务器错误或其他内部错误，登录失败，请重试')
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_USER_CANCEL) {
      // 用户取消授权
      ToolsUtil.showToast('用户取消授权')
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_SYSTEM_SERVICE) {
      ToolsUtil.showToast('系统服务异常，请稍后重试')
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_REQUEST_REFUSE) {
      // 重复请求，应用无需处理
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_AGREEMENT_STATUS_NOT_ACCEPTED) {
      // 用户未同意协议
      ToolsUtil.showToast('请阅读并同意华为账号协议')
      // this.startAnimation()
    } else {
      ToolsUtil.showToast('应用登录失败，请重试')
    }
  }

  static getAvatarFromHuaweiAccount(onComplete?: () => void) {
    const authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest()
    authRequest.scopes = ['profile']
    authRequest.permissions = ['serviceauthcode']
    authRequest.forceAuthorization = true
    authRequest.state = util.generateRandomUUID()

    try {
      const controller = new authentication.AuthenticationController(PathUtils.appContext!)
      controller.executeRequest(authRequest).then(async (data) => {
        const authorizationWithHuaweiIDResponse = data as authentication.AuthorizationWithHuaweiIDResponse
        const state = authorizationWithHuaweiIDResponse.state
        if (state && authRequest.state !== state) {
          return
        }
        const authorizationWithHuaweiIDCredential = authorizationWithHuaweiIDResponse?.data
        const avatarUri = authorizationWithHuaweiIDCredential?.avatarUri
        const nickName = authorizationWithHuaweiIDCredential?.nickName
        const pixelMap = await AccountUtil.requestImage(avatarUri!)
        userData.userAvatar = avatarUri ?? ''
        userData.nickName = nickName ?? ''
        const localAvatarUri = await SelectFileUtil.savePixelMapToFile(PathUtils.photoPath!, 'avatar', pixelMap)
        Preferences.saveUserAvatar(PathUtils.appContext!, localAvatarUri)
        Preferences.saveUserNickName(PathUtils.appContext!, nickName ?? '')
        if (onComplete) {
          onComplete()
        }
      }).catch((err: BusinessError) => {
        AccountUtil.dealAllError(err)
        if (onComplete) {
          onComplete()
        }
      })
    } catch (error) {
      AccountUtil.dealAllError(error)
      if (onComplete) {
        onComplete()
      }
    }
  }

  static async requestImage(url: string): Promise<PixelMap> {
    return new Promise((resolve, reject) => {
      let httpRequest = http.createHttp()
      httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      }, (error: BusinessError, data: http.HttpResponse) => {
        if (error) {
          reject(error)
        } else {
          let imgData: ArrayBuffer = data.result as ArrayBuffer
          AccountUtil.bufferToPixelMap(imgData).then(resolve).catch(reject)
        }
      })
    })
  }

  static async bufferToPixelMap(imgData: ArrayBuffer): Promise<PixelMap> {
    let imageSource = image.createImageSource(imgData)
    let options: image.DecodingOptions = {
      desiredSize: { width: 512, height: 512 }, // 可选：指定目标尺寸
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888 // 指定像素格式
    }
    return await imageSource.createPixelMap(options)
  }

  static initAccount() {
    userData.isLogin = Preferences.getUserIsLogin(PathUtils.appContext!)
    if (userData.isLogin) {
      userData.userAvatar = AccountUtil.ISHasAvatar(Preferences.getUserAvatar(PathUtils.appContext!))
      userData.nickName = Preferences.getUserNickName(PathUtils.appContext!)
      userData.unionID = Preferences.getUserUnionID(PathUtils.appContext!)
      userData.idToken = Preferences.getUserIdToken(PathUtils.appContext!)
      userData.authorizationCode = Preferences.getUserAuthorizationCode(PathUtils.appContext!)
      userData.openID = Preferences.getUserOpenID(PathUtils.appContext!)
      userData.isVip = Preferences.getUserIsVip(PathUtils.appContext!)
      IapVerifyUtil.verifyPurchaseStatus(PathUtils.appContext!)
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
    try {
      let file = fileIo.openSync(url!, fileIo.OpenMode.READ_ONLY)
      const imageSource: image.ImageSource = image.createImageSource(file.fd)
      return await imageSource.createPixelMap()
    } catch (error) {
      return Promise.reject(error)
    }
  }
}