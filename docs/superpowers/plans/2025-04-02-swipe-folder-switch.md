# 滑动切换文件夹功能实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在视频列表页添加滑动手势切换文件夹功能，与面包屑联动，同时保持现有侧边栏手势。

**Architecture:** 在 Index.ets 的 VideoView 外层 Stack 添加新的滑动手势，通过侧边栏状态判断手势优先级。当侧边栏收起时，根据当前文件夹位置和滑动方向执行切换或打开侧边栏。面包屑通过 Scroll 组件滚动到当前文件夹居中位置。

**Tech Stack:** ArkTS, ArkUI, HarmonyOS SDK

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `entry/src/main/ets/pages/Index.ets` | 主页面，添加文件夹切换手势逻辑 |
| `entry/src/main/ets/component/VideoItemComponent/VideoViewComponent.ets` | 面包屑组件，添加滚动到指定文件夹方法 |

---

## Task 1: 在 Index.ets 添加文件夹切换手势

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets:372-381`

- [ ] **Step 1: 在 Index 类中添加文件夹切换辅助方法**

在 Index 类中添加获取当前文件夹索引和切换文件夹的方法：

```typescript
// 在 Index 类中，约第 76 行后添加（passwd 变量之后）

/**
 * 获取当前文件夹在列表中的索引
 */
private getCurrentFolderIndex(): number {
  return this.file_folder_list.findIndex(
    folder => folder.date === this.videoListController.folder.date
  )
}

/**
 * 切换到指定索引的文件夹
 */
private switchToFolder(index: number): void {
  if (index < 0 || index >= this.file_folder_list.length) {
    return
  }

  const targetFolder = this.file_folder_list[index]
  if (this.videoListController.folder.date === targetFolder.date) {
    return
  }

  // 清除搜索状态
  this.searchValue = ''

  // 刷新文件夹列表（确保数据最新）
  this.file_folder_list = Preferences.getFileFolder(PathUtils.appContext!)
  this.fileFolderSource.updateData(this.file_folder_list)

  // 获取目标文件夹的最新数据
  const currentFolder = this.fileFolderSource.getFileFolder(targetFolder.name)
  if (currentFolder) {
    this.videoListController.videoDataSource.updateData(currentFolder.video_list)
    this.videoListController.updateData(
      this.videoListController.videoDataSource,
      currentFolder
    )
  }
}

/**
 * 处理文件夹切换滑动手势
 */
private handleFolderSwipe(event: GestureEvent): void {
  // 搜索状态下禁止切换
  if (this.searchValue.length > 0) {
    return
  }

  // 批量选择模式下禁止切换
  if (this.videoListController.multipleChooseState === Visibility.Visible) {
    return
  }

  // 侧边栏展开时不响应
  if (this.sideBarController.visibility === Visibility.Visible) {
    return
  }

  // 文件夹列表为空或只有一个时不切换
  if (this.file_folder_list.length <= 1) {
    return
  }

  const rotateAngle = event?.angle ?? 0
  const currentIndex = this.getCurrentFolderIndex()
  const isFirstFolder = currentIndex === 0
  const isLastFolder = currentIndex === this.file_folder_list.length - 1

  // 判断滑动方向：角度在 -45° ~ 45° 之间为向右滑
  const isSwipeRight = rotateAngle > -45 && rotateAngle < 45

  if (isSwipeRight) {
    // 从左向右滑
    if (isFirstFolder) {
      // 第一个文件夹右滑 -> 打开侧边栏
      this.sideBarController.open()
    } else {
      // 切换到上一个文件夹
      this.switchToFolder(currentIndex - 1)
    }
  } else {
    // 从右向左滑
    if (!isLastFolder) {
      this.switchToFolder(currentIndex + 1)
    }
  }
}
```

- [ ] **Step 2: 修改现有手势，添加文件夹切换逻辑**

找到现有的 priorityGesture（约第 372 行），修改为：

```typescript
.priorityGesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent) => {
  // 调用文件夹切换处理
  this.handleFolderSwipe(event)
}))
```

**注意**：原有的侧边栏展开/收起逻辑已整合到 `handleFolderSwipe` 方法中。

- [ ] **Step 3: 编译检查**

Run: `hvigorw assembleHap --mode debug`
Expected: 编译成功，无错误

- [ ] **Step 4: Commit**

```bash
git add entry/src/main/ets/pages/Index.ets
git commit -m "[new] 添加滑动切换文件夹手势，与侧边栏手势共存"
```

---

## Task 2: 添加面包屑滚动联动（居中显示）

**Files:**
- Modify: `entry/src/main/ets/component/VideoItemComponent/VideoViewComponent.ets`

- [ ] **Step 1: 在 VideoView 中添加 Scroll 控制器和滚动方法**

在 VideoView 类中（约第 30 行后），添加：

```typescript
// 面包屑滚动控制器
@State breadcrumbScroller: Scroller = new Scroller()
```

- [ ] **Step 2: 修改面包屑 Scroll 组件，绑定控制器**

找到面包屑的 Scroll 组件（约第 165-195 行），修改为：

```typescript
Scroll(this.breadcrumbScroller) {
  // 原有内容不变
}
.width('100%')
.scrollBar(BarState.Off)
.scrollable(ScrollDirection.Horizontal)
.edgeEffect(EdgeEffect.Spring)
```

- [ ] **Step 3: 添加滚动到指定文件夹的方法**

在 VideoView 类中添加方法：

```typescript
/**
 * 滚动面包屑使指定文件夹居中显示
 */
