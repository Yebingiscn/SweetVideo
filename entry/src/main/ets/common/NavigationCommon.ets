import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'

export default class NavigationAddress {
  static AV_PLAYER = 'player'
  static FFMPEG_PLAYER = 'FFMpegPlayer'
  static RED_PLAYER = 'RedPlayer'
  static SETTING_PAGE = 'SettingsPage'
  static ABOUT_PAGE = 'AboutPage'
  static RECENT_PLAY = 'RecentPlay'
  static PRIVACY_SPACE = 'PrivacySpace'
  static CRASH_PAGE = 'CrashPage'
  static PERSONALIZE_PAGE = 'PersonalizePage'
  static PLAYER_SETTING_PAGE = 'PlayerSettingPage'
  static PRIVACY_ERROR_LIST = 'PrivacySpaceErrorList'
  static MORE_SETTING_PAGE = 'MoreSettingPage'
}

export class PrivacySpaceParams {
  public needGotoSetting: boolean = false
}

// Navigation 传参设置
export class PlayerParams {
  public metadata: VideoMetadata | undefined
  public metadata_list: VideoMetadata [] | undefined
  public file_folder: FileFolder | undefined

  constructor(metadata: VideoMetadata | undefined, metadata_list: VideoMetadata [] | undefined,
    file_folder: FileFolder | undefined) {
    this.metadata = metadata
    this.metadata_list = metadata_list
    this.file_folder = file_folder
  }
}