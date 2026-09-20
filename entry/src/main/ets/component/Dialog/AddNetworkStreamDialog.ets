import { DialogButtonBar } from './DialogButtonBar'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import Preferences from '../../database/Preferences'
import { PathUtils } from '../../utils/PathUtils'
import SelectFileUtil from '../../utils/SelectFileUtil'
import { salmonLogger } from 'salmonlogger'
import FFmpegThumbnailUtil from '../../utils/FFmpegThumbnailUtil'
import { picker } from '@kit.CoreFileKit'
import StrmUtil from '../../utils/StrmUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import SmbUtil, { SmbPlayback } from '../../utils/SmbUtil'
import { ButtonFancyModifier } from '../../common/AttributeModifierConfig'

const TAG = 'AddNetworkStreamDialog'

@CustomDialog
export struct AddNetworkStreamDialog {
  controller?: CustomDialogController = undefined
  @State streamName: string = ''
  @State streamUrl: string = ''
  @State saving: boolean = false
  onStreamAdded?: () => void

  build() {
    Column({ space: 20 }) {
      Text('添加网络串流')
        .fontSize(20)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)

      Text('支持 HTTP/HTTPS/RTMP 和 SMB 视频地址，也可以导入 .strm 文件。SMB 可使用已保存的账号。')
        .fontSize(12)
        .fontColor($r('app.color.text_color'))
        .opacity(0.6)
        .width('100%')

      TextInput({ placeholder: '名称：方便区分的地址名称', text: this.streamName })
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .borderRadius(16)
        .height(44)
        .onChange((input: string) => this.streamName = input)
        .id('input_stream_name')

      TextArea({ placeholder: '例如 https://服务器/video.mp4 或 smb://服务器/共享/video.mkv', text: this.streamUrl })
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .borderRadius(16)
        .onChange((input: string) => this.streamUrl = input)

      Button('导入 .strm 文件')
        .fontColor($r('app.color.text_color'))
        .attributeModifier(new ButtonFancyModifier('100%', 40))
        .backgroundColor($r('sys.color.button_background_color_transparent'))
        .onClick(async () => {
          await this.selectStrmFile()
        })

      DialogButtonBar(
        () => {
          this.controller?.close()
        },
        () => this.saveStream()
      )
    }.padding(20).enabled(!this.saving)
  }

  private async saveStream(): Promise<void> {
    if (this.saving || !this.streamUrl.trim()) {
      return
    }
    if (!this.streamName.trim() && !SmbUtil.isSmb(this.streamUrl)) {
      return
    }
    this.saving = true
    try {
      const url = await SmbUtil.prepareUri(this.streamUrl)
      const name = this.streamName.trim() || ToolsUtil.fileNameFromUri(url)
      const date = `stream_${Date.now()}`
      const streams = Preferences.getNetworkStreams(PathUtils.appContext!)
      streams.push({
        uri: url,
        title: name,
        date: date,
        size: [0, 0],
        time: 0,
        last_play: 0,
        format: SmbUtil.isSmb(url) ? VideoInfoUtil.getExtension(ToolsUtil.fileNameFromUri(url)) : '',
        video_size: '',
        hdr_type: 0,
        audio_type: 0,
        frame_rate: 0,
        start_time: 0,
        end_time: 0,
        external_subtitle_format: '',
        pointA: 0,
        pointB: 0
      } as VideoMetadata)
      Preferences.saveNetworkStreams(PathUtils.appContext!, streams)
      this.streamName = ''
      this.streamUrl = ''
      this.onStreamAdded?.()
      this.controller?.close()
      this.fetchThumbnailAndSave(url, date)
    } catch (error) {
      ToolsUtil.showToast(error instanceof Error ? error.message : '保存串流失败，请重试')
    } finally {
      this.saving = false
    }
  }

  private async selectStrmFile(): Promise<void> {
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.fileSuffixFilters = ['STRM 串流快捷方式|.strm', 'strm']
    let uris: string[] = []
    try {
      uris = await new picker.DocumentViewPicker(PathUtils.appContext!).select(options)
    } catch (_error) {
      return
    }
    if (uris.length === 0) {
      return
    }
    try {
      const result = await StrmUtil.read(uris[0])
      this.streamUrl = result.url
      if (!this.streamName.trim()) {
        this.streamName = result.name
      }
      ToolsUtil.showToast('已读取 .strm 文件')
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error)
      ToolsUtil.showToast(message)
    }
  }

  private async fetchThumbnailAndSave(url: string, date: string): Promise<void> {
    const smb = new SmbPlayback()
    try {
      const result = await FFmpegThumbnailUtil.extractNetworkCover(await smb.resolve(url), 300)
      if (result.success && result.pixelMap) {
        await SelectFileUtil.savePixelMapToFile(PathUtils.coverPath, date, result.pixelMap,
          { releasePixelMap: true })
      } else if (result.error) {
        salmonLogger.addLog(TAG, `FFmpeg fetchThumbnail failed: ${result.error}`, false)
      }
    } catch (e) {
      salmonLogger.addLog(TAG, `fetchThumbnail failed: ${e}`, false)
    } finally {
      smb.close()
    }
  }
}
