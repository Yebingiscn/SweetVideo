import curves from '@ohos.curves'
import Curves from '@ohos.curves'

/**
 * 动画工具类，提供统一的动画效果管理
 */
export class XAnimation {
  // 动画模式，默认为自动模式
  private static mode: string = 'auto'

  /**
   * 设置动画模式
   * @param mode 动画模式: 'auto'(自动), 'up'(向上), 'bottom'(向下), 'left'(向左), 'right'(向右)
   */
  public static setAnimation(mode: string) {
    XAnimation.mode = mode
  }

  /**
   * 根据方向获取对应的过渡动画效果
   * @param dir 动画进入方向: 'left' | 'right' | 'up' | 'bottom'
   * @param delay 动画延迟时间(毫秒)，默认为0
   * @param hasAnimate 是否启用动画，默认为true
   * @returns 对应方向的过渡动画效果对象
   */
  public static getAnimation(dir: 'left' | 'right' | 'up' | 'bottom',
    delay: number = 0,
    hasAnimate: boolean = true) {
    // 从上方进入的动画效果：透明度渐显 + 向上平移
    const MoveFromTop: object =
      TransitionEffect.OPACITY.animation(hasAnimate ? { duration: 200, curve: Curve.Ease, delay: delay } : undefined)
        .combine(TransitionEffect.translate({ x: 0, y: -100 })
          .animation(hasAnimate ? { curve: Curves.responsiveSpringMotion(0.4, 0.75), delay: delay } : undefined))
    
    // 从下方进入的动画效果：透明度渐显 + 向下平移
    const MoveFromBottom: object =
      TransitionEffect.OPACITY.animation(hasAnimate ? { duration: 200, curve: Curve.Ease, delay: delay } : undefined)
        .combine(TransitionEffect.translate({ x: 0, y: 100 })
          .animation(hasAnimate ? { curve: Curves.responsiveSpringMotion(0.4, 0.75), delay: delay } : undefined))
    
    // 从起始位置进入的动画效果：透明度渐显 + 向左平移
    const MoveFromStart: object =
      TransitionEffect.OPACITY.animation(hasAnimate ? { duration: 200, curve: Curve.Ease, delay: delay } : undefined)
        .combine(TransitionEffect.translate({ x: -100, y: 0 })
          .animation(hasAnimate ? { curve: Curves.responsiveSpringMotion(0.4, 0.75), delay: delay } : undefined))
    
    // 从结束位置进入的动画效果：透明度渐显 + 向右平移
    const MoveFromEnd: object =
      TransitionEffect.OPACITY.animation(hasAnimate ? { duration: 200, curve: Curve.Ease, delay: delay } : undefined)
        .combine(TransitionEffect.translate({ x: 100, y: 0 })
          .animation(hasAnimate ? { curve: Curves.responsiveSpringMotion(0.4, 0.75), delay: delay } : undefined))
    
    // 根据当前模式返回相应的动画效果
    switch (XAnimation.mode) {
      case 'auto': {
        // 自动模式：根据传入的方向选择对应动画
        switch (dir) {
          case 'up':
            return MoveFromTop
          case 'bottom':
            return MoveFromBottom
          case 'left':
            return MoveFromStart
          case 'right':
            return MoveFromEnd
        }
      }
      // 固定模式：无论传入什么方向，都返回指定的动画效果
      case 'up':
        return MoveFromBottom
      case 'bottom':
        return MoveFromTop
      case 'left':
        return MoveFromEnd
      case 'right':
        return MoveFromStart
      default:
        return MoveFromBottom
    }
  }

  /**
   * 执行带动画效果的函数
   * @param fn 需要执行的函数
   * @param animate 是否启用动画，默认为true
   * @param s1 弹簧动画的第一个参数，默认为0.4
   * @param s2 弹簧动画的第二个参数，默认为0.85
   */
  public static runWithAnimation(
    fn: Function,
    animate: boolean = true,
    s1: number = 0.4,
    s2: number = 0.85): void {
    if (animate) {
      // 使用弹簧动画执行函数
      animateToImmediately({ curve: curves.springMotion(s1, s2) }, () => {
        fn()
      })
    } else {
      // 不使用动画直接执行函数
      fn()
    }
  }

  /**
   * 获取动画曲线参数配置
   * @param duration 动画持续时间(毫秒)，默认为300
   * @param s1 弹簧动画的第一个参数，默认为0.4
   * @param s2 弹簧动画的第二个参数，默认为0.7
   * @returns 动画参数对象
   */
  public static getAnimationCurve(duration: number = 300, s1: number = 0.4, s2: number = 0.7): AnimateParam {
    return { duration: duration, curve: curves.springMotion(s1, s2) }
  }
}