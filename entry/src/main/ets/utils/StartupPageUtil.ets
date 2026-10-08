import NavigationAddress from '../common/NavigationCommon'

export interface StartupPageOption {
  value: string
  label: ResourceStr
  route: string
}

export default class StartupPageUtil {
  static readonly IPTV_SOURCE_PREFIX: string = '__iptv_src__'
  static readonly pages: StartupPageOption[] = [
    { value: '__stream__', label: $r('app.string.default_start_page_stream'), route: NavigationAddress.STREAM_PAGE },
    { value: '__smb__', label: 'SMB', route: NavigationAddress.SMB_PAGE },
    { value: '__webdav__', label: 'WebDAV', route: NavigationAddress.WEBDAV_PAGE },
    { value: '__ftp__', label: 'FTP', route: NavigationAddress.FTP_PAGE },
    { value: '__iptv__', label: $r('app.string.default_start_page_iptv'), route: NavigationAddress.IPTV_SOURCE_PAGE }
  ]

  static getPage(value: string): StartupPageOption | undefined {
    return StartupPageUtil.pages.find(page => page.value === value)
  }
}
