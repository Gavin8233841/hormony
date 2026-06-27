# 鸿学伴鸿蒙端公共组件库设计

> **创建时间**: 2026-06-27
> **创建者**: Trae (Work) — 并行协助
> **状态**: 设计文档，待 IDE 实现时参考
> **注意**: 本文档为新建文件，不修改任何 IDE 正在编辑的 ETS 文件

---

## 一、设计目标

当前 6 个页面存在大量重复的 UI 结构，提取为公共组件可：
1. 减少代码重复（Index 5 个功能入口、Profile 3 个统计卡片结构高度重复）
2. 统一视觉规范（颜色、圆角、间距一致）
3. 便于后续维护（改一处生效全局）

## 二、组件清单

### 2.1 StatCard — 统计卡片

**使用场景**: Index 首页（提问数/正确率/学习天数）、Profile 画像页（正确率/答题数/学习天数）

```typescript
// common/components/StatCard.ets

@Component
export struct StatCard {
  @Prop value: string;      // 统计数值
  @Prop label: string;      // 统计标签
  @Prop color: string;      // 数值颜色（功能色）
  @Prop icon: Resource;     // 图标（可选）

  build() {
    Column({ space: 6 }) {
      if (this.icon) {
        Image(this.icon).width(20).height(20)
      }
      Text(this.value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.color)
      Text(this.label)
        .fontSize(12)
        .fontColor('#929292')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#ffffff')
    .borderRadius(12)
    .alignItems(HorizontalAlign.Center)
  }
}
```

### 2.2 FunctionEntry — 功能入口项

**使用场景**: Index 首页 5 个功能入口

```typescript
// common/components/FunctionEntry.ets

@Component
export struct FunctionEntry {
  @Prop title: string;       // 功能名称
  @Prop desc: string;        // 功能描述
  @Prop borderColor: string; // 左边框颜色
  target: string;            // 路由目标
  onClick: (target: string) => void = () => {};

  build() {
    Row({ space: 12 }) {
      Divider()
        .vertical()
        .strokeWidth(3)
        .color(this.borderColor)
        .height(36)
      Column({ space: 4 }) {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1a1a1a')
        Text(this.desc)
          .fontSize(12)
          .fontColor('#929292')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›')
        .fontSize(20)
        .fontColor('#cccccc')
    }
    .width('100%')
    .padding({ left: 12, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#ffffff')
    .borderRadius(12)
    .onClick(() => this.onClick(this.target))
  }
}
```

### 2.3 TagChip — 标签组件

**使用场景**: Course 知识点标签、Profile 薄弱/已掌握标签、Plan 任务类型标签

```typescript
// common/components/TagChip.ets

@Component
export struct TagChip {
  @Prop text: string;
  @Prop bgColor: string;    // 背景色（含透明度）
  @Prop textColor: string;  // 文字色

  build() {
    Text(this.text)
      .fontSize(11)
      .fontColor(this.textColor)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(this.bgColor)
      .borderRadius(10)
  }
}
```

### 2.4 LoadingState — 三态加载

**使用场景**: 所有数据加载页面（Course/Profile/Knowledge/Plan）

```typescript
// common/components/LoadingState.ets

@Component
export struct LoadingState {
  @Prop loading: boolean;
  @Prop error: string;
  @Prop empty: boolean;
  @Prop emptyText: string;
  onRetry: () => void = () => {};

  build() {
    if (this.loading) {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(40)
          .height(40)
          .color('#0a59f7')
        Text('加载中...')
          .fontSize(14)
          .fontColor('#929292')
      }
      .width('100%')
      .padding(40)
      .alignItems(HorizontalAlign.Center)
    } else if (this.error.length > 0) {
      Column({ space: 12 }) {
        Text('⚠')
          .fontSize(32)
          .fontColor('#e53935')
        Text(this.error)
          .fontSize(14)
          .fontColor('#929292')
        Text('点击重试')
          .fontSize(14)
          .fontColor('#0a59f7')
          .onClick(() => this.onRetry())
      }
      .width('100%')
      .padding(40)
      .alignItems(HorizontalAlign.Center)
    } else if (this.empty) {
      Column({ space: 8 }) {
        Text('📭')
          .fontSize(32)
        Text(this.emptyText || '暂无数据')
          .fontSize(14)
          .fontColor('#929292')
      }
      .width('100%')
      .padding(40)
      .alignItems(HorizontalAlign.Center)
    }
  }
}
```

### 2.5 ProgressBar — 进度条

**使用场景**: Course 课程进度、Plan 计划完成度

