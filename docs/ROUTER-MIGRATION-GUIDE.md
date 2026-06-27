# Router → Navigation 迁移指南

> **来源**: DevEco Code `arkts_knowledge_search` 工具返回（2026-06-27）
> **用途**: 当 Codex 决定迁移路由系统时参考此文档
> **注意**: 迁移是 Codex 的架构决策，当前阶段不执行

---

## 核心用法

### Navigation（路由容器）

```typescript
Navigation(pageStack) {
  // 根页面内容
}.mode(NavigationMode.Stack)
```

### NavPathStack（路由栈控制）

```typescript
let stack: NavPathStack = new NavPathStack()
stack.pushPathByName('PageA', { id: 1 })  // 入栈
stack.pop()                                 // 出栈（返回）
stack.replacePathByName('PageB', null)      // 替换当前页
```

### NavDestination（页面容器）

```typescript
NavDestination() {
  // 页面内容
}
.onReady((ctx) => {
  this.stack = ctx.pathStack
})
```

### navPath 参数获取

```typescript
this.stack.getParamByIndex(this.stack.size() - 1)  // 按索引
this.stack.getParamByName('PageA')                   // 按名称
```

---

## 迁移步骤

### 第 1 步: 建路由表

创建 `route_map.json`（name → 页面 Builder 映射）

### 第 2 步: 根页面改造

将 Index.ets 的根容器改为 `Navigation + NavPathStack`

### 第 3 步: 页面改造

各页面从 `@Entry @Component` 改为 `NavDestination + @Builder`

### 第 4 步: 跳转替换

| 旧代码 | 新代码 |
|--------|--------|
| `router.pushUrl({ url: 'pages/Chat' })` | `stack.pushPathByName('Chat', null)` |
| `router.back()` | `stack.pop()` |

### 第 5 步: 参数获取替换

| 旧代码 | 新代码 |
|--------|--------|
| `router.getParams()` | `NavPathStack.getParamByIndex()` 或 `getParamByName()` |

### 第 6 步: 注意事项

- 子页面必须用 `onReady` 获取 `pathStack`，**不能自己 new NavPathStack**
- `main_pages.json` 路由注册可能需要调整
- 所有页面的 `import router from '@ohos.router'` 需移除

---

## 当前项目影响分析

### 需要修改的文件

| 文件 | 当前 | 迁移后 |
|------|------|--------|
| Index.ets | 5 处 `router.pushUrl` | `stack.pushPathByName` |
| Chat.ets | `router.back()` | `stack.pop()` |
| Course.ets | `router.back()` | `stack.pop()` |
| Plan.ets | `router.back()` | `stack.pop()` |
| Knowledge.ets | `router.back()` | `stack.pop()` |
| Profile.ets | `router.back()` | `stack.pop()` |

共 10 处调用 + 6 处 import 需要修改。

### 迁移风险

- 低风险：纯路由替换，不涉及业务逻辑
- 需测试：页面间传参（当前无传参，迁移后可添加）
- 需测试：返回行为（`stack.pop()` vs `router.back()`）
