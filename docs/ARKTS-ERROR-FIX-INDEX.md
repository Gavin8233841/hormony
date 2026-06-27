# ArkTS 编译错误修复指南索引

> **来源**: DevEco Code 内置 Skill `arkts-error-fixes`
> **路径**: `C:\Users\guo82\.local\share\deveco\skills\arkts-error-fixes\reference\`
> **用途**: 编译报错时，先匹配下方错误类型，再读取对应 .md 文件获取修复方案

---

## 错误类型索引（30 个）

### 类型系统错误

| 错误类型 | 文件 | 典型场景 |
|----------|------|----------|
| `any_type_errors` | any_type_errors.md | 使用了 `any` 类型（ArkTS 禁止） |
| `utility_type_errors` | utility_type_errors.md | 使用了 `Partial<T>`/`Readonly<T>` 等工具类型 |
| `esobject_type_errors` | esobject_type_errors.md | 使用了 `ESObject` 类型 |
| `object_literal_type_errors` | object_literal_type_errors.md | 对象字面量类型推断失败 |
| `object_literal_interface_errors` | object_literal_interface_errors.md | 对象字面量不匹配接口定义 |
| `object_spread_errors` | object_spread_errors.md | 使用了对象展开 `{...obj}` |
| `function_return_type_errors` | function_return_type_errors.md | 函数返回类型不匹配 |
| `standalone_function_errors` | standalone_function_errors.md | 独立函数声明问题 |
| `arrow_function_conversion_errors` | arrow_function_conversion_errors.md | 箭头函数转换错误 |
| `interface_method_signature_errors` | interface_method_signature_errors.md | 接口方法签名不匹配 |
| `implementation_not_allowed_errors` | implementation_not_allowed_errors.md | implements 不允许的场景 |

### 装饰器/状态管理错误

| 错误类型 | 文件 | 典型场景 |
|----------|------|----------|
| `decorator_state_errors` | decorator_state_errors.md | @State/@Prop/@Link 使用错误 |
| `appstorage_errors` | appstorage_errors.md | AppStorage 错误 |
| `storage_link_default_errors` | storage_link_default_errors.md | @StorageLink 默认值错误 |

### UI/组件错误

| 错误类型 | 文件 | 典型场景 |
|----------|------|----------|
| `color_consistency_errors` | color_consistency_errors.md | 颜色使用不一致（分层颜色） |
| `color_property_errors` | color_property_errors.md | 颜色属性值错误 |
| `fontcolor_property_errors` | fontcolor_property_errors.md | fontColor 属性错误 |
| `idata_source_errors` | idata_source_errors.md | IDataSource 接口实现错误 |
| `title_button_rect_type_errors` | title_button_rect_type_errors.md | TitleButtonRect 类型错误 |

### 系统/API 错误

| 错误类型 | 文件 | 典型场景 |
|----------|------|----------|
| `context_type_errors` | context_type_errors.md | Context 类型错误 |
| `window_type_errors` | window_type_errors.md | Window 类型错误 |
| `window_rect_size_errors` | window_rect_size_errors.md | WindowRectSize 类型错误 |
| `avoid_area_type_errors` | avoid_area_type_errors.md | AvoidArea 类型错误 |
| `breakpoint_type_errors` | breakpoint_type_errors.md | Breakpoint 类型错误 |
| `display_listener_type_errors` | display_listener_type_errors.md | DisplayListener 类型错误 |
| `resource_conversion_errors` | resource_conversion_errors.md | Resource 转换错误 |
| `notification_errors` | notification_errors.md | 通知 API 错误 |

### 通用错误

| 错误类型 | 文件 | 典型场景 |
|----------|------|----------|
| `catch_clause_type_errors` | catch_clause_type_errors.md | catch 子句类型错误（`catch(e: Error)` 不允许） |
| `possibly_null_errors` | possibly_null_errors.md | 可能为 null 的值未判空 |
| `duplicate_entry_errors` | duplicate_entry_errors.md | 重复的 @Entry 声明 |
| `unused_variable_warnings` | unused_variable_warnings.md | 未使用变量告警 |

---

## 使用方法

1. 编译报错时，先看错误消息中的关键词
2. 匹配上表中的错误类型
3. 读取对应文件：`Read C:\Users\guo82\.local\share\deveco\skills\arkts-error-fixes\reference\<错误类型>.md`
4. 按指南修复

## 示例

```
# 编译报错: ArkTS:ERROR File: xxx.ets:10:5
# 'as' type assertion is not allowed

# 匹配: any_type_errors.md 或 utility_type_errors.md
# 读取: Read .../any_type_errors.md
# 修复: 用类型守卫替代 as 断言
```
