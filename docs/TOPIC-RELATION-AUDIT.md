# 知识星图关系数据审计文档

> 生成时间：2026-07-01
> 数据源：`apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json`（147 条知识切片）
> 输出文件：`apps/harmonyos/entry/src/main/resources/rawfile/learning/topic-relations.json`（33 个节点）
> 校验脚本：`scripts/validate-topic-relations.py`

## 总览

| 课程 | courseId | topic 数量 | 节点数量 | 根节点 | 最大层级 |
|------|----------|-----------|---------|--------|---------|
| 数据结构与算法 | cs101 | 12 | 12 | 1 | 4 |
| 操作系统 | cs102 | 10 | 10 | 1 | 2 |
| 计算机网络 | cs103 | 11 | 11 | 1 | 6 |

## CS101 - 数据结构与算法

### 先修关系依据

| 节点 ID | Topic | Level | 先修节点 | 关系依据 |
|---------|-------|-------|---------|---------|
| cs101_array | 数组与线性表 | 0 | — | 最基础线性数据结构，所有后续结构的基础 |
| cs101_linked_list | 链表 | 1 | array | 链表是线性表的链式存储实现，需先理解顺序存储（数组）才能对比学习 |
| cs101_stack_queue | 栈与队列 | 2 | array, linked_list | 栈和队列既可用数组也可用链表实现，需掌握两种存储方式 |
| cs101_bst | 二叉树与BST | 1 | array | 二叉树的数组存储（堆数组）需先理解数组；树形结构是图的基础 |
| cs101_avl_rb | AVL树与红黑树 | 2 | bst | 自平衡树是 BST 的进阶，必须先掌握 BST 的性质和操作 |
| cs101_graph | 图的表示与遍历 | 3 | stack_queue, bst | 图的遍历（DFS/BFS）需要栈和队列；树的遍历是图遍历的特例 |
| cs101_shortest_path | 最短路径算法 | 4 | graph | 最短路径算法建立在图的基本概念和遍历之上 |
| cs101_sorting | 排序算法 | 1 | array | 排序操作的对象是数组/线性表，需先掌握数组 |
| cs101_dp | 动态规划 | 2 | sorting | 动态规划常以排序为预处理步骤；递归思维是 DP 的基础 |
| cs101_greedy_divide | 贪心算法与分治 | 2 | sorting | 分治法的经典应用包括归并排序和快速排序，需先学排序 |
| cs101_hash | 哈希表 | 1 | array | 哈希表基于数组的随机访问特性，需先理解数组 |
| cs101_heap | 堆与优先队列 | 2 | bst, sorting | 堆是完全二叉树的数组表示，需先掌握树和数组；堆排序也需要排序基础 |

### DAG 结构

```
数组与线性表(0) ─┬─→ 链表(1) ──→ 栈与队列(2) ──→ 图的表示与遍历(3) ──→ 最短路径算法(4)
                 ├─→ 二叉树与BST(1) ─┬─→ AVL树与红黑树(2)
                 │                    ├─→ 图的表示与遍历(3)
                 │                    └─→ 堆与优先队列(2)
                 ├─→ 排序算法(1) ─┬─→ 动态规划(2)
                 │                 ├─→ 贪心算法与分治(2)
                 │                 └─→ 堆与优先队列(2)
                 └─→ 哈希表(1)
```

## CS102 - 操作系统

### 先修关系依据

| 节点 ID | Topic | Level | 先修节点 | 关系依据 |
|---------|-------|-------|---------|---------|
| cs102_process | 进程与线程 | 0 | — | OS 最核心概念，所有后续主题的基础 |
| cs102_cpu_scheduling | CPU调度算法 | 1 | process | 调度的对象是进程/线程，需先理解进程概念 |
| cs102_memory_mgmt | 内存管理基础 | 1 | process | 内存分配给进程使用，需先理解进程地址空间 |
| cs102_virtual_memory | 虚拟内存与分页 | 2 | memory_mgmt | 虚拟内存是内存管理的扩展，需先掌握物理内存管理 |
| cs102_segmentation | 分段与段页式 | 3 | virtual_memory | 段页式是分页的进阶，需先掌握分页机制 |
| cs102_file_system | 文件系统 | 2 | memory_mgmt | 文件系统使用内存管理（缓冲区、页缓存），需先理解内存管理 |
| cs102_io_disk | I/O系统与磁盘调度 | 3 | file_system | 磁盘 I/O 与文件系统密切相关，需先理解文件存储 |
| cs102_deadlock | 死锁 | 1 | process | 死锁发生在进程间竞争资源，需先理解进程概念 |
| cs102_sync | 同步与互斥 | 1 | process | 同步互斥是进程间协作的基础，需先理解进程 |
| cs102_ipc | 进程间通信 | 2 | sync | IPC 需要同步机制保障正确性，需先掌握同步原语 |

