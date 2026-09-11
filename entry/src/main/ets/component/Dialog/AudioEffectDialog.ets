import { AudioEffectConfig } from '../../interfaces/AudioEffectInterface'
import ToolsUtil from '../../utils/ToolsUtil'
import { salmonLogger } from 'salmonlogger'

const EFFECT_VALUES: string[] = [
  'off', 'preset', 'equalizer', 'noise-reduction', 'sound-field', 'audio-separation',
  'voice-beautifier', 'environment', 'audio-mixer', 'space-render',
  'pure-voice-change', 'general-voice-change', 'tempo-pitch', 'hoa-space-render'
]
const EFFECT_LABELS: string[] = [
  '关闭', '音效预设', '均衡器', '降噪', '声场', '音源分离',
  '声音美化', '环境音效', '混音', '空间渲染',
  '传统变声', '通用变声', '变速变调', 'HOA 空间渲染'
]

const PRESET_VALUES: string[] = [
  'hifi', 'surround', 'cinema', 'concert',
  'vocal', 'bass-boost', 'gaming', 'retro',
  'space-extension', 'broadcast-studio'
]
const PRESET_LABELS: string[] = [
  '高保真', '环绕立体声', '影院模式', '音乐厅',
  '人声增强', '低音增强', '3D环绕', '怀旧复古',
  '空间拓展', '广播质感'
]

function createPresetConfig(preset: string): AudioEffectConfig {
  const config = new AudioEffectConfig()
  switch (preset) {
    case 'hifi':
      config.effect = 'voice-beautifier'
      config.beautifier = 'cd'
      break
    case 'surround':
      config.effect = 'space-render'
      config.spaceMode = 'position'
      config.spaceX = 0
      config.spaceY = 0
      config.spaceZ = 2
      break
    case 'cinema':
      config.effect = 'voice-beautifier'
      config.beautifier = 'theatre'
      break
    case 'concert':
      config.effect = 'sound-field'
      config.soundField = 'grand'
      break
    case 'vocal':
      config.effect = 'voice-beautifier'
      config.beautifier = 'clear'
      break
    case 'bass-boost':
      config.effect = 'equalizer'
      config.eqPreset = 'custom'
      config.eqGains = [6, 4, 2, 0, 0, 0, 0, 0, 0, 0]
      break
    case 'gaming':
      config.effect = 'space-render'
      config.spaceMode = 'rotation'
      config.spaceTime = 5
      config.spaceDirection = 'clockwise'
      config.spaceX = 0
      config.spaceY = 0
      config.spaceZ = 1
      break
    case 'retro':
      config.effect = 'environment'
      config.environment = 'gramophone'
      break
    case 'space-extension':
      config.effect = 'space-render'
      config.spaceMode = 'extension'
      config.spaceRadius = 2
      config.spaceAngle = 180
      break
    case 'broadcast-studio':
      config.effect = 'environment'
      config.environment = 'broadcast'
      break
  }
  return config
}

const EQ_VALUES: string[] = [
  'custom', 'default', 'ballads', 'chinese-style', 'classical',
  'dance', 'jazz', 'pop', 'r-and-b', 'rock'
]
const EQ_LABELS: string[] = [
  '自定义', '默认', '抒情', '国风', '古典',
  '舞曲', '爵士', '流行', 'R&B', '摇滚'
]
const EQ_FREQ_LABELS: string[] = ['31Hz', '62Hz', '125Hz', '250Hz', '500Hz', '1kHz', '2kHz', '4kHz', '8kHz', '16kHz']

const SOUND_FIELD_VALUES: string[] = ['front-facing', 'grand', 'near', 'wide']
const SOUND_FIELD_LABELS: string[] = ['正面', '宏大', '近场', '宽广']

const ENVIRONMENT_VALUES: string[] = ['broadcast', 'earpiece', 'underwater', 'gramophone']
const ENVIRONMENT_LABELS: string[] = ['广播', '听筒', '水下', '留声机']

const BEAUTIFIER_VALUES: string[] = ['clear', 'theatre', 'cd', 'studio']
const BEAUTIFIER_LABELS: string[] = ['清晰', '剧院', 'CD', '录音棚']

const SPACE_MODE_VALUES: string[] = ['position', 'rotation', 'extension']
const SPACE_MODE_LABELS: string[] = ['固定位置', '环绕旋转', '空间扩展']

