// 时间类，格式化时间
class TimeUtil {
  convertMSToMMSS(ms: number | undefined): string {
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

  convertSSToMMSS(seconds: number | undefined): string {
    if (seconds === undefined || seconds === null || isNaN(seconds)) {
      return '00:00';
    }
    const totalSeconds = Math.floor(seconds);
    const minutes = Math.floor(totalSeconds / 60);
    const remainingSeconds = totalSeconds % 60;
    // 格式化显示 (分钟不补零，秒数补零)
    const mm = minutes.toString(); // 分钟保持原始数值
    const ss = remainingSeconds.toString().padStart(2, '0');
    return `${mm}:${ss}`;
  }

  // 字幕时间格式化
  formatTime(ms: number): string {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    const milliseconds = ms % 1000;

    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}.${milliseconds.toString()
      .padStart(3, '0')}`;
  }
}

export default new TimeUtil()