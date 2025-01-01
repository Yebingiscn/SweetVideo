class TimeUtil {
  convertMsToMMSS(ms: number | undefined): string {
    if (!ms) {
      return '00:00'
    }
    // 计算分钟数和秒数
    let minutes = Math.floor(ms / 60000); // 1分钟 = 60000毫秒
    const seconds = Math.floor((ms % 60000) / 1000); // 剩余的秒数
    const hours = Math.floor(minutes / 60)
    minutes = minutes % 60 * hours
    // 格式化为两位数的字符串，确保单个位数前加零
    const mm = minutes.toString().padStart(2, '0');
    const ss = seconds.toString().padStart(2, '0');
    if (hours > 0) {
      const hh = hours.toString().padStart(2, '0');
      return `${hh}:${mm}:${ss}`
    } else {
      // 返回格式化的时间字符串
      return `${mm}:${ss}`;
    }
  }
}

const timeUtil = new TimeUtil()

export default timeUtil as TimeUtil