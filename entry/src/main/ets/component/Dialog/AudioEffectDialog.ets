import { AudioEffectConfig } from '../../interfaces/AudioEffectInterface'
import ToolsUtil from '../../utils/ToolsUtil'
import { salmonLogger } from 'salmonlogger'

const EFFECT_VALUES: string[] = [
  'off', 'preset', 'equalizer', 'noise-reduction', 'sound-field', 'audio-separation',
  'voice-beautifier', 'environment', 'audio-mixer', 'space-render',
  'pure-voice-change', 'general-voice-change', 'tempo-pitch', 'hoa-space-render'
]
const EFFECT_LABELS: ResourceStr[] = [
  $r('app.string.off'), $r('app.string.effect_preset'), $r('app.string.effect_equalizer'), $r('app.string.effect_noise_reduction'), $r('app.string.effect_sound_field'), $r('app.string.effect_accompaniment'),
  $r('app.string.effect_voice_beautifier'), $r('app.string.effect_environment'), $r('app.string.effect_audio_mixer'), $r('app.string.effect_space_render'),
  $r('app.string.effect_pure_voice_change'), $r('app.string.effect_general_voice_change'), $r('app.string.effect_tempo_pitch'), $r('app.string.effect_hoa_space_render')
]

const PRESET_VALUES: string[] = [
  'hifi', 'surround', 'cinema', 'concert',
  'vocal', 'bass-boost', 'gaming', 'retro',
  'space-extension', 'broadcast-studio'
]
const PRESET_LABELS: ResourceStr[] = [
  $r('app.string.preset_hifi'), $r('app.string.preset_surround'), $r('app.string.preset_cinema'), $r('app.string.preset_concert'),
  $r('app.string.preset_vocal'), $r('app.string.preset_bass_boost'), $r('app.string.preset_gaming'), $r('app.string.preset_retro'),
  $r('app.string.preset_space_extension'), $r('app.string.preset_broadcast_studio')
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
const EQ_LABELS: ResourceStr[] = [
  $r('app.string.eq_custom'), $r('app.string.eq_default'), $r('app.string.eq_ballads'), $r('app.string.eq_chinese_style'), $r('app.string.eq_classical'),
  $r('app.string.eq_dance'), $r('app.string.eq_jazz'), $r('app.string.eq_pop'), $r('app.string.eq_randb'), $r('app.string.eq_rock')
]
const EQ_FREQ_LABELS: string[] = ['31Hz', '62Hz', '125Hz', '250Hz', '500Hz', '1kHz', '2kHz', '4kHz', '8kHz', '16kHz']

const SOUND_FIELD_VALUES: string[] = ['front-facing', 'grand', 'near', 'wide']
const SOUND_FIELD_LABELS: ResourceStr[] = [$r('app.string.sf_front'), $r('app.string.sf_grand'), $r('app.string.sf_near'), $r('app.string.sf_wide')]

const ENVIRONMENT_VALUES: string[] = ['broadcast', 'earpiece', 'underwater', 'gramophone']
const ENVIRONMENT_LABELS: ResourceStr[] = [$r('app.string.env_broadcast'), $r('app.string.env_earpiece'), $r('app.string.env_underwater'), $r('app.string.env_gramophone')]

const BEAUTIFIER_VALUES: string[] = ['clear', 'theatre', 'cd', 'studio']
const BEAUTIFIER_LABELS: ResourceStr[] = [$r('app.string.bf_clear'), $r('app.string.bf_theatre'), 'CD', $r('app.string.bf_studio')]

const SPACE_MODE_VALUES: string[] = ['position', 'rotation', 'extension']
const SPACE_MODE_LABELS: ResourceStr[] = [$r('app.string.space_position'), $r('app.string.space_rotation'), $r('app.string.space_extension')]

const DIRECTION_VALUES: string[] = ['counterclockwise', 'clockwise']
const DIRECTION_LABELS: ResourceStr[] = [$r('app.string.dir_counterclockwise'), $r('app.string.dir_clockwise')]

const PURE_GENDER_VALUES: string[] = ['female', 'male']
const PURE_GENDER_LABELS: ResourceStr[] = [$r('app.string.gender_female'), $r('app.string.gender_male')]

const PURE_TYPE_VALUES: string[] = ['cartoon', 'cute', 'female', 'male', 'monster', 'robots', 'seasoned']
const PURE_TYPE_LABELS: ResourceStr[] = [$r('app.string.voice_cartoon'), $r('app.string.voice_cute'), $r('app.string.voice_female'), $r('app.string.voice_male'), $r('app.string.voice_monster'), $r('app.string.voice_robot'), $r('app.string.voice_seasoned')]

const GENERAL_VALUES: string[] =
  ['cute', 'cyberpunk', 'female', 'male', 'mix', 'monster', 'seasoned', 'synth', 'trill', 'war']
const GENERAL_LABELS: ResourceStr[] = [$r('app.string.voice_cute'), $r('app.string.gen_cyberpunk'), $r('app.string.voice_female'), $r('app.string.voice_male'), $r('app.string.gen_mix'), $r('app.string.voice_monster'), $r('app.string.voice_seasoned'), $r('app.string.gen_synth'), $r('app.string.gen_trill'), $r('app.string.gen_war')]

const SEPARATION_VALUES: string[] = ['vocals', 'accompaniment', 'mix']
const SEPARATION_LABELS: ResourceStr[] = [$r('app.string.sep_vocals'), $r('app.string.sep_accompaniment'), $r('app.string.sep_mix')]

const HOA_VALUES: string[] = [
  'order1-acn-n3d', 'order1-acn-sn3d', 'order1-fuma',
  'order2-acn-n3d', 'order2-acn-sn3d', 'order2-fuma',
  'order3-acn-n3d', 'order3-acn-sn3d', 'order3-fuma'
]
const HOA_LABELS: ResourceStr[] = [
  $r('app.string.hoa_1_acn_n3d'), $r('app.string.hoa_1_acn_sn3d'), $r('app.string.hoa_1_fuma'),
  $r('app.string.hoa_2_acn_n3d'), $r('app.string.hoa_2_acn_sn3d'), $r('app.string.hoa_2_fuma'),
  $r('app.string.hoa_3_acn_n3d'), $r('app.string.hoa_3_acn_sn3d'), $r('app.string.hoa_3_fuma')
]

@Component
struct TabSelector {
  labels: ResourceStr[] = []
  values: string[] = []
  @Prop current: string = ''
  onSelect: (value: string) => void = () => {
  }

  build() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignContent: FlexAlign.Start }) {
      Repeat<ResourceStr>(this.labels)
        .each((repeatItem: RepeatItem<ResourceStr>) => {
          Row() {
            Text(repeatItem.item)
              .fontSize(13)
              .fontWeight(this.values[repeatItem.index] === this.current ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.values[repeatItem.index] === this.current ? Color.White : $r('app.color.text_color'))
              .maxLines(1)
          }
          .padding(5)
          .margin({ right: 6, bottom: 6 })
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
        .key((item: ResourceStr, index: number) => `${index}_${this.values[index]}`)
    }
    .width('100%')
  }
}

