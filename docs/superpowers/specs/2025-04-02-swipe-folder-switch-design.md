# 滑动切换文件夹功能设计

## 背景

当前视频列表页支持通过面包屑点击切换文件夹，用户希望在保持现有左右滑动手势（控制侧边栏）的基础上，添加滑动切换文件夹的功能，并与面包屑联动。

## 目标

1. 在视频内容区域添加滑动手势切换文件夹
2. 与现有侧边栏展开/收起手势共存
3. 面包屑导航随滑动实时更新高亮状态
4. 边界情况处理完善（第一个/最后一个文件夹）

## 设计细节

### 手势逻辑

| 当前文件夹位置 | 滑动方向 | 动作 |
|---------------|----------|------|
| 第一个文件夹 | 从左向右滑 | 打开侧边栏 |
| 第一个文件夹 | 从右向左滑 | 切换到下一个文件夹 |
| 中间文件夹 | 从左向右滑 | 切换到上一个文件夹 |
| 中间文件夹 | 从右向左滑 | 切换到下一个文件夹 |
| 最后一个文件夹 | 从左向右滑 | 切换到上一个文件夹 |
| 最后一个文件夹 | 从右向左滑 | 无动作（已是最后一个）|

### 关键约束

1. **侧边栏状态判断**：只有侧边栏收起时才响应文件夹切换手势
2. **手势优先级**：
   - 侧边栏收起时：文件夹切换手势生效
   - 侧边栏展开时：使用原有的侧边栏关闭手势（从侧边栏区域左滑）

### 面包屑联动

- 文件夹切换时，面包屑自动滚动到当前文件夹位置
- 当前文件夹高亮显示（已有逻辑）
- 切换动画：视频列表淡入淡出 + 面包屑位置调整

## 实现要点

### 1. 手势检测位置

在 `Index.ets` 的 `VideoView` 外层 `Stack`（第 353-408 行区域）添加新的滑动手势，与原有手势共存。

### 2. 状态判断逻辑

```typescript
// 伪代码
.onGesture(SwipeGesture({ direction: SwipeDirection.Horizontal })
  .onAction((event: GestureEvent) => {
    // 侧边栏展开时不响应
    if (this.sideBarController.visibility === Visibility.Visible) {
      return
    }

    const currentIndex = getCurrentFolderIndex()
    const isFirstFolder = currentIndex === 0
    const isLastFolder = currentIndex === folderList.length - 1
    const isSwipeRight = event.angle > -45 && event.angle < 45

    if (isSwipeRight) {
      if (isFirstFolder) {
        // 第一个文件夹右滑 -> 打开侧边栏
        this.sideBarController.open()
      } else {
        // 切换到上一个文件夹
        switchToFolder(currentIndex - 1)
      }
    } else {
      // 左滑
      if (!isLastFolder) {
        switchToFolder(currentIndex + 1)
      }
    }
  })
)
```

### 3. 文件夹切换动画

- 视频列表：`TransitionEffect.OPACITY` + 短时长（150ms）
- 面包屑：`Scroll` 组件滚动到对应位置，**当前文件夹居中显示**

### 4. 需要修改的文件

| 文件 | 修改内容 |
|------|----------|
| `entry/src/main/ets/pages/Index.ets` | 添加文件夹切换手势逻辑 |
| `entry/src/main/ets/component/VideoItemComponent/VideoViewComponent.ets` | 面包屑滚动联动（如需要） |

### 5. 边界情况处理

| 情况 | 处理方式 |
|------|----------|
| 只有一个文件夹 | 右滑打开侧边栏，左滑无响应 |
| 文件夹列表为空 | 不响应切换手势 |
| 搜索状态下 | **禁止切换**（保持当前搜索上下文） |
| 批量选择模式下 | 不响应切换手势 |

## 测试验证

1. **正常切换**：在各个文件夹位置左右滑动，验证切换到正确文件夹
2. **边界情况**：第一个文件夹右滑打开侧边栏，最后一个文件夹左滑无响应
3. **状态冲突**：侧边栏展开时不响应文件夹切换
4. **面包屑联动**：切换后面包屑正确高亮并滚动到可视区域
5. **其他功能**：搜索、批量选择状态下不干扰
