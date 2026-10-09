export interface AudioCoverBuilderParams {
  coverUri: string
}

// 覆盖音频播放时的黑色 Surface，但不拦截播放器手势。
@Builder
export function AudioCoverBuilder(params: AudioCoverBuilderParams) {
  if (params.coverUri) {
    Image(params.coverUri)
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Contain)
      .hitTestBehavior(HitTestMode.Transparent)
  }
}
