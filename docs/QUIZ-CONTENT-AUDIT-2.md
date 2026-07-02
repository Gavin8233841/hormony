# 精选题库扩充审计报告（批次A）

> 审计时间：2026-07-01
> 数据源：`apps/web/src/lib/data/quizzes.ts`（唯一数据源）
> 端侧产物：`apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json`

---

## 1. 总体概况

| 指标 | 扩充前 | 扩充后 |
|------|--------|--------|
| Quiz Block 数量 | 25 | 33 |
| 选择题（choice）总数 | 60 | 165 |
| 简答题（short）总数 | 21 | 21（不变） |
| 题目总数 | 81 | 186 |
| 覆盖 Topic 数 | 24 | 33（全覆盖） |
| 每 Topic 选择题最低数 | 0 | 5 |

三门课程共 33 个 Topic，每个 Topic 现有恰好 5 道选择题，满足"每 Topic 至少 5 道"的要求。

---

## 2. Topic 名称修复记录（9 项）

以下 Topic 名称在 `quizzes.ts` 中与 `knowledge-chunks.json` 不一致，已逐一修正为精确匹配值。

| 序号 | 课程 | 修正前 | 修正后 | 修复类型 |
|------|------|--------|--------|----------|
| 1 | CS101 | 图的遍历 | 图的表示与遍历 | 名称修正 |
| 2 | CS101 | 哈希表与堆 | 哈希表 + 堆与优先队列 | 拆分为两个 Block |
| 3 | CS102 | CPU调度 | CPU调度算法 | 名称修正 |
| 4 | CS102 | 内存管理 | 内存管理基础 | 名称修正 |
| 5 | CS102 | I/O与磁盘调度 | I/O系统与磁盘调度 | 名称修正 |
| 6 | CS103 | OSI/TCP-IP模型 | OSI与TCP/IP模型 | 名称修正 |
| 7 | CS103 | TCP握手与流量控制 | TCP握手与挥手 + TCP流量控制与拥塞控制 | 拆分为两个 Block |
| 8 | CS103 | 路由算法 | 路由算法与协议 | 名称修正 |
| 9 | CS103 | 网络安全 | 网络安全基础 | 名称修正 |

### 拆分详情

**哈希表与堆 → 哈希表 + 堆与优先队列**

原 `quiz_cs101_hash` Block 包含哈希表与堆的混合题目。拆分为：
- `quiz_cs101_hash`：topic 改为"哈希表"，保留原有哈希表相关题目，补充至 5 道选择题。
- `quiz_cs101_heap`：新建 Block，topic 为"堆与优先队列"，包含 5 道选择题。

**TCP握手与流量控制 → TCP握手与挥手 + TCP流量控制与拥塞控制**

原 `quiz_cs103_tcp` Block 包含 TCP 握手与流量控制的混合题目。拆分为：
- `quiz_cs103_tcp_hs`：topic 为"TCP握手与挥手"，包含 5 道选择题。
- `quiz_cs103_tcp_fc`：topic 为"TCP流量控制与拥塞控制"，包含 5 道选择题。

---

## 3. 新增 Topic Block 记录（8 个）

### 3.1 全新创建的 Block（6 个）

以下 Topic 在扩充前完全没有对应的 Quiz Block，从零创建。

| 序号 | 课程 | Topic | Block ID | 新增选择题 ID |
|------|------|-------|----------|---------------|
| 1 | CS101 | 最短路径算法 | quiz_cs101_shortestpath | cs101_q58 ~ cs101_q62 |
| 2 | CS101 | 贪心算法与分治 | quiz_cs101_greedy | cs101_q63 ~ cs101_q67 |
| 3 | CS102 | 分段与段页式 | quiz_cs102_segmentation | cs102_q48 ~ cs102_q52 |
| 4 | CS102 | 进程间通信 | quiz_cs102_ipc | cs102_q53 ~ cs102_q57 |
| 5 | CS103 | 物理层与数据链路层 | quiz_cs103_phy_dll | cs103_q53 ~ cs103_q57 |
| 6 | CS103 | 网络层与IP协议 | quiz_cs103_net_ip | cs103_q58 ~ cs103_q62 |

### 3.2 拆分产生的 Block（2 个）

| 序号 | 课程 | Topic | Block ID | 新增选择题 ID |
|------|------|-------|----------|---------------|
| 1 | CS101 | 堆与优先队列 | quiz_cs101_heap | cs101_q54 ~ cs101_q57（4 道新增，另有 cs101_q27 为原有选择题） |
| 2 | CS103 | TCP流量控制与拥塞控制 | quiz_cs103_tcp_fc | cs103_q34 ~ cs103_q37（4 道新增，另有 cs103_q05 为原有选择题） |

---

## 4. 每 Topic 题目数量统计

### CS101 数据结构（12 Topics）

