class TimeUtil {
  // 格式化时间
  convertMsToMMSS(ms: number | undefined): string {
    if (!ms) {
      return '00:00'
    }
    // 计算总秒数
    const totalSeconds = Math.floor(ms / 1000) // 将毫秒转换为秒
    const hours = Math.floor(totalSeconds / 3600) // 计算小时
    const minutes = Math.floor((totalSeconds % 3600) / 60) // 计算剩余分钟
    const seconds = totalSeconds % 60 // 计算剩余秒数

    // 格式化为两位数的字符串，确保单个位数前加零
    const hh = hours.toString().padStart(2, '0')
    const mm = minutes.toString().padStart(2, '0')
    const ss = seconds.toString().padStart(2, '0')

    // 根据小时数返回格式化的时间字符串
    return hours > 0 ? `${hh}:${mm}:${ss}` : `${mm}:${ss}`
  }
}

export default new TimeUtil()