```typescript
// common/components/ProgressBar.ets

@Component
export struct ProgressBar {
  @Prop progress: number;    // 0.0 - 1.0
  @Prop color: string;       // 进度色
  @Prop trackColor: string;  // 轨道色
  @Prop height: number;      // 高度 vp

  build() {
    Stack({ alignContent: Alignment.Start }) {
      // 轨道
      Column()
        .width('100%')
        .height(this.height || 8)
        .backgroundColor(this.trackColor || '#e8e8e8')
        .borderRadius((this.height || 8) / 2)

      // 进度
      Column()
        .width((Math.min(Math.max(this.progress, 0), 1) * 100) + '%')
        .height(this.height || 8)
        .backgroundColor(this.color || '#4caf50')
        .borderRadius((this.height || 8) / 2)
    }
    .width('100%')
  }
}
```

### 2.6 PageHeader — 页面标题栏

**使用场景**: 所有二级页面（Chat/Course/Plan/Knowledge/Profile）

```typescript
// common/components/PageHeader.ets

@Component
export struct PageHeader {
  @Prop title: string;
  @Prop subtitle: string;
  onBack: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Text('‹')
        .fontSize(24)
        .fontColor('#1a1a1a')
        .onClick(() => this.onBack())

      Column({ space: 4 }) {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a1a')
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(12)
            .fontColor('#929292')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 12 })
    .backgroundColor('#f5f6f8')
  }
}
```

## 三、组件使用示例

### Index.ets 改造前后对比

**改造前**（5 个功能入口约 130 行重复代码）:
```typescript
// 每个入口都是 30 行的 Row 结构，仅文案/颜色/路由不同
Row({ space: 12 }) {
  Divider().vertical().strokeWidth(3).color('#0a59f7').height(36)
  Column({ space: 4 }) {
    Text('问问鸿学伴').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#1a1a1a')
    Text('AI 辅导 · 多轮对话').fontSize(12).fontColor('#929292')
  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
  Text('›').fontSize(20).fontColor('#cccccc')
}.width('100%').padding({...}).backgroundColor('#ffffff').borderRadius(12)
  .onClick(() => { router.pushUrl({ url: 'pages/Chat' }) })
// ... 重复 4 次 ...
```

**改造后**（使用 FunctionEntry 组件）:
```typescript
FunctionEntry({ title: '问问鸿学伴', desc: 'AI 辅导 · 多轮对话', borderColor: '#0a59f7', target: 'pages/Chat', onClick: (t: string) => { router.pushUrl({ url: t }) } })
FunctionEntry({ title: '学习计划', desc: '目标拆解 · 每日任务', borderColor: '#4caf50', target: 'pages/Plan', onClick: (t: string) => { router.pushUrl({ url: t }) } })
FunctionEntry({ title: '搜课程资料', desc: '知识库 · 语义搜索', borderColor: '#ff9800', target: 'pages/Knowledge', onClick: (t: string) => { router.pushUrl({ url: t }) } })
FunctionEntry({ title: '我的课程', desc: '进度追踪 · 资料管理', borderColor: '#9c27b0', target: 'pages/Course', onClick: (t: string) => { router.pushUrl({ url: t }) } })
FunctionEntry({ title: '学习画像', desc: '数据分析 · 个性化推荐', borderColor: '#00bcd4', target: 'pages/Profile', onClick: (t: string) => { router.pushUrl({ url: t }) } })
```

约 130 行 → 5 行，减少 96% 重复代码。

## 四、文件结构

```
entry/src/main/ets/common/components/
├── StatCard.ets          # 统计卡片
├── FunctionEntry.ets     # 功能入口项
├── TagChip.ets           # 标签
├── LoadingState.ets      # 三态加载
├── ProgressBar.ets       # 进度条
└── PageHeader.ets        # 页面标题栏
```

## 五、实施建议

1. **时机**: IDE 完成当前 loop 后，在下一轮 loop 中实施
2. **步骤**: 先创建 6 个组件文件 → 逐页面替换 → 构建验证 → 截图验证
3. **风险**: 低 — 纯结构提取，不改业务逻辑
4. **注意**: @Component 组件的 @Prop 不可在子组件内修改；事件回调用函数属性传递

## 六、与设计系统对齐

所有组件的颜色值对齐 `docs/FRONTEND-INTERACTION-FRAMEWORK.md` 的设计系统：
- 背景色: `#f5f6f8`
- 卡片色: `#ffffff`
- 主文字: `#1a1a1a`
- 次文字: `#929292`
- 品牌色: `#0a59f7`
- 成功绿: `#4caf50`
- 警告橙: `#ff9800`
- 错误红: `#e53935`
- 圆角: 12vp
