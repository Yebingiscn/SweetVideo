// 产品接口 interface
interface PlayerControllerInterface {
  backForward(): void;

  fastForward(): void;
}

// 这里放 AVSession 的内容
abstract class BasePlayerController implements PlayerControllerInterface {
  // 公共方法实现
  backForward(): void {
    console.log('执行后退操作');
    // 公共的后退逻辑
  }

  fastForward(): void {
    console.log('执行快进操作');
    // 公共的快进逻辑
  }

  // 抽象方法，子类必须实现
  abstract play(): void;

  abstract pause(): void;
}

// 具体产品 controller/AVPlayer
@Observed
class VideoPlayerController implements PlayerControllerInterface {
  backForward() { /* 实现 */
  }

  fastForward() { /* 实现 */
  }
}

@Observed
class IJKPlayerController implements PlayerControllerInterface {
  backForward(): void {
    throw new Error('Method not implemented.');
  }

  fastForward(): void {
    throw new Error('Method not implemented.');
  }
}

// 真正的工厂 controller
class PlayerControllerFactory {
  createPlayerController(): VideoPlayerController {
    return new VideoPlayerController();
  }
}