/**
 * 事件回调函数类型定义
 */
type EventCallback<T> = (data: T) => void;

/**
 * 事件监听器基础接口
 */
interface BaseEventListener<T> {
  id: string;
  once: boolean;
  callback: EventCallback<T>;
}

export class BaseListener<T> {
  private dataEvents: Map<string, BaseEventListener<T>[]> = new Map();

  /**
   * @param eventName 事件名称
   * @param callback 回调函数
   * @param once 是否只执行一次，默认false
   * @returns 取消订阅的函数
   */
  on(eventName: string, callback: EventCallback<T>, once: boolean = false): () => void {
    const listenerId = this.generateId();
    const listener: BaseEventListener<T> = {
      id: listenerId,
      callback,
      once
    };

    if (!this.dataEvents.has(eventName)) {
      this.dataEvents.set(eventName, []);
    }

    const listeners = this.dataEvents.get(eventName);
    if (listeners) {
      listeners.push(listener);
    }

    return () => this.off(eventName, listenerId);
  }

  /**
   * 订阅带数据的事件（只执行一次）
   * @param eventName 事件名称
   * @param callback 回调函数
   * @returns 取消订阅的函数
   */
  once(eventName: string, callback: EventCallback<T>): () => void {
    return this.on(eventName, callback, true);
  }

  off(eventName: string, listenerId?: string): void {
    // 处理数据事件
    const dataListeners = this.dataEvents.get(eventName);
    if (dataListeners) {
      if (listenerId) {
        const index = dataListeners.findIndex(listener => listener.id === listenerId);
        if (index !== -1) {
          dataListeners.splice(index, 1);
          if (dataListeners.length === 0) {
            this.dataEvents.delete(eventName);
          }
          return;
        }
      } else {
        this.dataEvents.delete(eventName);
      }
    }
  }

  /**
   * 发布事件
   * @param eventName 事件名称
   * @param data 事件数据
   */
  emit(eventName: string, data: T): void {
    const listeners = this.dataEvents.get(eventName);
    if (!listeners || listeners.length === 0) {
      return;
    }

    const listenersToExecute = [...listeners];

    listenersToExecute.forEach(listener => {
      try {
        (listener.callback as EventCallback<T>)(data);
        if (listener.once) {
          this.off(eventName, listener.id);
        }
      } catch (error) {
        console.error(`事件回调执行错误 [${eventName}]:`, error);
      }
    });
  }

  /**
   * 检查是否有事件监听器
   * @param eventName 事件名称
   * @returns 是否存在监听器
   */
  hasListeners(eventName: string): boolean {
    const dataListeners = this.dataEvents.get(eventName);
    // const voidListeners = this.voidEvents.get(eventName);

    const hasDataListeners = dataListeners ? dataListeners.length > 0 : false;
    // const hasVoidListeners = voidListeners ? voidListeners.length > 0 : false;

    return hasDataListeners
  }

  /**
   * 获取事件监听器数量
   * @param eventName 事件名称（可选，不传则返回所有事件的监听器总数）
   * @returns 监听器数量
   */
  getListenerCount(eventName?: string): number {
    if (eventName) {
      const dataCount = this.dataEvents.get(eventName)?.length || 0;
      return dataCount;
    }
    let total = 0;
    this.dataEvents.forEach(listeners => total += listeners.length);
    return total;
  }

  /**
   * 获取所有事件名称
   * @returns 事件名称数组
   */
  getEventNames(): string[] {
    const dataEventNames = Array.from(this.dataEvents.keys());
    return dataEventNames
  }

  /**
   * 清除所有事件监听器
   */
  clear(): void {
    this.dataEvents.clear();
  }

  /**
   * 清除指定事件的所有监听器
   * @param eventName 事件名称
   */
  clearEvent(eventName: string): void {
    this.dataEvents.delete(eventName);
    // this.voidEvents.delete(eventName);
  }

  /**
   * 生成唯一ID
   * @returns 唯一ID字符串
   */
  private generateId(): string {
    return `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}