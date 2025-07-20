import { SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil';
import TimeUtil from '../../utils/TimeUtil';

@Component
export struct SettingTimeItem {
  @State symbol: Resource | undefined = undefined
  @State message: ResourceStr = ''
  @StorageProp('disable_blur') disable_blur: boolean = false
  @State selectedIndex: number[] = [0, 0, 0, 0]
  @Prop selected: number = 0;
  private TenthsOfMinutes: string[] = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
  private UnitOfTMinutes: string[] = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
  private TenthsOfSecond: string[] = ['0', '1', '2', '3', '4', '5']
  private UnitOfSecond: string[] = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
  private multi: string[][] = [this.TenthsOfMinutes, this.UnitOfTMinutes, this.TenthsOfSecond, this.UnitOfSecond]
  onChange = (value: number) => {
    console.log(value.toString()); // 无实际作用，只是消除未使用警告
  }

  aboutToAppear() {
    const timeStr = this.convertToTimeFormat(this.selected);
    this.selectedIndex = this.timeToIndexes(timeStr);
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        SymbolGlyph(this.symbol)
          .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
        Text(this.message + ':')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
        Text(this.selected === 0 ? '不跳过' : TimeUtil.convertSSToMMSS(this.selected))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .width('100%') // 宽度充满父容器
      }
      .width('100%')
      .margin({ bottom: 10 }) // 与下部分间距

      TextPicker({ range: this.multi, selected: this.selectedIndex })
        .width('100%')// 宽度充满父容器
        .onChange((value: string | string[], index: number | number[]) => {
          if (Array.isArray(index)) {
            this.selectedIndex = index
            const minutes = parseInt(value[0] + value[1], 10);
            const seconds = parseInt(value[2] + value[3], 10);
            const totalSeconds = minutes * 60 + seconds;
            this.onChange(totalSeconds)
          }
        })
        .divider(null)
    }
    .backgroundColor($r('app.color.start_window_background_blur'))
    .borderRadius(16)
    .padding(15) // 统一内边距
    .margin({ top: 5, bottom: 5 })
  }

  private convertToTimeFormat(totalSeconds: number): string {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes.toString().padStart(2, '0')}${seconds.toString().padStart(2, '0')}`;
  }

  private timeToIndexes(timeStr: string): number[] {
    return timeStr.split('').map((char, i) => this.multi[i].indexOf(char));
  }
}