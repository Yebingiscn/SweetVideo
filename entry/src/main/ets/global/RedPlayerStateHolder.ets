//红薯播放器常用设置项
export default class RedPlayerStateHolder {
  videoDuration: number = 0
  videoPosition: number = 0
  videoWidth: number = 0
  videoHeight: number = 0
  videoViewWidth: Length = '100%'
  videoViewHeight: Length = '100%'
  url: string = ''
  isStart: boolean = false
  speedIndex: number = 1
  videoCodec: string = ''
  audioCodec: string = ''
}