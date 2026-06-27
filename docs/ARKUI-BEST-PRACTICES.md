# ArkUI 最佳实践速查（从 DevEco Code Skills 提取）

> **来源**: DevEco Code `arkui-knowledge` Skill
> **原始文件**: `C:\Users\guo82\.local\share\deveco\skills\arkui-knowledge\references\`
> **用途**: 编写 ArkUI 代码前速查，避免高频错误

---

## 一、常见错误清单

### 1.1 Tabs / TabContent

```typescript
// ✅ 正确
Tabs({ barPosition: BarPosition.End }) {
  TabContent() {           // TabContent() 无参数
    Column() { Text('首页') }
  }.tabBar('首页')         // 标签内容放 .tabBar()
}
// ❌ 错误: TabContent 传对象参数
// ❌ 错误: 把组件直接放在 Tabs 下（不经过 TabContent）
```

### 1.2 ForEach / LazyForEach

```typescript
// ✅ 正确
ForEach(this.items, (item: ItemInfo) => {
  Text(item.title)
}, (item: ItemInfo) => item.id)   // key 必须返回稳定 string
// ❌ 错误: key 回调不返回值
// ❌ 错误: 用 index 做 key（顺序可能变）
// ⚠️ LazyForEach 必须配合 IDataSource 数据源
```

### 1.3 状态装饰器

```typescript
// ✅ 正确
@Component
struct MyComp {
  @State message: string = ''    // @State 只能在组件成员上
  @Prop inputVal: string = ''    // @Prop 父传子
  @Link twoWayVal: string        // @Link 双向绑定
}
// ❌ 错误: @State 放在局部变量/普通类/顶层变量
// ⚠️ V1(@State/@Prop/@Link) 和 V2(@Local/@Param) 不能混用
```

### 1.4 组件属性

```typescript
// ✅ 正确
Text('标题')
  .backgroundColor('#FFFFFF')
  .fontSize(16)
  .fontColor('#1a1a1a')
  .fontWeight(FontWeight.Bold)
// ❌ 错误: 用 CSS 缩写（bg, radius, size, color）
// ❌ 错误: 给 Text 加 .objectFit()（属于 Image）
// ❌ 错误: 传字符串替代枚举（应用 FontWeight.Bold 不是 "bold"）
```

### 1.5 对话框

```typescript
// ✅ 正确
this.getUIContext().showAlertDialog({
  title: '确认',
  message: '确认删除？',
  primaryButton: { value: '确定', action: () => {} },   // 按钮文字用 value
  secondaryButton: { value: '取消', action: () => {} }
})
// ❌ 错误: 按钮用 text 字段
// ✅ Toast
this.getUIContext().getPromptAction().showToast({ message: '已保存' })
```

## 二、API 护栏

### 2.1 组件构造器

| 组件 | 构造器参数 | 注意 |
|------|-----------|------|
| `Tabs(options?)` | `barPosition`, `index`, `controller` | — |
| `TabContent()` | **无参数** | 标签放 `.tabBar()` |
| `List({ space })` | space 为间距 | 子组件必须是 `ListItem` |
| `Grid()` | — | 子组件必须是 `GridItem` |
| `Row({ space })` | space 为间距 | — |
| `Column({ space })` | space 为间距 | — |
| `Flex()` | **无 space** | 用 margin 控制间距 |
| `Stack({ alignContent })` | 对齐方式 | 不用 row/column 对齐方法 |

### 2.2 修饰符归属

| 组件 | 拥有的修饰符 |
|------|-------------|
| `Text` | `.fontSize` `.fontColor` `.fontWeight` `.textAlign` `.maxLines` `.textOverflow` |
| `Image` | `.objectFit` |
| `Column`/`Row` | 布局对齐（枚举类型不同） |
| `List` | 方向/边缘/分割线/滚动 |
| `ListItem` | 行内容 |

### 2.3 margin/padding

```typescript
// ✅ 数字
.margin(12)
// ✅ 对象
.margin({ top: 10, bottom: 10, left: 16, right: 16 })
// ❌ 错误: CSS 风格多参数
// margin(10, 0, 10, 0)  ← 不支持
```

### 2.4 枚举值

- 必须用精确大小写：`TextAlign.Center`（非 `center`）
- `FontWeight.Bold`（非 `"bold"`）
- `BarPosition.End`（非 `"end"`）
- 不传字符串替代枚举

### 2.5 UIContext API

当项目已使用 UIContext 模式时：
- Toast: `this.getUIContext().getPromptAction().showToast(...)`
- 对话框: `this.getUIContext().showAlertDialog(...)`
- 路由: `this.getUIContext().getRouter()`
- 动画: `this.getUIContext().animateTo(...)`

## 三、UI 质量检查清单

1. 从启动页到每个必需元素的可见路径都能到达
2. 每个必需的点击都有对应的 UI 反馈
3. 状态变化后更新后的文字确实被渲染
4. 没有必需文字被遮罩层覆盖
5. 需要按钮的地方不用 Text 替代
6. Tab 标签在代码中存在且在 Tab 栏可见
7. 新增 UI 在启动页可达的导航路径内

## 四、组件用法速查

### TextInput + Button + 状态刷新

```typescript
@State userName: string = ''
@State errorText: string = ''

Column({ space: 12 }) {
  TextInput({ placeholder: '请输入用户名', text: this.userName })
    .onChange((value: string) => {
      this.userName = value
    })
  Button('注册')
    .onClick(() => {
      this.errorText = this.userName.length === 0 ? '请填写完整信息' : '注册成功'
    })
  Text(this.errorText)
    .fontColor(this.errorText === '注册成功' ? Color.Green : Color.Red)
}
```

### List + ForEach

```typescript
List({ space: 10 }) {
  ForEach(this.items, (item: ItemInfo) => {
    ListItem() {
      Text(item.title)
    }
  }, (item: ItemInfo) => item.id)
}
```

### Grid + ForEach

```typescript
Grid() {
  ForEach(this.cards, (item: CardItem) => {
    GridItem() {
      Text(item.title)
    }
  }, (item: CardItem) => item.id)
}
```