const DIRECTION_VALUES: string[] = ['counterclockwise', 'clockwise']
const DIRECTION_LABELS: string[] = ['逆时针', '顺时针']

const PURE_GENDER_VALUES: string[] = ['female', 'male']
const PURE_GENDER_LABELS: string[] = ['女声源', '男声源']

const PURE_TYPE_VALUES: string[] = ['cartoon', 'cute', 'female', 'male', 'monster', 'robots', 'seasoned']
const PURE_TYPE_LABELS: string[] = ['卡通', '萝莉', '女声', '男声', '怪物', '机器人', '大叔']

const GENERAL_VALUES: string[] =
  ['cute', 'cyberpunk', 'female', 'male', 'mix', 'monster', 'seasoned', 'synth', 'trill', 'war']
const GENERAL_LABELS: string[] = ['萝莉', '赛博朋克', '女声', '男声', '混合', '怪物', '大叔', '合成器', '颤音', '战争']

const SEPARATION_VALUES: string[] = ['vocals', 'accompaniment', 'mix']
const SEPARATION_LABELS: string[] = ['人声', '伴奏', '合成']

const HOA_VALUES: string[] = [
  'order1-acn-n3d', 'order1-acn-sn3d', 'order1-fuma',
  'order2-acn-n3d', 'order2-acn-sn3d', 'order2-fuma',
  'order3-acn-n3d', 'order3-acn-sn3d', 'order3-fuma'
]
const HOA_LABELS: string[] = [
  '一阶 ACN/N3D', '一阶 ACN/SN3D', '一阶 FuMa',
  '二阶 ACN/N3D', '二阶 ACN/SN3D', '二阶 FuMa',
  '三阶 ACN/N3D', '三阶 ACN/SN3D', '三阶 FuMa'
]

@Component
struct TabSelector {
  labels: string[] = []
  values: string[] = []
  @Prop current: string = ''
  onSelect: (value: string) => void = () => {
  }

  build() {
    Scroll() {
      Row({ space: 6 }) {
        Repeat<string>(this.labels)
          .each((repeatItem: RepeatItem<string>) => {
            Row() {
              Text(repeatItem.item)
                .fontSize(13)
                .fontWeight(this.values[repeatItem.index] === this.current ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.values[repeatItem.index] === this.current ? Color.White : $r('app.color.text_color'))
                .maxLines(1)
            }
            .padding(5)
            .backgroundColor(this.values[repeatItem.index] === this.current ? $r('app.color.main_color') :
              $r('app.color.search_component_blur'))
            .height(28)
            .constraintSize({ minWidth: 55, maxWidth: 120 })
            .borderRadius(16)
            .justifyContent(FlexAlign.Center)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .onClick(() => {
              this.onSelect(this.values[repeatItem.index])
            })
          })
          .key((item: string, index: number) => `${index}_${item}`)
      }
    }
    .scrollBar(BarState.Off)
    .scrollable(ScrollDirection.Horizontal)
    .edgeEffect(EdgeEffect.Spring)
  }
}

@Component
struct ParamCardComponent {
  @BuilderParam content: () => void

  build() {
    Column({ space: 8 }) {
      this.content()
    }
    .width('100%')
    .padding(12)
    .borderRadius(16)
    .backgroundColor($r('sys.color.titlebar_icon_background_color'))
  }
}

@Component
struct ValueSliderComponent {
  title: string = ''
  @Prop value: number = 0
  min: number = 0
  max: number = 1
  step: number = 0.1
  decimals: number = 1
  onChange: (value: number) => void = () => {
  }

  build() {
    Column({ space: 2 }) {
      Row() {
        Text(this.title).fontSize(14).fontColor($r('app.color.text_color')).layoutWeight(1)
        Text(this.value.toFixed(this.decimals)).fontSize(13).fontColor('#909399')
      }.width('100%')

      Slider({
        value: this.value,
        min: this.min,
        max: this.max,
        step: this.step,
        style: SliderStyle.OutSet
      })
        .selectedColor($r('app.color.main_color'))
        .enableHapticFeedback(true)
        .onChange((nextValue: number) => this.onChange(nextValue))
    }
    .width('100%')
  }
}

