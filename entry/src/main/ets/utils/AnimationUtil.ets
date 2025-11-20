import curves from '@ohos.curves';
import Curves from '@ohos.curves';

export class XAnimation {
  private static mode: string = 'auto'

  public static setAnimation(mode: string) {
    XAnimation.mode = mode;
  }

  public static getAnimation(dir: 'left' | 'right' | 'up' | 'bottom', delay: number = 0, hasAnimate: boolean = true) {
    const MoveFromTop: object =
      TransitionEffect.OPACITY.animation(hasAnimate ? { duration: 200, curve: Curve.Ease, delay: delay } : undefined)
        .combine(TransitionEffect.translate({ x: 0, y: -100 })
          .animation(hasAnimate ? { curve: Curves.responsiveSpringMotion(0.4, 0.75), delay: delay } : undefined))
    const MoveFromBottom: object =
      TransitionEffect.OPACITY.animation(hasAnimate ? { duration: 200, curve: Curve.Ease, delay: delay } : undefined)
        .combine(TransitionEffect.translate({ x: 0, y: 100 })
          .animation(hasAnimate ? { curve: Curves.responsiveSpringMotion(0.4, 0.75), delay: delay } : undefined))
    const MoveFromStart: object =
      TransitionEffect.OPACITY.animation(hasAnimate ? { duration: 200, curve: Curve.Ease, delay: delay } : undefined)
        .combine(TransitionEffect.translate({ x: -100, y: 0 })
          .animation(hasAnimate ? { curve: Curves.responsiveSpringMotion(0.4, 0.75), delay: delay } : undefined))
    const MoveFromEnd: object =
      TransitionEffect.OPACITY.animation(hasAnimate ? { duration: 200, curve: Curve.Ease, delay: delay } : undefined)
        .combine(TransitionEffect.translate({ x: 100, y: 0 })
          .animation(hasAnimate ? { curve: Curves.responsiveSpringMotion(0.4, 0.75), delay: delay } : undefined))
    switch (XAnimation.mode) {
      case 'auto': {
        switch (dir) {
          case 'up':
            return MoveFromTop;
          case 'bottom':
            return MoveFromBottom;
          case 'left':
            return MoveFromStart;
          case 'right':
            return MoveFromEnd;
        }
      }
      case 'up':
        return MoveFromBottom;
      case 'bottom':
        return MoveFromTop;
      case 'left':
        return MoveFromEnd;
      case 'right':
        return MoveFromStart;
      default:
        return MoveFromBottom;
    }
  }

  public static runWithAnimation(
    fn: Function,
    animate: boolean = true,
    s1: number = 0.4,
    s2: number = 0.85): void {
    if (animate) {
      animateToImmediately({ curve: curves.springMotion(s1, s2) }, () => {
        fn();
      });
    } else {
      fn()
    }
  }

  public static getAnimationCurve(duration: number = 300, s1: number = 0.4, s2: number = 0.7): AnimateParam {
    return { duration: duration, curve: curves.springMotion(s1, s2) }
  }
}