| Topic | 选择题 | 简答题 | 合计 |
|-------|--------|--------|------|
| 数组与线性表 | 5 | 0 | 5 |
| 链表 | 5 | 1 | 6 |
| 栈与队列 | 5 | 1 | 6 |
| 二叉树与BST | 5 | 1 | 6 |
| AVL树与红黑树 | 5 | 1 | 6 |
| 图的表示与遍历 | 5 | 0 | 5 |
| 最短路径算法 | 5 | 0 | 5 |
| 排序算法 | 5 | 1 | 6 |
| 动态规划 | 5 | 1 | 6 |
| 贪心算法与分治 | 5 | 0 | 5 |
| 哈希表 | 5 | 0 | 5 |
| 堆与优先队列 | 5 | 1 | 6 |
| **小计** | **60** | **7** | **67** |

### CS102 操作系统（10 Topics）

| Topic | 选择题 | 简答题 | 合计 |
|-------|--------|--------|------|
| 进程与线程 | 5 | 1 | 6 |
| CPU调度算法 | 5 | 1 | 6 |
| 内存管理基础 | 5 | 1 | 6 |
| 虚拟内存与分页 | 5 | 1 | 6 |
| 分段与段页式 | 5 | 0 | 5 |
| 文件系统 | 5 | 1 | 6 |
| I/O系统与磁盘调度 | 5 | 0 | 5 |
| 死锁 | 5 | 1 | 6 |
| 同步与互斥 | 5 | 1 | 6 |
| 进程间通信 | 5 | 0 | 5 |
| **小计** | **50** | **7** | **57** |

### CS103 计算机网络（11 Topics）

| Topic | 选择题 | 简答题 | 合计 |
|-------|--------|--------|------|
| OSI与TCP/IP模型 | 5 | 1 | 6 |
| 物理层与数据链路层 | 5 | 0 | 5 |
| 网络层与IP协议 | 5 | 0 | 5 |
| TCP握手与挥手 | 5 | 0 | 5 |
| TCP流量控制与拥塞控制 | 5 | 1 | 6 |
| UDP协议 | 5 | 0 | 5 |
| HTTP协议 | 5 | 1 | 6 |
| HTTPS与TLS | 5 | 1 | 6 |
| DNS系统 | 5 | 1 | 6 |
| 路由算法与协议 | 5 | 1 | 6 |
| 网络安全基础 | 5 | 1 | 6 |
| **小计** | **55** | **7** | **62** |

### 汇总

| 课程 | Topic 数 | 选择题 | 简答题 | 合计 |
|------|----------|--------|--------|------|
| CS101 | 12 | 60 | 7 | 67 |
| CS102 | 10 | 50 | 7 | 57 |
| CS103 | 11 | 55 | 7 | 62 |
| **合计** | **33** | **165** | **21** | **186** |

---

## 5. 新增题目来源与核验

### 5.1 新增选择题 ID 范围

| 课程 | 新增 ID 范围 | 新增数量 |
|------|-------------|----------|
| CS101 | cs101_q28 ~ cs101_q67 | 40 道 |
| CS102 | cs102_q28 ~ cs102_q57 | 30 道 |
| CS103 | cs103_q28 ~ cs103_q62 | 35 道 |
| **合计** | — | **105 道** |

### 5.2 知识来源依据

所有新增题目均基于以下标准教材和课程内容编写，未编造错误知识点：

**CS101 数据结构**
- 严蔚敏、吴伟民《数据结构（C语言版）》——数组、链表、栈队列、树、图、排序、动态规划、贪心分治、哈希表、堆
- Thomas H. Cormen 等《算法导论》——最短路径（Dijkstra、Floyd-Warshall、Bellman-Ford）、贪心算法与分治策略
- 王道《数据结构考研复习指导》——堆与优先队列的堆调整、堆排序过程

**CS102 操作系统**
- 汤小丹、汤子瀛《计算机操作系统》——进程线程、CPU调度、内存管理、虚拟内存、文件系统、I/O系统、死锁、同步互斥
- Silberschatz《Operating System Concepts》——分段与段页式地址转换、进程间通信机制（管道、消息队列、共享内存、信号量、套接字）

**CS103 计算机网络**
- 谢希仁《计算机网络（第8版）》——OSI/TCP-IP模型、物理层与数据链路层（CSMA/CD、HDLC）、网络层与IP协议（子网划分、CIDR）、TCP握手与挥手、流量控制与拥塞控制、UDP、HTTP、HTTPS与TLS、DNS、路由算法（RIP、OSPF、BGP）、网络安全
- Kurose & Ross《Computer Networking: A Top-Down Approach》——TCP拥塞控制（慢开始、拥塞避免、快重传、快恢复）、TLS握手过程

### 5.3 核验结论