@CustomDialog
export struct AudioEffectDialog {
  controller?: CustomDialogController
  getCurrentConfig?: () => AudioEffectConfig
  isSystemPlayer?: () => boolean
  onApply?: (config: AudioEffectConfig, silent?: boolean) => Promise<boolean>
  @State systemPlayer: boolean = false
  @State applyStatus: string = ''
  @State effectValues: string[] = EFFECT_VALUES
  @State effectLabels: string[] = EFFECT_LABELS
  private pendingConfig: AudioEffectConfig | undefined = undefined
  private applyTimer: number = -1
  private applyVersion: number = 0
  @State effect: string = 'off'
  @State eqPreset: string = 'default'
  @State eqGains: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  @State soundField: string = 'front-facing'
  @State environment: string = 'broadcast'
  @State beautifier: string = 'clear'
  @State spaceMode: string = 'position'
  @State spaceX: number = 0
  @State spaceY: number = 0
  @State spaceZ: number = 1
  @State spaceTime: number = 5
  @State spaceDirection: string = 'counterclockwise'
  @State spaceRadius: number = 1
  @State spaceAngle: number = 90
  @State pureGender: string = 'female'
  @State pureType: string = 'cartoon'
  @State purePitch: number = 0
  @State generalType: string = 'cute'
  @State tempo: number = 1
  @State pitch: number = 1
  @State separationOutput: string = 'vocals'
  @State hoaLayout: string = 'order1-acn-n3d'
  @State currentPreset: string = ''

  aboutToAppear(): void {
    this.systemPlayer = this.isSystemPlayer?.() === true
    this.effectValues = EFFECT_VALUES.filter((value: string) =>
      !this.systemPlayer || (value !== 'hoa-space-render' && value !== 'audio-mixer'))
    this.effectLabels = this.effectValues.map((value: string) => {
      if (this.systemPlayer && value === 'tempo-pitch') return '变调'
      return EFFECT_LABELS[EFFECT_VALUES.indexOf(value)]
    })
    this.applyStatus = ''
    this.loadConfig(this.getCurrentConfig?.() ?? new AudioEffectConfig())
  }

  aboutToDisappear(): void {
    this.flushPending()
  }