### DAG 结构

```
进程与线程(0) ─┬─→ CPU调度算法(1)
               ├─→ 内存管理基础(1) ─┬─→ 虚拟内存与分页(2) ──→ 分段与段页式(3)
               │                     └─→ 文件系统(2) ──→ I/O系统与磁盘调度(3)
               ├─→ 死锁(1)
               └─→ 同步与互斥(1) ──→ 进程间通信(2)
```

## CS103 - 计算机网络

### 先修关系依据

| 节点 ID | Topic | Level | 先修节点 | 关系依据 |
|---------|-------|-------|---------|---------|
| cs103_osi_model | OSI与TCP/IP模型 | 0 | — | 网络体系结构总览，所有层的基础框架 |
| cs103_physical_link | 物理层与数据链路层 | 1 | osi_model | 位于 OSI 底层，需先理解分层模型 |
| cs103_network_ip | 网络层与IP协议 | 2 | physical_link | 网络层建立在数据链路层提供的点到点传输之上 |
| cs103_tcp_handshake | TCP握手与挥手 | 3 | network_ip | TCP 运行在网络层之上，需先理解 IP 协议 |
| cs103_tcp_flow | TCP流量控制与拥塞控制 | 4 | tcp_handshake | 流控和拥塞控制是 TCP 连接建立后的行为，需先理解 TCP 连接管理 |
| cs103_udp | UDP协议 | 3 | network_ip | UDP 与 TCP 同为传输层协议，需先理解网络层 |
| cs103_http | HTTP协议 | 4 | tcp_handshake | HTTP 基于 TCP 传输，需先理解 TCP 连接 |
| cs103_https_tls | HTTPS与TLS | 5 | http, tcp_flow | HTTPS = HTTP + TLS，需先掌握 HTTP 和 TCP 流控 |
| cs103_dns | DNS系统 | 5 | http, udp | DNS 使用 UDP/TCP 传输，与 HTTP 同属应用层协议 |
| cs103_routing | 路由算法与协议 | 3 | network_ip | 路由是网络层的核心功能，需先理解 IP 协议 |
| cs103_security | 网络安全基础 | 6 | https_tls, dns | 网络安全建立在加密通信（HTTPS/TLS）和域名系统之上 |

### DAG 结构

```
OSI与TCP/IP模型(0) ──→ 物理层与数据链路层(1) ──→ 网络层与IP协议(2) ─┬─→ TCP握手与挥手(3) ─┬─→ TCP流量控制与拥塞控制(4) ──┐
                                                                     ├─→ UDP协议(3)          ├─→ HTTP协议(4) ─┬─→ HTTPS与TLS(5) ──┐
                                                                     └─→ 路由算法与协议(3)    │                   └─→ DNS系统(5) ──┐ │
                                                                                             │                                    │ │
                                                                                             └────────────────────────────────────┴─→ 网络安全基础(6)
```

## 校验结果

运行 `python scripts/validate-topic-relations.py`，全部 6 项校验通过：

1. **ID 唯一性**: 33 个 ID 无重复
2. **引用完整性**: 所有 prerequisiteIds 引用均指向文件内真实存在的节点，无自引用
3. **DAG 无环性**: Kahn 拓扑排序通过，拓扑序长度 33，无环
4. **课程内连通性**: 三门课程各自从单一根节点可达全部节点，无跨课程先修
5. **Level 一致性**: 所有节点的 level = max(先修节点 level) + 1，根节点 level = 0
6. **Topic 一致性**: 33 个 topic 与 knowledge-chunks.json 完全一致

## 修正说明

原始规格中 `DNS系统` 标注为 level 4，但其先修节点 `HTTP协议` 为 level 4。按 level 定义（level = max(prereq levels) + 1），DNS 系统的 level 应为 5。已修正为 5，相应地 `网络安全基础`（先修 HTTPS与TLS(5) 和 DNS系统(5)）的 level 为 6，保持一致。