scrollBreadcrumbToFolder(folderDate: number): void {
  // 获取目标文件夹在列表中的索引
  const folderIndex = this.file_folder_list.findIndex(f => f.date === folderDate)
  if (folderIndex === -1) {
    return
  }

  // 计算每个文件夹项的大致宽度（包含间距）
  // 根据实际布局，Text 组件宽度变化，这里使用估算值
  const estimatedItemWidth = 80 // 估算每个文件夹名称的平均宽度
  const spacing = 15 // Row 中的 space: 15
  const targetOffset = folderIndex * (estimatedItemWidth + spacing)

  // 获取 Scroll 组件宽度（近似值，实际由布局决定）
  // 使用动画平滑滚动到目标位置
  animateTo({
    duration: 200,
    curve: Curve.Ease
  }, () => {
    this.breadcrumbScroller.scrollTo({
      xOffset: targetOffset,
      yOffset: 0,
      animation: { duration: 200, curve: Curve.Ease }
    })
  })
}
```

- [ ] **Step 4: 暴露方法供外部调用**

为了让 Index 能调用这个方法，需要在 VideoViewController 中添加回调，或者通过其他方式通信。这里采用更简单的方式：在 Index 中直接操作面包屑的滚动。

由于 VideoView 是子组件，Index 需要通过 `@State` 或方法来控制。我们修改方案：在 Index 中保存当前文件夹的索引状态，VideoView 通过 `@Watch` 监听并自动滚动。

在 `VideoViewComponent.ets` 中，修改 `folder` 属性的监听：

```typescript
// 在 VideoView 类中添加
@Watch('onFolderChanged') @Link folder: FileFolder

// 添加监听回调
onFolderChanged(): void {
  // 文件夹变化时触发面包屑滚动
  this.scrollBreadcrumbToFolder(this.folder.date)
}
```

但这样需要修改 Index 传递 folder 的方式。更简单的方案是：在 `VideoListController` 更新时触发。

实际上，面包屑已经通过 `this.videoListController.folder` 绑定了当前文件夹。我们可以在 VideoView 的 `aboutToAppear` 或 `onFolderChanged` 中处理。

简化方案：直接在 `VideoView` 的 `build` 中使用 `onAreaChange` 或监听 folder 变化。

实际上，观察代码发现 `videoListController` 是 `@Link`，其 `folder` 属性变化时不会自动触发 VideoView 的更新。我们需要在 Index 的 `switchToFolder` 方法调用后，主动触发面包屑滚动。

修改方案：通过 `AppStorage` 或事件机制。但为了简单，我们直接在 Index 的 `switchToFolder` 方法中，在切换文件夹后调用一个方法来滚动面包屑。

由于 VideoView 是子组件，Index 可以通过 `@ViewChild` 方式访问，但 ArkTS 中没有这个装饰器。我们可以：

1. 通过回调函数
2. 通过 AppStorage 设置一个触发滚动的 key
3. 通过事件总线

这里选择最简单的：在 Index 中维护一个状态，通过 Props 传递给 VideoView，VideoView 监听变化后滚动。

修改 `VideoViewComponent.ets`：

```typescript
// 添加新的 Prop
@Prop @Watch('onScrollToFolder') scrollToFolderDate: number = 0