  build() {
    Column({ space: 12 }) {
      Text('流心音效')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_color'))
        .width('100%')

      TabSelector({
        labels: this.effectLabels,
        values: this.effectValues,
        current: this.effect,
        onSelect: (value: string): void => {
          this.effect = value
          this.applyCurrentConfig()
        }
      })

      Scroll() {
        Column({ space: 10 }) {
          if (this.effect === 'equalizer') {
            ParamCardComponent() {
              TabSelector({
                labels: EQ_LABELS,
                values: EQ_VALUES,
                current: this.eqPreset,
                onSelect: (value: string): void => {
                  this.eqPreset = value
                  this.applyCurrentConfig()
                }
              })
              if (this.eqPreset === 'custom') {
                Repeat<string>(EQ_FREQ_LABELS)
                  .each((repeatItem: RepeatItem<string>) => {
                    ValueSliderComponent({
                      title: repeatItem.item,
                      value: this.eqGains[repeatItem.index],
                      min: -10,
                      max: 10,
                      step: 1,
                      decimals: 0,
                      onChange: (nextValue: number): void => {
                        this.updateEqGain(repeatItem.index, nextValue)
                        this.applyCurrentConfig()
                      }
                    })
                  })
                  .key((item: string, index: number) => `${index}_${item}`)
              }
            }
          } else if (this.effect === 'sound-field') {
            ParamCardComponent() {
              TabSelector({
                labels: SOUND_FIELD_LABELS,
                values: SOUND_FIELD_VALUES,
                current: this.soundField,
                onSelect: (value: string): void => {
                  this.soundField = value
                  this.applyCurrentConfig()
                }
              })
            }
          } else if (this.effect === 'audio-separation') {
            ParamCardComponent() {
              TabSelector({
                labels: SEPARATION_LABELS,
                values: SEPARATION_VALUES,
                current: this.separationOutput,
                onSelect: (value: string): void => {
                  this.separationOutput = value
                  this.applyCurrentConfig()
                }
              })
              this.HintText('音源分离依赖设备 NPU 能力；不支持时会自动关闭效果。')
            }
          } else if (this.effect === 'voice-beautifier') {
            ParamCardComponent() {
              TabSelector({
                labels: BEAUTIFIER_LABELS,
                values: BEAUTIFIER_VALUES,
                current: this.beautifier,
                onSelect: (value: string): void => {
                  this.beautifier = value
                  this.applyCurrentConfig()
                }
              })
            }
          } else if (this.effect === 'environment') {
            ParamCardComponent() {
              TabSelector({
                labels: ENVIRONMENT_LABELS,
                values: ENVIRONMENT_VALUES,
                current: this.environment,
                onSelect: (value: string): void => {
                  this.environment = value
                  this.applyCurrentConfig()
                }
              })
            }
          } else if (this.effect === 'space-render') {
            ParamCardComponent() {
              TabSelector({
                labels: SPACE_MODE_LABELS,
                values: SPACE_MODE_VALUES,
                current: this.spaceMode,
                onSelect: (value: string): void => {
                  this.spaceMode = value
                  this.applyCurrentConfig()
                }
              })
              if (this.spaceMode === 'position' || this.spaceMode === 'rotation') {
                ValueSliderComponent({
                  title: 'X（米）',
                  value: this.spaceX,
                  min: -5,
                  max: 5,
                  step: 0.1,
                  decimals: 1,
                  onChange: (nextValue: number): void => {
                    this.spaceX = nextValue;
                    this.applyCurrentConfig()
                  }
                })
                ValueSliderComponent({
                  title: 'Y（米）',
                  value: this.spaceY,
                  min: -5,
                  max: 5,
                  step: 0.1,
                  decimals: 1,
                  onChange: (nextValue: number): void => {
                    this.spaceY = nextValue;
                    this.applyCurrentConfig()
                  }
                })
                ValueSliderComponent({
                  title: 'Z（米）',
                  value: this.spaceZ,
                  min: -5,
                  max: 5,
                  step: 0.1,
                  decimals: 1,
                  onChange: (nextValue: number): void => {
                    this.spaceZ = nextValue;
                    this.applyCurrentConfig()
                  }
                })
              }
              if (this.spaceMode === 'rotation') {
                ValueSliderComponent({
                  title: '环绕周期（秒）',
                  value: this.spaceTime,
                  min: 2,
                  max: 40,
                  step: 1,
                  decimals: 0,
                  onChange: (nextValue: number): void => {
                    this.spaceTime = nextValue;
                    this.applyCurrentConfig()
                  }
                })
                TabSelector({
                  labels: DIRECTION_LABELS,
                  values: DIRECTION_VALUES,
                  current: this.spaceDirection,
                  onSelect: (value: string): void => {
                    this.spaceDirection = value
                    this.applyCurrentConfig()
                  }
                })
              } else if (this.spaceMode === 'extension') {
                ValueSliderComponent({
                  title: '扩展半径（米）',
                  value: this.spaceRadius,
                  min: 1,
                  max: 5,
                  step: 0.1,
                  decimals: 1,
                  onChange: (nextValue: number): void => {
                    this.spaceRadius = nextValue;
                    this.applyCurrentConfig()
                  }
                })
                ValueSliderComponent({
                  title: '扩展角度',
                  value: this.spaceAngle,
                  min: 1,
                  max: 359,
                  step: 1,
                  decimals: 0,
                  onChange: (nextValue: number): void => {
                    this.spaceAngle = nextValue;
                    this.applyCurrentConfig()
                  }
                })
              }
            }
          } else if (this.effect === 'pure-voice-change') {
            ParamCardComponent() {
              TabSelector({
                labels: PURE_GENDER_LABELS,
                values: PURE_GENDER_VALUES,
                current: this.pureGender,
                onSelect: (value: string): void => {
                  this.pureGender = value
                  this.applyCurrentConfig()
                }
              })
              TabSelector({
                labels: PURE_TYPE_LABELS,
                values: PURE_TYPE_VALUES,
                current: this.pureType,
                onSelect: (value: string): void => {
                  this.pureType = value
                  this.applyCurrentConfig()
                }
              })
              ValueSliderComponent({
                title: '音高（0=自动）',
                value: this.purePitch,
                min: 0,
                max: 3,
                step: 0.1,
                decimals: 1,
                onChange: (nextValue: number): void => {
                  this.purePitch = nextValue === 0 || nextValue >= 0.3 ? nextValue : 0.3
                  this.applyCurrentConfig()
                }
              })
            }
          } else if (this.effect === 'general-voice-change') {
            ParamCardComponent() {
              TabSelector({
                labels: GENERAL_LABELS,
                values: GENERAL_VALUES,
                current: this.generalType,
                onSelect: (value: string): void => {
                  this.generalType = value
                  this.applyCurrentConfig()
                }
              })
            }
          } else if (this.effect === 'tempo-pitch') {
            ParamCardComponent() {
              if (!this.systemPlayer) {
              ValueSliderComponent({
                title: '速度',
                value: this.tempo,
                min: 0.5,
                max: 10,
                step: 0.1,
                decimals: 1,
                onChange: (nextValue: number): void => {
                  this.tempo = nextValue;
                  this.applyCurrentConfig()
                }
              })
              }
              ValueSliderComponent({
                title: '音高',
                value: this.pitch,
                min: 0.1,
                max: 5,
                step: 0.1,
                decimals: 1,
                onChange: (nextValue: number): void => {
                  this.pitch = nextValue;
                  this.applyCurrentConfig()
                }
              })
              this.HintText(this.systemPlayer ? '变调仅支持单声道音轨；视频变速请使用播放器倍速。' :
                '改变速度会改变音频时长，不建议用于需要保持音画同步的视频。')
            }
          } else if (this.effect === 'hoa-space-render') {
            ParamCardComponent() {
              TabSelector({
                labels: HOA_LABELS,
                values: HOA_VALUES,
                current: this.hoaLayout,
                onSelect: (value: string): void => {
                  this.hoaLayout = value
                  this.applyCurrentConfig()
                }
              })
              this.HintText('要求鸿蒙 7及以上，且音频通道顺序必须与所选 HOA 布局一致。')
            }
          } else if (this.effect === 'noise-reduction') {
            ParamCardComponent() {
              this.HintText(this.systemPlayer ? '仅支持单声道音轨；处理后恢复原采样率，不会把立体声降为单声道。' :
                '降噪会将处理格式调整为 16kHz 单声道。')
            }
          } else if (this.effect === 'audio-mixer') {
            ParamCardComponent() {
              this.HintText('mpv 当前提供单路解码音频，此模式作为 AudioSuite 混音管线直通。')
            }
          } else if (this.effect === 'off') {
            ParamCardComponent() {
              this.HintText(this.systemPlayer ? '使用系统播放器原声，不进行 AudioSuite 处理。' :
                '使用普通 OHAudio 输出，不进行 AudioSuite 处理。')
            }
          } else if (this.effect === 'preset') {
            ParamCardComponent() {
              TabSelector({
                labels: PRESET_LABELS,
                values: PRESET_VALUES,
                current: this.currentPreset,
                onSelect: (value: string): void => {
                  this.currentPreset = value
                  const presetConfig = createPresetConfig(value)
                  this.loadPresetParams(presetConfig)
                  this.scheduleApply(presetConfig)
                }
              })
              this.HintText('选择预设即可快速应用，切换到对应效果可进一步微调参数。')
            }
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .constraintSize({ maxHeight: 400 })
      .scrollBar(BarState.Auto)

      if (this.systemPlayer) {
        this.HintText('系统音效保持原音频格式。传统变声、降噪和变调仅支持单声道；不提供 HOA 和单路混音。')
      }
      if (this.applyStatus.length > 0) {
        // Bind the text directly: a primitive @Builder argument can retain its
        // initial value while the non-empty conditional branch stays mounted.
        Row({ space: 6 }) {
          Text(this.applyStatus)
            .fontSize(13)
            .fontColor('#909399')
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }

      Row({ space: 10 }) {
        Button('重置')
          .layoutWeight(1)
          .height(40)
          .fontSize(15)
          .fontColor($r('app.color.text_color'))
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .borderRadius(16)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .onClick(() => {
            this.loadConfig(new AudioEffectConfig())
            this.applyCurrentConfig()
          })
        Button('关闭')
          .layoutWeight(1)
          .height(40)
          .fontSize(15)
          .fontColor($r('app.color.text_color'))
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .borderRadius(16)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .onClick(() => this.controller?.close())
      }
      .width('100%')
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 16,
      bottom: 16
    })
  }

  @Builder
  HintText(message: string) {
    Row({ space: 6 }) {
      Text(message)
        .fontSize(13)
        .fontColor('#909399')
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  private updateEqGain(index: number, value: number): void {
    const gains = this.eqGains.slice()
    gains[index] = value
    this.eqGains = gains
  }

  private applyCurrentConfig(): void {
    if (this.effect === 'preset') return
    const config = this.createConfig()
    if (this.systemPlayer) config.tempo = 1
    this.scheduleApply(config)
  }

  private scheduleApply(config: AudioEffectConfig): void {
    // Invalidate older completions immediately, including during debounce.
    ++this.applyVersion
    this.pendingConfig = config
    this.applyStatus = ''
    if (this.applyTimer !== -1) clearTimeout(this.applyTimer)
    this.applyTimer = setTimeout(() => this.flushPending(), 180)
  }

  private flushPending(): void {
    if (this.applyTimer !== -1) clearTimeout(this.applyTimer)
    this.applyTimer = -1
    const config = this.pendingConfig
    this.pendingConfig = undefined
    if (!config) return
    const version = ++this.applyVersion
    this.applyStatus = ''
    this.applyConfig(config, version)
  }

  private async applyConfig(config: AudioEffectConfig, version: number): Promise<void> {
    try {
      const applied = await this.onApply?.(config, true)
      if (version === this.applyVersion) {
        this.applyStatus = applied ? '' : '应用失败，保留原设置'
        if (!applied) this.reportApplyFailure(config.effect, this.applyStatus)
      }
    } catch (error) {
      if (version === this.applyVersion) {
        this.applyStatus = (error as Error).message || '音效应用失败，保留原设置'
        this.reportApplyFailure(config.effect, this.applyStatus)
      }
    }
  }

  private reportApplyFailure(effect: string, message: string): void {
    salmonLogger.addLog('AudioEffectDialog', `音效 ${effect} 应用失败：${message}`, true)
    ToolsUtil.showToast(message)
  }

  private loadConfig(config: AudioEffectConfig): void {
    this.effect = config.effect
    this.eqPreset = config.eqPreset
    this.eqGains = config.eqGains.slice()
    this.soundField = config.soundField
    this.environment = config.environment
    this.beautifier = config.beautifier
    this.spaceMode = config.spaceMode
    this.spaceX = config.spaceX
    this.spaceY = config.spaceY
    this.spaceZ = config.spaceZ
    this.spaceTime = config.spaceTime
    this.spaceDirection = config.spaceDirection
    this.spaceRadius = config.spaceRadius
    this.spaceAngle = config.spaceAngle
    this.pureGender = config.pureGender
    this.pureType = config.pureType
    this.purePitch = config.purePitch
    this.generalType = config.generalType
    this.tempo = config.tempo
    this.pitch = config.pitch
    this.separationOutput = config.separationOutput
    this.hoaLayout = config.hoaLayout
  }

  private loadPresetParams(config: AudioEffectConfig): void {
    this.eqPreset = config.eqPreset
    this.eqGains = config.eqGains.slice()
    this.soundField = config.soundField
    this.environment = config.environment
    this.beautifier = config.beautifier
    this.spaceMode = config.spaceMode
    this.spaceX = config.spaceX
    this.spaceY = config.spaceY
    this.spaceZ = config.spaceZ
    this.spaceTime = config.spaceTime
    this.spaceDirection = config.spaceDirection
    this.spaceRadius = config.spaceRadius
    this.spaceAngle = config.spaceAngle
    this.pureGender = config.pureGender
    this.pureType = config.pureType
    this.purePitch = config.purePitch
    this.generalType = config.generalType
    this.tempo = config.tempo
    this.pitch = config.pitch
    this.separationOutput = config.separationOutput
    this.hoaLayout = config.hoaLayout
  }

  private createConfig(): AudioEffectConfig {
    const config = new AudioEffectConfig()
    config.effect = this.effect
    config.eqPreset = this.eqPreset
    config.eqGains = this.eqGains.slice()
    config.soundField = this.soundField
    config.environment = this.environment
    config.beautifier = this.beautifier
    config.spaceMode = this.spaceMode
    config.spaceX = this.spaceX
    config.spaceY = this.spaceY
    config.spaceZ = this.spaceZ
    config.spaceTime = this.spaceTime
    config.spaceDirection = this.spaceDirection
    config.spaceRadius = this.spaceRadius
    config.spaceAngle = this.spaceAngle
    config.pureGender = this.pureGender
    config.pureType = this.pureType
    config.purePitch = this.purePitch
    config.generalType = this.generalType
    config.tempo = this.tempo
    config.pitch = this.pitch
    config.separationOutput = this.separationOutput
    config.hoaLayout = this.hoaLayout
    return config
  }
}
