import { DialogButtonBar } from './DialogButtonBar'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import DataSyncUtil from '../../utils/DataSyncUtil'
import TimeUtil from '../../utils/TimeUtil'

@CustomDialog
export struct FolderOpeningEndingDialog {
  controller?: CustomDialogController
  onConfirm?: (folderDate: string, startTime: number, endTime: number) => void
  @State startTime: number = 0
  @State endTime: number = 0
  @State folderName: string = ''
  @State videoCount: number = 0
  private folderDate: string = ''

  aboutToAppear(): void {
    const folder = DataSyncUtil.editingFolder
    if (!folder) {
      return
    }
    this.folderDate = folder.date
    this.folderName = folder.name
    this.videoCount = folder.video_list.length
    this.startTime = this.getCommonTime(folder, true)
    this.endTime = this.getCommonTime(folder, false)
  }

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.menu_intro_outro'))
        .fontSize(20)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)

      Text($r('app.string.op_ed_overwrite_confirm', this.folderName, this.videoCount))
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .textAlign(TextAlign.Center)

      this.StartTimeSlider()

      this.EndTimeSlider()

      DialogButtonBar(
        () => {
          this.controller?.close()
        },
        () => {
          this.confirmInput()
        }
      )
    }
    .padding(20)
  }

  @Builder
  StartTimeSlider() {
    Column({ space: 6 }) {
      Row({ space: 12 }) {
        Text($r('app.string.skip_intro'))
          .fontSize(14)
          .fontColor($r('app.color.text_color'))
          .fontWeight(FontWeight.Medium)

        Text(this.startTime === 0 ? $r('app.string.off') : TimeUtil.convertSSToMMSS(this.startTime))
          .fontSize(14)
          .fontColor($r('app.color.text_color'))
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Slider({
        value: this.startTime,
        min: 0,
        max: 300,
        style: SliderStyle.InSet
      })
        .onChange((value: number) => {
          this.startTime = value
        })
        .selectedColor($r('app.color.main_color'))
        .width('100%')
        .enableHapticFeedback(true)
    }
    .width('100%')
    .backgroundColor($r('app.color.start_window_background_blur'))
    .borderRadius(16)
    .padding(12)
  }

  @Builder
  EndTimeSlider() {
    Column({ space: 6 }) {
      Row({ space: 12 }) {
        Text($r('app.string.skip_outro'))
          .fontSize(14)
          .fontColor($r('app.color.text_color'))
          .fontWeight(FontWeight.Medium)

        Text(this.endTime === 0 ? $r('app.string.off') : TimeUtil.convertSSToMMSS(this.endTime))
          .fontSize(14)
          .fontColor($r('app.color.text_color'))
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Slider({
        value: this.endTime,
        min: 0,
        max: 300,
        style: SliderStyle.InSet
      })
        .onChange((value: number) => {
          this.endTime = value
        })
        .selectedColor($r('app.color.main_color'))
        .width('100%')
        .enableHapticFeedback(true)
    }
    .width('100%')
    .backgroundColor($r('app.color.start_window_background_blur'))
    .borderRadius(16)
    .padding(12)
  }

  private getCommonTime(folder: FileFolder, isStartTime: boolean): number {
    if (folder.video_list.length === 0) {
      return 0
    }
    const firstTime = (isStartTime ? folder.video_list[0].start_time :
      (folder.video_list[0].end_time_is_duration ? folder.video_list[0].end_time : 0)) ?? 0
    const allSame = folder.video_list.every(video =>
    ((isStartTime ? video.start_time : (video.end_time_is_duration ? video.end_time : 0)) ?? 0) === firstTime)
    return allSame ? Math.round(firstTime / 1000) : 0
  }

  private confirmInput(): void {
    this.onConfirm?.(this.folderDate, this.startTime * 1000, this.endTime * 1000)
    this.controller?.close()
  }
}