onScrollToFolder(): void {
  if (this.scrollToFolderDate > 0) {
    this.scrollBreadcrumbToFolder(this.scrollToFolderDate)
  }
}
```

然后在 Index 中传递：

```typescript
// Index.ets 中添加状态
@State scrollToFolderDate: number = 0

// switchToFolder 方法中，切换后设置
this.scrollToFolderDate = targetFolder.date
```

但由于切换可能很快，需要确保每次都能触发。可以使用时间戳或其他方式。

重新考虑：由于 `videoListController.folder` 是引用类型，每次 `updateData` 都会更新它，我们可以在 VideoView 中监听 `videoListController` 的 `folder` 变化。

ArkTS 中 `@Link` 对象属性变化不会触发重新渲染。但我们可以通过计算属性或监听来实现。

实际上，最简单的方式是：在 VideoView 的 `build` 方法开头，根据当前 folder 计算并滚动。但这会在每次渲染时执行。

最终决定：在 Index.ets 的 `switchToFolder` 方法中，使用 `AppStorage` 触发滚动。

```typescript
// switchToFolder 方法末尾添加
AppStorage.setOrCreate('scrollToFolderDate', targetFolder.date)
```

在 VideoView 中监听：

```typescript
// 添加状态监听
@StorageLink('scrollToFolderDate') scrollToFolderDate: number = 0

@Watch('onScrollToFolder')
onScrollToFolder(): void {
  if (this.scrollToFolderDate > 0 && this.file_folder_list.length > 0) {
    this.scrollBreadcrumbToFolder(this.scrollToFolderDate)
  }
}
```

- [ ] **Step 5: 实现滚动方法**

根据上面的设计，在 `VideoViewComponent.ets` 中：

1. 添加 `@StorageLink` 监听
2. 实现 `scrollBreadcrumbToFolder` 方法
3. 添加 `breadcrumbScroller` 控制器
4. 修改 Scroll 组件绑定控制器

- [ ] **Step 6: 在 Index.ets 中触发滚动**

在 `switchToFolder` 方法末尾添加：

```typescript
AppStorage.setOrCreate('scrollToFolderDate', targetFolder.date)
```

- [ ] **Step 7: 编译检查**

Run: `hvigorw assembleHap --mode debug`
Expected: 编译成功，无错误

- [ ] **Step 8: Commit**

```bash
git add entry/src/main/ets/pages/Index.ets entry/src/main/ets/component/VideoItemComponent/VideoViewComponent.ets
git commit -m "[new] 文件夹切换时面包屑自动滚动居中"
```

---

## Task 3: 代码检查和优化

- [ ] **Step 1: 运行代码规范检查**

Run: `codelinter -c code-linter.json5 -o codelinter-report.txt entry/src/main/ets`
Expected: 无错误（或修复所有错误）

- [ ] **Step 2: 设备部署验证**

构建并安装到设备：

```bash
hvigorw assembleHap && \
  hdc app install entry/build/default/outputs/default/entry-default-signed.hap && \
  hdc shell aa start -a EntryAbility -b cn.kimufly.sweetvideo
```

- [ ] **Step 3: 功能验证清单**

| 测试项 | 预期结果 |
|--------|----------|
| 第一个文件夹从左向右滑 | 打开侧边栏 |
| 第一个文件夹从右向左滑 | 切换到第二个文件夹 |
| 中间文件夹左右滑动 | 正确切换到上一个/下一个 |
| 最后一个文件夹从右向左滑 | 无响应（已是最后一个） |
| 侧边栏展开时滑动 | 不切换文件夹 |
| 搜索状态下滑动 | 不切换文件夹 |
| 批量选择模式下滑动 | 不切换文件夹 |
| 面包屑跟随滚动 | 切换后当前文件夹居中 |

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "[update] 滑动切换文件夹功能完成，通过设备验证"
```

---

## 附录：完整代码变更参考

