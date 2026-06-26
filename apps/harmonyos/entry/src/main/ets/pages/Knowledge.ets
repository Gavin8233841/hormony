/**
 * 知识库页
 */

import router from '@ohos.router';
import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { KnowledgeChunk, KnowledgeSearchRequest, KnowledgeSearchResponse } from '../model/DataModels';

@Entry
@Component
struct KnowledgePage {
  @State query: string = '';
  @State results: KnowledgeChunk[] = [];
  @State loading: boolean = false;
  @State message: string = '';

  private demoChunks: KnowledgeChunk[] = [
    { text: '二叉搜索树（BST）是一种节点值满足左子树均小于根、右子树均大于根的二叉树。中序遍历 BST 可得到升序序列。', source: '数据结构.pdf' },
    { text: '动态规划通过将复杂问题分解为重叠子问题并存储子问题解来避免重复计算。', source: '数据结构.pdf' },
    { text: '进程调度算法包括 FCFS、SJF、时间片轮转、多级反馈队列等。', source: '操作系统.pdf' },
    { text: 'TCP 三次握手：SYN → SYN+ACK → ACK，建立可靠连接。', source: '计算机网络.pdf' },
    { text: '图的遍历分为 DFS 和 BFS，DFS 使用栈/递归，BFS 使用队列。', source: '数据结构.pdf' },
  ];

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor('#e2e8f0')
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            router.back();
          })
        Column() {
          Text('知识库')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#e2e8f0')
          Text('RAG 检索演示 · Retrieval Agent 语义匹配')
            .fontSize(12)
            .fontColor('#94a3b8')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 4 })
      }
      .width('100%')
      .padding({ left: 8, right: 20, top: 16, bottom: 12 })

      // 搜索栏
      Row({ space: 12 }) {
        TextInput({ text: this.query, placeholder: '搜索知识库...' })
          .layoutWeight(1)
          .fontSize(14)
          .backgroundColor('#1e293b')
          .borderRadius(12)
          .onChange((v: string) => { this.query = v; })
          .onSubmit(() => { this.search(); })

        Button('检索')
          .fontSize(14)
          .backgroundColor('#2563eb')
          .fontColor('#ffffff')
          .borderRadius(12)
          .enabled(!this.loading)
          .onClick(() => { this.search(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(12)
          .fontColor('#94a3b8')
          .margin({ left: 16, bottom: 8 })
          .width('100%')
      }

      // 结果
      if (this.results.length > 0) {
        Text(`检索到 ${this.results.length} 条相关资料`)
          .fontSize(12)
          .fontColor('#94a3b8')
          .margin({ left: 16, bottom: 8 })

        List({ space: 12 }) {
          ForEach(this.results, (item: KnowledgeChunk) => {
            ListItem() {
              Column() {
                Text(item.source)
                  .fontSize(13)
                  .fontColor('#3b82f6')
                  .margin({ bottom: 6 })
                Text(item.courseId ? item.courseId : 'local')
                  .fontSize(11)
                  .fontColor('#64748b')
                  .margin({ bottom: 6 })
                if (item.score !== undefined) {
                  Text(`相关度: ${(item.score * 100).toFixed(0)}%`)
                    .fontSize(11)
                    .fontColor('#10b981')
                    .margin({ bottom: 6 })
                }
                Text(item.text)
                  .fontSize(13)
                  .fontColor('#cbd5e1')
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#1e293b')
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0f172a')
  }

  async search(): Promise<void> {
    const q = this.query.toLowerCase().trim();
    if (q.length === 0) {
      this.results = this.demoChunks;
      this.message = '显示本地演示资料';
      return;
    }

    this.loading = true;
    this.message = '检索中...';
    const request: KnowledgeSearchRequest = {
      query: q,
      topK: 5,
    };

    try {
      const response = await HttpClient.post<KnowledgeSearchResponse>(Constants.API_KNOWLEDGE_SEARCH, request);
      this.results = response.chunks;
      this.message = `后端检索到 ${this.results.length} 条资料`;
    } catch (e) {
      this.results = this.demoChunks.filter(
        (c: KnowledgeChunk): boolean => c.text.toLowerCase().includes(q) || c.source.toLowerCase().includes(q)
      );
      this.message = '后端暂不可用，已切换本地演示检索';
    } finally {
      this.loading = false;
    }
  }
}
