export class VideoStatusBarParams {
  screenWidth: number = 0
  screenHeight: number = 0
  clockTime: string = ''
}

@Builder
export function VideoStatusBarBuilder(params: VideoStatusBarParams) {
  if (params.screenWidth > params.screenHeight) {
    Row() {
      Text(params.clockTime)
        .fontWeight(FontWeight.Medium)
        .fontSize(16)
        .fontColor($r('sys.color.white'))
        .textAlign(TextAlign.Center)
        .align(Alignment.Center)
    }.width('100%')
    .height(15) //临时解决PC MODE下遮挡的问题
    .justifyContent(FlexAlign.Center)
  }
}