### Index.ets 新增方法

```typescript
// 在 Index 类中添加以下方法

/**
 * 获取当前文件夹在列表中的索引
 */
private getCurrentFolderIndex(): number {
  return this.file_folder_list.findIndex(
    folder => folder.date === this.videoListController.folder.date
  )
}

/**
 * 切换到指定索引的文件夹
 */
private switchToFolder(index: number): void {
  if (index < 0 || index >= this.file_folder_list.length) {
    return
  }

  const targetFolder = this.file_folder_list[index]
  if (this.videoListController.folder.date === targetFolder.date) {
    return
  }

  // 清除搜索状态
  this.searchValue = ''

  // 刷新文件夹列表（确保数据最新）
  this.file_folder_list = Preferences.getFileFolder(PathUtils.appContext!)
  this.fileFolderSource.updateData(this.file_folder_list)

  // 获取目标文件夹的最新数据
  const currentFolder = this.fileFolderSource.getFileFolder(targetFolder.name)
  if (currentFolder) {
    this.videoListController.videoDataSource.updateData(currentFolder.video_list)
    this.videoListController.updateData(
      this.videoListController.videoDataSource,
      currentFolder
    )
  }

  // 触发面包屑滚动
  AppStorage.setOrCreate('scrollToFolderDate', targetFolder.date)
}

/**
 * 处理文件夹切换滑动手势
 */
private handleFolderSwipe(event: GestureEvent): void {
  // 搜索状态下禁止切换
  if (this.searchValue.length > 0) {
    return
  }

  // 批量选择模式下禁止切换
  if (this.videoListController.multipleChooseState === Visibility.Visible) {
    return
  }

  // 侧边栏展开时不响应
  if (this.sideBarController.visibility === Visibility.Visible) {
    return
  }

  // 文件夹列表为空或只有一个时不切换
  if (this.file_folder_list.length <= 1) {
    return
  }

  const rotateAngle = event?.angle ?? 0
  const currentIndex = this.getCurrentFolderIndex()
  const isFirstFolder = currentIndex === 0
  const isLastFolder = currentIndex === this.file_folder_list.length - 1

  // 判断滑动方向：角度在 -45° ~ 45° 之间为向右滑
  const isSwipeRight = rotateAngle > -45 && rotateAngle < 45

  if (isSwipeRight) {
    // 从左向右滑
    if (isFirstFolder) {
      // 第一个文件夹右滑 -> 打开侧边栏
      this.sideBarController.open()
    } else {
      // 切换到上一个文件夹
      this.switchToFolder(currentIndex - 1)
    }
  } else {
    // 从右向左滑
    if (!isLastFolder) {
      this.switchToFolder(currentIndex + 1)
    }
  }
}
```

### VideoViewComponent.ets 新增

```typescript
// 在 VideoView 类中添加
@State breadcrumbScroller: Scroller = new Scroller()
@StorageLink('scrollToFolderDate') scrollToFolderDate: number = 0

@Watch('onScrollToFolder')
onScrollToFolder(): void {
  if (this.scrollToFolderDate > 0 && this.file_folder_list.length > 0) {
    this.scrollBreadcrumbToFolder(this.scrollToFolderDate)
  }
}

/**
 * 滚动面包屑使指定文件夹居中显示
 */
scrollBreadcrumbToFolder(folderDate: number): void {
  const folderIndex = this.file_folder_list.findIndex(f => f.date === folderDate)
  if (folderIndex === -1) {
    return
  }

  // 估算每个文件夹项的宽度（包含间距）
  const estimatedItemWidth = 80
  const spacing = 15
  const targetOffset = Math.max(0, folderIndex * (estimatedItemWidth + spacing) - 100)

  this.breadcrumbScroller.scrollTo({
    xOffset: targetOffset,
    yOffset: 0,
    animation: { duration: 200, curve: Curve.Ease }
  })
}
```

### 手势绑定修改

```typescript
// Index.ets 第 372 行附近
.priorityGesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent) => {
  this.handleFolderSwipe(event)
}))
```

### 面包屑 Scroll 绑定

```typescript
// VideoViewComponent.ets 第 165 行附近
Scroll(this.breadcrumbScroller) {
  // ...
}
```
