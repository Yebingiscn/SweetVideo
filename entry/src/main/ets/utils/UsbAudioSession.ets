import { usbManager } from '@kit.BasicServicesKit'
import { fileIo } from '@kit.CoreFileKit'
import { salmonLogger } from 'salmonlogger'

// The file descriptor remains owned here until playback stops. The USB AO
// duplicates it and drains its asynchronous transfers before releasing it.
export class UsbAudioSession {
  private pipe: usbManager.USBDevicePipe | undefined = undefined
  private fd: number = -1
  private generation: number = 0
  static volumeControl: ((value: number) => boolean) | undefined = undefined

  get descriptor(): number { return this.fd }

  static deviceKey(device: usbManager.USBDevice): string {
    return `${device.vendorId}:${device.productId}:${device.name}`
  }

  static devices(): usbManager.USBDevice[] {
    if (!canIUse('SystemCapability.USB.USBManager')) return []
    return usbManager.getDevices().filter((device: usbManager.USBDevice) =>
      device.configs.some((config: usbManager.USBConfiguration) =>
        config.interfaces.some((iface: usbManager.USBInterface) => iface.clazz === 1)))
  }

  async open(deviceName: string): Promise<number> {
    if (this.fd >= 0) return this.fd
    const generation = ++this.generation
    const devices = UsbAudioSession.devices()
    const device = deviceName ? devices.find((item: usbManager.USBDevice) => UsbAudioSession.deviceKey(item) === deviceName) :
      (devices.length === 1 ? devices[0] : undefined)
    if (!device) throw new Error(devices.length > 1 ? '请先在引擎设置中选择 USB 音频设备' : '未找到所选 USB 音频设备')
    if (!usbManager.hasRight(device.name) && !await usbManager.requestRight(device.name)) {
      throw new Error('未取得 USB 设备授权')
    }
    if (generation !== this.generation) throw new Error('USB 连接已取消')
    const pipe = usbManager.connectDevice(device)
    if (!pipe) throw new Error('无法连接 USB 设备')
    try {
      const fd = usbManager.getFileDescriptor(pipe)
      // SDK error codes are positive. Validate the returned number as an fd.
      if (fd < 0) throw new Error('系统未提供 USB 原生传输句柄')
      fileIo.statSync(fd)
      this.fd = fd
      this.pipe = pipe
      return fd
    } catch (error) {
      usbManager.closePipe(pipe)
      throw new Error('无法取得 USB 原生传输权限')
    }
  }

  close(): void {
    this.generation++
    if (this.fd >= 0) {
      try { fileIo.closeSync(this.fd) } catch (error) {
        salmonLogger.addLog('UsbAudioSession', '关闭 USB 句柄失败', true)
      }
      this.fd = -1
    }
    if (this.pipe) {
      try { usbManager.closePipe(this.pipe) } catch (error) {
        salmonLogger.addLog('UsbAudioSession', '释放 USB 设备失败', true)
      }
      this.pipe = undefined
    }
  }
}
