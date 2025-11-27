// 隐私空间工具类
export default class PrivacySpaceUtil {
  // 标识当前是否激活隐私空间
  private static readonly PRIVATE_MODE_KEY = 'isPrivateMode';

  static setPrivacyMode(privacy_mode: boolean) {
    AppStorage.setOrCreate<boolean>(PrivacySpaceUtil.PRIVATE_MODE_KEY, privacy_mode);
  }

  static getPrivacyMode() {
    return AppStorage.get<boolean>(PrivacySpaceUtil.PRIVATE_MODE_KEY);
  }
}