@Component
struct ValueSliderComponent {
  title: ResourceStr = ''
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
  @State effectLabels: ResourceStr[] = EFFECT_LABELS
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
  private pendingConfig: AudioEffectConfig | undefined = undefined
  private applyTimer: number = -1
  private applyVersion: number = 0

  aboutToAppear(): void {
    this.systemPlayer = this.isSystemPlayer?.() === true
    this.effectValues = EFFECT_VALUES.filter((value: string) =>
    !this.systemPlayer || (value !== 'hoa-space-render' && value !== 'audio-mixer'))
    this.effectLabels = this.effectValues.map((value: string): ResourceStr => {
      if (this.systemPlayer && value === 'tempo-pitch') {
        return $r('app.string.effect_pitch_shift')
      }
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
      Text($r('app.string.sweet_audio_effect'))
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
            Column({ space: 8 }) {
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
                Row({ space: 4 }) {
                  Repeat<string>(EQ_FREQ_LABELS)
                    .each((repeatItem: RepeatItem<string>) => {
                      Column({ space: 4 }) {
                        Text(`${this.eqGains[repeatItem.index]}`)
                          .fontSize(11)
                          .fontColor('#909399')
                          .height(16)
                        Slider({
                          value: this.eqGains[repeatItem.index],
                          min: -10,
                          max: 10,
                          step: 1,
                          style: SliderStyle.OutSet,
                          direction: Axis.Vertical
                        })
                          .selectedColor($r('app.color.main_color'))
                          .height(120)
                          .width(24)
                          .enableHapticFeedback(true)
                          .onChange((nextValue: number) => {
                            this.updateEqGain(repeatItem.index, nextValue)
                            this.applyCurrentConfig()
                          })
                        Text(repeatItem.item)
                          .fontSize(10)
                          .fontColor($r('app.color.text_color'))
                          .height(16)
                      }
                      .justifyContent(FlexAlign.Center)
                      .alignItems(HorizontalAlign.Center)
                    })
                    .key((item: string, index: number) => `${index}_${item}`)
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceAround)
              }
            }
            .width('100%')
            .padding(12)
            .borderRadius(16)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          } else if (this.effect === 'sound-field') {
            Column({ space: 8 }) {
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
            .width('100%')
            .padding(12)
            .borderRadius(16)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          } else if (this.effect === 'audio-separation') {
            Column({ space: 8 }) {
              TabSelector({
                labels: SEPARATION_LABELS,
                values: SEPARATION_VALUES,
                current: this.separationOutput,
                onSelect: (value: string): void => {
                  this.separationOutput = value
                  this.applyCurrentConfig()
                }
              })
              this.HintText($r('app.string.npu_hint'))
            }
            .width('100%')
            .padding(12)
            .borderRadius(16)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          } else if (this.effect === 'voice-beautifier') {
            Column({ space: 8 }) {
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
            .width('100%')
            .padding(12)
            .borderRadius(16)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          } else if (this.effect === 'environment') {
            Column({ space: 8 }) {
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
            .width('100%')
            .padding(12)
            .borderRadius(16)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          } else if (this.effect === 'space-render') {
            Column({ space: 8 }) {
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
                  title: $r('app.string.axis_x_m'),
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
                  title: $r('app.string.axis_y_m'),
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
                  title: $r('app.string.axis_z_m'),
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
                  title: $r('app.string.surround_period_s'),
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
                  title: $r('app.string.extension_radius_m'),
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
                  title: $r('app.string.extension_angle'),
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
            .width('100%')
            .padding(12)
            .borderRadius(16)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          } else if (this.effect === 'pure-voice-change') {
            Column({ space: 8 }) {
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
                title: $r('app.string.pitch_auto'),
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
            .width('100%')
            .padding(12)
            .borderRadius(16)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          } else if (this.effect === 'general-voice-change') {
            Column({ space: 8 }) {
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
            .width('100%')
            .padding(12)
            .borderRadius(16)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          } else if (this.effect === 'tempo-pitch') {
            Column({ space: 8 }) {
              if (!this.systemPlayer) {
                ValueSliderComponent({
                  title: $r('app.string.speed'),
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
                title: $r('app.string.pitch'),
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
              this.HintText(this.systemPlayer ? $r('app.string.tempo_pitch_hint') :
                $r('app.string.speed_change_hint'))
            }
            .width('100%')
            .padding(12)
            .borderRadius(16)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          } else if (this.effect === 'hoa-space-render') {
            Column({ space: 8 }) {
              TabSelector({
                labels: HOA_LABELS,
                values: HOA_VALUES,
                current: this.hoaLayout,
                onSelect: (value: string): void => {
                  this.hoaLayout = value
                  this.applyCurrentConfig()
                }
              })
              this.HintText($r('app.string.hoa_hint'))
            }
            .width('100%')
            .padding(12)
            .borderRadius(16)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          } else if (this.effect === 'noise-reduction') {
            Column({ space: 8 }) {
              this.HintText(this.systemPlayer ? $r('app.string.nr_hint_system') :
                $r('app.string.nr_hint_mpv'))
            }
            .width('100%')
            .padding(12)
            .borderRadius(16)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          } else if (this.effect === 'audio-mixer') {
            Column({ space: 8 }) {
              this.HintText($r('app.string.mixer_hint'))
            }
            .width('100%')
            .padding(12)
            .borderRadius(16)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          } else if (this.effect === 'off') {
            Column({ space: 8 }) {
              this.HintText(this.systemPlayer ? $r('app.string.space_hint_system') :
                $r('app.string.space_hint_mpv'))
            }
            .width('100%')
            .padding(12)
            .borderRadius(16)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          } else if (this.effect === 'preset') {
            Column({ space: 8 }) {
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
              this.HintText($r('app.string.preset_hint'))
            }
            .width('100%')
            .padding(12)
            .borderRadius(16)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .constraintSize({ maxHeight: 400 })
      .scrollBar(BarState.Auto)

      if (this.systemPlayer) {
        this.HintText($r('app.string.system_effect_hint'))
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
        Button($r('app.string.reset'))
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
        Button($r('app.string.off'))
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
  HintText(message: ResourceStr) {
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
    if (this.effect === 'preset') {
      return
    }
    const config = this.createConfig()
    if (this.systemPlayer) {
      config.tempo = 1
    }
    this.scheduleApply(config)
  }

  private scheduleApply(config: AudioEffectConfig): void {
    // Invalidate older completions immediately, including during debounce.
    ++this.applyVersion
    this.pendingConfig = config
    this.applyStatus = ''
    if (this.applyTimer !== -1) {
      clearTimeout(this.applyTimer)
    }
    this.applyTimer = setTimeout(() => this.flushPending(), 180)
  }

  private flushPending(): void {
    if (this.applyTimer !== -1) {
      clearTimeout(this.applyTimer)
    }
    this.applyTimer = -1
    const config = this.pendingConfig
    this.pendingConfig = undefined
    if (!config) {
      return
    }
    const version = ++this.applyVersion
    this.applyStatus = ''
    this.applyConfig(config, version)
  }

  private async applyConfig(config: AudioEffectConfig, version: number): Promise<void> {
    try {
      const applied = this.onApply ? await this.onApply(config, true) : false
      if (version === this.applyVersion) {
        this.applyStatus = applied ? '' : ToolsUtil.getStringResource($r('app.string.apply_failed_keep').id)
        if (!applied) {
          this.reportApplyFailure(config.effect, this.applyStatus)
        }
      }
    } catch (error) {
      if (version === this.applyVersion) {
        this.applyStatus = (error as Error).message || ToolsUtil.getStringResource($r('app.string.effect_apply_failed_keep').id)
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
