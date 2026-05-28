// 时间类，格式化时间
export default class TimeUtil {
  static convertMSToHHMMSS(ms: number | undefined): string {
    if (ms === undefined || ms === null || isNaN(ms)) {
      return '--:--'
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

  static convertSSToMMSS(seconds: number | undefined): string {
    if (seconds === undefined || seconds === null || isNaN(seconds)) {
      return '--:--'
    }
    const totalSeconds = Math.floor(seconds)
    const minutes = Math.floor(totalSeconds / 60)
    const remainingSeconds = totalSeconds % 60
    // 格式化显示 (分钟不补零，秒数补零)
    const mm = minutes.toString() // 分钟保持原始数值
    const ss = remainingSeconds.toString().padStart(2, '0')
    return `${mm}:${ss}`
  }

  static getPlayTime(playTime: number, totalTime: number) {
    return TimeUtil.convertMSToHHMMSS(Math.min(Math.max(playTime, 0), (totalTime ?? 0)))
  }

  static getRemainTime(playTime: number, totalTime: number, playSpeed: number) {
    return '-' + TimeUtil.convertMSToHHMMSS(Math.max(((totalTime ?? 0) - playTime) / (playSpeed ?? 1),
      0))
  }

  static convertSSToHHMMSS(seconds: number | undefined): string {
    if (seconds === undefined || seconds === null || isNaN(seconds)) {
      return '--:--'
    }
    const totalSeconds = Math.floor(seconds)
    const hours = Math.floor(totalSeconds / 3600)
    const minutes = Math.floor((totalSeconds % 3600) / 60)
    const remainingSeconds = totalSeconds % 60
    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`
    }
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`
  }

  static convertMSToChinese(ms: number | undefined): string {
    if (ms === undefined || ms === null || isNaN(ms) || ms <= 0) {
      return '0秒'
    }
    const seconds = Math.floor(ms / 1000)
    if (seconds < 60) {
      return `${seconds}秒`
    }
    const minutes = Math.floor(seconds / 60)
    const remainingSeconds = seconds % 60
    return `${minutes}分${remainingSeconds}秒`
  }

  static getTextByTime() {
    const hours = new Date().getHours()
    if (hours === 15) {
      return '饮茶啦'
    }
    // 常规时间问候
    if (hours >= 0 && hours < 5) {
      return '晚安~'
    } else if (hours >= 5 && hours < 12) {
      return '早上好'
    } else if (hours >= 12 && hours < 14) {
      return '中午好'
    } else if (hours >= 14 && hours < 18) {
      return '下午好'
    } else {
      return '晚上好'
    }
  }
}
