import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'

export class PlayerEngine {
  static AV_PLAYER = 'player'
  static MPV_PLAYER = 'MPVPlayer'
}

export default class NavigationAddress {
  static VIDEO_PLAYER = 'VideoPlayer'
  static SETTING_PAGE = 'SettingsPage'
  static ABOUT_PAGE = 'AboutPage'
  static RECENT_PLAY = 'RecentPlay'
  static PRIVACY_SPACE = 'PrivacySpace'
  static CRASH_PAGE = 'CrashPage'
  static PERSONALIZE_PAGE = 'PersonalizePage'
  static PLAYER_SETTING_PAGE = 'PlayerSettingPage'
  static SUBTITLE_SETTING_PAGE = 'SubtitleSettingPage'
  static PRIVACY_ERROR_LIST = 'PrivacySpaceErrorList'
  static MORE_SETTING_PAGE = 'MoreSettingPage'
  static VIP_PAGE = 'GetVipPage'
  static STREAM_PAGE = 'StreamPage'
}

export class PrivacySpaceParams {
  public needGotoSetting: boolean = false
}

// Navigation 传参设置
export class PlayerParams {
  public metadata: VideoMetadata | undefined
  public metadata_list: VideoMetadata [] | undefined
  public folder_date: string | undefined
  public file_folder: FileFolder | undefined
  public skipHistory: boolean = false
  public playerType: string = PlayerEngine.AV_PLAYER

  constructor(metadata: VideoMetadata | undefined, metadata_list: VideoMetadata [] | undefined,
    file_folder: FileFolder | undefined, skipHistory?: boolean, playerType?: string, folder_date?: string) {
    this.metadata = metadata
    this.metadata_list = metadata_list
    this.file_folder = file_folder
    if (skipHistory !== undefined) {
      this.skipHistory = skipHistory
    }
    if (playerType !== undefined) {
      this.playerType = playerType
    }
    this.folder_date = folder_date
  }
}