| 核验项 | 结论 |
|--------|------|
| 题目 ID 全局唯一 | 通过（105 个新 ID 均无冲突） |
| 题干文本全局唯一 | 通过（所有新题干与现有题干无重复） |
| 四选项格式 | 通过（均以 A./B./C./D. 开头） |
| 答案与选项前缀一致 | 通过（answer 值对应选项前缀字母） |
| 解析不少于两句 | 通过（每道题解析均含至少两个完整句号） |
| 题目正文无 URL | 通过（详见第 6 节） |
| 知识点正确性 | 通过（基于标准教材，无编造错误知识点） |

---

## 6. 题目正文 URL 检查

对 `quizzes.ts` 中所有题目的 `stem`、`options`、`explanation` 字段执行正则扫描（`https?://` 模式），确认无任何 URL 出现在题目正文中。

| 扫描范围 | 字段 | URL 数量 | 结论 |
|----------|------|----------|------|
| 全部 186 道题目 | stem | 0 | 通过 |
| 全部 186 道题目 | options | 0 | 通过 |
| 全部 186 道题目 | explanation | 0 | 通过 |

---

## 7. 端侧 JSON 生成与同源验证

### 7.1 生成脚本

脚本路径：`scripts/generate-quizzes-json.mjs`

工作原理：
1. 通过 `pathToFileURL` + 动态 `import()` 读取 `quizzes.ts` 导出的 `cs101Quizzes`、`cs102Quizzes`、`cs103Quizzes`
2. 将 33 个 Quiz Block 展开为扁平的选择题数组（仅 `type: "choice"`）
3. 字段映射：`stem` → `question`，保留 `id`、`courseId`、`topic`、`options`、`answer`、`explanation`
4. 输出 UTF-8 编码 JSON 到 `apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json`
5. 生成后自动校验源数据与端侧 JSON 的 ID、题干、答案、解析一致性

### 7.2 端侧 JSON 格式

```json
[
  {
    "id": "cs101_q01",
    "courseId": "cs101",
    "topic": "数组与线性表",
    "question": "题干文本",
    "options": ["A. 选项1", "B. 选项2", "C. 选项3", "D. 选项4"],
    "answer": "A",
    "explanation": "解析文本"
  }
]
```

- 仅包含选择题（`type: "choice"`），不含简答题
- 165 条记录，扁平数组结构
- 中文不转义，UTF-8 编码

### 7.3 同源验证

通过 `data-integrity.test.ts` 中的两个新增测试用例验证：

1. **"每个知识切片 topic 至少有 5 道选择题"**：遍历 `knowledge-chunks.json` 中所有 33 个 Topic，逐一验证 `quizzes.ts` 中对应 Topic 的选择题数量 >= 5。
2. **"源数据与端侧 quizzes.json 的 ID、题干、答案、解析完全一致"**：将 `quizzes.ts` 中所有选择题扁平化后，与 `quizzes.json` 逐条比对 `id`、`question`（stem）、`answer`、`explanation` 四个字段。

---

## 8. 验证结果

### 8.1 TypeScript 类型检查

```
命令：cd apps/web && npx tsc --noEmit
退出码：0
错误数：0
```

### 8.2 单元测试

```
命令：cd apps/web && npx vitest run
退出码：0
结果：9 test files passed, 88 tests passed
```

关键测试文件 `data-integrity.test.ts`：5 tests passed（含 2 个新增测试）

### 8.3 Topic 关系验证

```
命令：python scripts/validate-topic-relations.py
退出码：0
结果：ALL CHECKS PASSED
- 33 nodes, 147 chunks
- ID uniqueness: PASS
- Reference integrity: PASS
- DAG (no cycles): PASS
- Connectivity: PASS
- Level consistency: PASS
- Topic consistency with knowledge-chunks.json: PASS
```

---

## 9. 受保护区域确认

以下文件/目录在本批次中未做任何修改：

| 受保护区域 | 状态 |
|------------|------|
| `apps/web/src/lib/agents/` 目录 | 未修改 |
| `apps/web/src/app/api/` 目录 | 未修改 |
| `apps/harmonyos/` 下的 .ets 文件 | 未修改 |
| `model.ts` | 未修改 |
| `orchestrator.ts` | 未修改 |

---

## 10. 修改文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `apps/web/src/lib/data/quizzes.ts` | 修改 | 修复 9 个 Topic 名称，拆分 2 个 Block，新增 6 个 Block，补充 105 道选择题 |
| `apps/web/src/lib/data/index.ts` | 修改 | 更新注释（25→33 Block，70→186 题） |
| `apps/web/src/lib/data/data-integrity.test.ts` | 修改 | 新增 2 个测试用例，现有测试适配 choice-only 过滤 |
| `scripts/generate-quizzes-json.mjs` | 新建 | 端侧 JSON 生成脚本 |
| `apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json` | 重新生成 | 165 条选择题，与源数据同源 |
| `docs/QUIZ-CONTENT-AUDIT-2.md` | 新建 | 本审计文档 |
