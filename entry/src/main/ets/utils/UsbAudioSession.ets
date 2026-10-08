import { usbManager } from '@kit.BasicServicesKit'
import { fileIo } from '@kit.CoreFileKit'
import { salmonLogger } from 'salmonlogger'
import ToolsUtil from './ToolsUtil.ets'

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
    if (!device) throw new Error(devices.length > 1 ? ToolsUtil.getStringResource($r('app.string.usb_select_audio_device').id) : ToolsUtil.getStringResource($r('app.string.usb_audio_device_not_found').id))
    if (!usbManager.hasRight(device.name) && !await usbManager.requestRight(device.name)) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.usb_not_authorized').id))
    }
    if (generation !== this.generation) throw new Error(ToolsUtil.getStringResource($r('app.string.usb_connection_cancelled').id))
    const pipe = usbManager.connectDevice(device)
    if (!pipe) throw new Error(ToolsUtil.getStringResource($r('app.string.usb_connect_failed').id))
    try {
      const fd = usbManager.getFileDescriptor(pipe)
      // SDK error codes are positive. Validate the returned number as an fd.
      if (fd < 0) throw new Error(ToolsUtil.getStringResource($r('app.string.usb_no_native_transfer').id))
      fileIo.statSync(fd)
      this.fd = fd
      this.pipe = pipe
      return fd
    } catch (error) {
      usbManager.closePipe(pipe)
      throw new Error(ToolsUtil.getStringResource($r('app.string.usb_native_permission_failed').id))
    }
  }

  cancelPendingOpen(): void {
    this.generation++
  }

  close(): void {
    this.cancelPendingOpen()
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
