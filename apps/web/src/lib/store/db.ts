// 简化版内存数据存储（初期零依赖，验证流程后再换 SQLite/PostgreSQL）
// 使用 globalThis 单例，避免 Next.js 开发模式下模块多实例导致数据丢失

import type { UserProfile, Course, StudyPlan, Quiz, KnowledgeChunk, QuizResult, ConversationRecord, DashboardStats, RecentActivity } from "@/lib/types";

interface DB {
  profiles: Map<string, UserProfile>;
  courses: Map<string, Course[]>;
  plans: Map<string, StudyPlan>;
  quizzes: Map<string, Quiz>;
  knowledge: KnowledgeChunk[];
  quizResults: QuizResult[];
  conversations: ConversationRecord[];
  activityLog: RecentActivity[];
}

declare global {
  // eslint-disable-next-line no-var
  var __APP_DB__: DB | undefined;
}

const db: DB = globalThis.__APP_DB__ ?? {
  profiles: new Map(),
  courses: new Map(),
  plans: new Map(),
  quizzes: new Map(),
  knowledge: [],
  quizResults: [],
  conversations: [],
  activityLog: [],
};

if (!globalThis.__APP_DB__) {
  globalThis.__APP_DB__ = db;
}

// 初始化演示数据
function seedDemoData() {
  const demoUser: UserProfile = {
    userId: "demo",
    name: "演示同学",
    stage: "本科二年级",
    weakTopics: ["树与图", "动态规划", "操作系统调度"],
    strongTopics: ["数组", "链表", "基础语法"],
    learningStyle: "视觉型",
    stats: { totalQuestions: 128, accuracy: 0.76, studyDays: 23 },
  };
  db.profiles.set("demo", demoUser);

  const demoCourses: Course[] = [
    { id: "cs101", title: "数据结构", progress: 0.65, docCount: 12, topics: ["数组", "链表", "树", "图", "排序", "动态规划"] },
    { id: "cs102", title: "操作系统", progress: 0.42, docCount: 8, topics: ["进程", "调度", "内存管理", "文件系统"] },
    { id: "cs103", title: "计算机网络", progress: 0.30, docCount: 6, topics: ["TCP/IP", "HTTP", "路由"] },
  ];
  db.courses.set("demo", demoCourses);

  // 演示知识库切片
  const demoChunks: KnowledgeChunk[] = [
    { id: "k1", text: "二叉搜索树（BST）是一种节点值满足左子树均小于根、右子树均大于根的二叉树。中序遍历 BST 可得到升序序列。查找、插入、删除平均时间复杂度为 O(log n)，最坏退化为 O(n)。", source: "数据结构.pdf", courseId: "cs101" },
    { id: "k2", text: "动态规划通过将复杂问题分解为重叠子问题并存储子问题解来避免重复计算，适用于具有最优子结构和重叠子问题性质的问题。经典应用包括最长公共子序列、背包问题、编辑距离等。", source: "数据结构.pdf", courseId: "cs101" },
    { id: "k3", text: "进程调度算法包括先来先服务（FCFS）、短作业优先（SJF）、时间片轮转、多级反馈队列等。FCFS 公平但平均等待时间长；SJF 平均等待最短但可能饥饿；时间片轮转适合交互式系统。", source: "操作系统.pdf", courseId: "cs102" },
    { id: "k4", text: "TCP 三次握手：客户端发 SYN → 服务端回 SYN+ACK → 客户端发 ACK，连接建立。四次挥手用于安全关闭连接。三次握手确保双方都能收发数据，防止历史连接失效。", source: "计算机网络.pdf", courseId: "cs103" },
    { id: "k5", text: "图的遍历分为深度优先搜索（DFS）和广度优先搜索（BFS），DFS 使用栈/递归实现，BFS 使用队列实现。DFS 适合寻找所有路径，BFS 适合寻找最短路径（无权图）。", source: "数据结构.pdf", courseId: "cs101" },
    { id: "k6", text: "哈希表通过哈希函数将键映射到数组索引，实现 O(1) 平均时间的查找、插入和删除。冲突解决方法包括链地址法（拉链法）和开放地址法（线性探测、二次探测）。负载因子 = 元素数/表大小，通常保持在 0.7 以下。", source: "数据结构.pdf", courseId: "cs101" },
    { id: "k7", text: "堆是一种完全二叉树，分为大顶堆（父节点 >= 子节点）和小顶堆（父节点 <= 子节点）。堆的插入和删除时间复杂度为 O(log n)。优先队列通常用堆实现，堆排序时间复杂度为 O(n log n)。", source: "数据结构.pdf", courseId: "cs101" },
    { id: "k8", text: "快速排序采用分治策略，选取基准元素将数组分为两部分，平均时间复杂度 O(n log n)，最坏 O(n²)。归并排序也是分治策略，稳定排序，时间复杂度始终 O(n log n)，需要 O(n) 额外空间。", source: "数据结构.pdf", courseId: "cs101" },
    { id: "k9", text: "虚拟内存通过页表机制将逻辑地址映射到物理地址，使进程拥有独立的地址空间。缺页中断发生在访问的页不在物理内存时，操作系统从磁盘加载该页。TLB（翻译后备缓冲器）加速地址转换。", source: "操作系统.pdf", courseId: "cs102" },
    { id: "k10", text: "死锁产生的四个必要条件：互斥、占有并等待、不可抢占、循环等待。预防死锁的方法包括破坏其中一个条件，如银行家算法通过安全序列避免死锁。", source: "操作系统.pdf", courseId: "cs102" },
    { id: "k11", text: "HTTP 是无状态的 应用层协议，默认端口 80。HTTPS 在 HTTP 基础上加入 TLS/SSL 加密，默认端口 443。HTTP/2 支持多路复用、头部压缩，HTTP/3 基于 QUIC 协议。", source: "计算机网络.pdf", courseId: "cs103" },
    { id: "k12", text: "DNS 域名系统将域名解析为 IP 地址，采用分层分布式数据库结构。递归查询由本地 DNS 服务器完成，迭代查询由 DNS 服务器依次向根、顶级域、权威服务器查询。", source: "计算机网络.pdf", courseId: "cs103" },
    { id: "k13", text: "贪心算法在每一步选择当前最优解，不回溯。适用于具有贪心选择性质和最优子结构的问题，如最小生成树（Prim/Kruskal）、最短路径（Dijkstra）、哈夫曼编码。与动态规划的区别在于贪心不回溯。", source: "算法设计.pdf", courseId: "cs101" },
    { id: "k14", text: "分治算法将问题分解为子问题，递归求解后合并结果。典型应用包括归并排序、快速排序、最近点对问题。主定理分析分治算法的时间复杂度：T(n) = aT(n/b) + f(n)。", source: "算法设计.pdf", courseId: "cs101" },
    { id: "k15", text: "AVL 树是一种自平衡二叉搜索树，任意节点的左右子树高度差不超过 1。插入和删除时通过旋转操作（左旋、右旋、左右旋、右左旋）维持平衡。查找效率稳定为 O(log n)。", source: "数据结构.pdf", courseId: "cs101" },
  ];
  db.knowledge.push(...demoChunks);

  // 演示学习计划
  const demoPlan: StudyPlan = {
    planId: "plan_demo_001",
    userId: "demo",
    goal: "两周复习数据结构期末考试",
    tasks: [
      { id: "t1", title: "复习数组与链表基础", date: "2026-06-27", estimatedMin: 60, type: "review", done: true },
      { id: "t2", title: "练习栈与队列题目", date: "2026-06-28", estimatedMin: 90, type: "practice", done: true },
      { id: "t3", title: "学习二叉树遍历", date: "2026-06-29", estimatedMin: 75, type: "reading", done: false },
      { id: "t4", title: "完成 BST 与 AVL 练习题", date: "2026-06-30", estimatedMin: 90, type: "practice", done: false },
      { id: "t5", title: "复习图论算法（DFS/BFS）", date: "2026-07-01", estimatedMin: 90, type: "review", done: false },
      { id: "t6", title: "动态规划专项练习", date: "2026-07-02", estimatedMin: 120, type: "practice", done: false },
      { id: "t7", title: "模拟测验：数据结构综合", date: "2026-07-03", estimatedMin: 60, type: "quiz", done: false },
    ],
  };
  db.plans.set("demo", demoPlan);

  // 演示活动记录
  db.activityLog = [
    { type: "chat", description: "提问：什么是二叉搜索树", timestamp: new Date(Date.now() - 3600000).toISOString() },
    { type: "quiz", description: "完成测验：4/5 题正确", timestamp: new Date(Date.now() - 7200000).toISOString() },
    { type: "plan", description: "完成任务：练习栈与队列题目", timestamp: new Date(Date.now() - 10800000).toISOString() },
    { type: "study", description: "检索知识库：动态规划", timestamp: new Date(Date.now() - 86400000).toISOString() },
    { type: "chat", description: "提问：TCP 三次握手过程", timestamp: new Date(Date.now() - 172800000).toISOString() },
    { type: "quiz", description: "完成测验：3/5 题正确", timestamp: new Date(Date.now() - 259200000).toISOString() },
    { type: "plan", description: "保存学习计划：两周复习数据结构", timestamp: new Date(Date.now() - 345600000).toISOString() },
    { type: "study", description: "上传知识：操作系统.pdf", timestamp: new Date(Date.now() - 432000000).toISOString() },
  ];

  // 演示会话历史
  const demoConversations: ConversationRecord[] = [
    {
      sessionId: "session_demo_001",
      userId: "demo",
      message: "什么是二叉搜索树？",
      response: "二叉搜索树（BST）是一种节点值满足左子树均小于根、右子树均大于根的二叉树。中序遍历 BST 可得到升序序列。查找、插入、删除平均时间复杂度为 O(log n)，最坏退化为 O(n)。",
      intent: "tutor",
      citations: [{ doc: "数据结构.pdf", snippet: "二叉搜索树（BST）..." }],
      createdAt: new Date(Date.now() - 3600000).toISOString(),
    },
    {
      sessionId: "session_demo_002",
      userId: "demo",
      message: "TCP 三次握手为什么不是两次？",
      response: "三次握手确保双方都能收发数据。如果只有两次，服务端发送 SYN+ACK 后认为连接已建立，但客户端可能未收到，导致服务端浪费资源。第三次 ACK 确认客户端也收到了服务端的响应，防止历史连接失效。",
      intent: "tutor",
      citations: [{ doc: "计算机网络.pdf", snippet: "TCP 三次握手..." }],
      createdAt: new Date(Date.now() - 172800000).toISOString(),
    },
    {
      sessionId: "session_demo_003",
      userId: "demo",
      message: "动态规划和贪心算法有什么区别？",
      response: "动态规划通过存储子问题解来避免重复计算，会回溯所有可能；贪心算法每步选当前最优，不回溯。动态规划适用于最优子结构+重叠子问题，贪心适用于贪心选择性质+最优子结构。典型例子：DP-背包问题，贪心-最小生成树。",
      intent: "tutor",
      citations: [{ doc: "算法设计.pdf", snippet: "贪心算法在每一步..." }],
      createdAt: new Date(Date.now() - 259200000).toISOString(),
    },
  ];
  db.conversations.push(...demoConversations);

  // 演示测验结果
  const demoQuizResult: QuizResult = {
    quizId: "quiz_demo_001",
    userId: "demo",
    totalQuestions: 5,
    correctCount: 4,
    accuracy: 0.8,
    details: [
      { questionId: "q1", stem: "二叉搜索树的中序遍历得到什么序列？", userAnswer: "升序序列", correctAnswer: "升序序列", isCorrect: true, explanation: "BST 中序遍历得到升序序列" },
      { questionId: "q2", stem: "哈希表的平均查找时间复杂度？", userAnswer: "O(1)", correctAnswer: "O(1)", isCorrect: true, explanation: "哈希表平均 O(1)，最坏 O(n)" },
      { questionId: "q3", stem: "快速排序的最坏时间复杂度？", userAnswer: "O(n log n)", correctAnswer: "O(n²)", isCorrect: false, explanation: "最坏情况下退化为 O(n²)" },
      { questionId: "q4", stem: "死锁的四个必要条件之一是？", userAnswer: "互斥", correctAnswer: "互斥", isCorrect: true, explanation: "互斥、占有并等待、不可抢占、循环等待" },
      { questionId: "q5", stem: "HTTP 默认端口号？", userAnswer: "80", correctAnswer: "80", isCorrect: true, explanation: "HTTP 默认 80，HTTPS 默认 443" },
    ],
    evaluation: "正确率 80%（4/5）。总体表现良好。错题集中在快速排序最坏时间复杂度，建议复习排序算法的时间复杂度分析，特别是最坏情况和平均情况的区别。",
    weakTopics: ["快速排序", "排序算法"],
    submittedAt: new Date(Date.now() - 7200000).toISOString(),
  };
  db.quizResults.push(demoQuizResult);
}

// 仅在首次创建时初始化演示数据
if (db.profiles.size === 0) {
  seedDemoData();
}

export const store = {
  // ========== Profile ==========
  getProfile(userId: string): UserProfile | undefined {
    return db.profiles.get(userId);
  },
  updateProfile(userId: string, updates: Partial<UserProfile>): UserProfile | undefined {
    const existing = db.profiles.get(userId);
    if (!existing) return undefined;
    const updated = { ...existing, ...updates };
    db.profiles.set(userId, updated);
    return updated;
  },

  // ========== Courses ==========
  getCourses(userId: string): Course[] {
    return db.courses.get(userId) ?? [];
  },
  addCourse(userId: string, course: Course): void {
    const courses = db.courses.get(userId) ?? [];
    courses.push(course);
    db.courses.set(userId, courses);
  },

  // ========== Knowledge ==========
  getKnowledge(courseId?: string): KnowledgeChunk[] {
    return courseId ? db.knowledge.filter((c) => c.courseId === courseId) : db.knowledge;
  },
  addKnowledge(chunk: KnowledgeChunk) {
    db.knowledge.push(chunk);
    if (db.knowledge.length > 500) {
      db.knowledge = db.knowledge.slice(-500);
    }
  },
  addKnowledgeBatch(chunks: KnowledgeChunk[]) {
    db.knowledge.push(...chunks);
    if (db.knowledge.length > 500) {
      db.knowledge = db.knowledge.slice(-500);
    }
  },

  // ========== Plans ==========
  savePlan(plan: StudyPlan) {
    db.plans.set(plan.userId, plan);
  },
  getPlan(userId: string): StudyPlan | undefined {
    return db.plans.get(userId);
  },
  updatePlanTask(userId: string, taskId: string, done: boolean): StudyPlan | undefined {
    const plan = db.plans.get(userId);
    if (!plan) return undefined;
    const task = plan.tasks.find((t) => t.id === taskId);
    if (task) {
      task.done = done;
    }
    return plan;
  },

  // ========== Quiz ==========
  saveQuiz(quiz: Quiz) {
    db.quizzes.set(quiz.quizId, quiz);
  },
  getQuiz(quizId: string): Quiz | undefined {
    return db.quizzes.get(quizId);
  },

  // ========== Quiz Results ==========
  recordQuizResult(result: QuizResult) {
    db.quizResults.push(result);
    if (db.quizResults.length > 200) {
      db.quizResults = db.quizResults.slice(-200);
    }
    // 同步更新用户画像的答题统计
    const profile = db.profiles.get(result.userId);
    if (profile) {
      const newTotal = profile.stats.totalQuestions + result.totalQuestions;
      const oldCorrect = Math.round(profile.stats.totalQuestions * profile.stats.accuracy);
      const newCorrect = oldCorrect + result.correctCount;
      profile.stats.totalQuestions = newTotal;
      profile.stats.accuracy = newTotal > 0 ? newCorrect / newTotal : 0;
      // 更新薄弱知识点
      if (result.weakTopics.length > 0) {
        const weakSet = new Set([...profile.weakTopics, ...result.weakTopics]);
        profile.weakTopics = Array.from(weakSet).slice(0, 10);
      }
    }
    // 记录活动
    db.activityLog.unshift({
      type: "quiz",
      description: `完成测验：${result.correctCount}/${result.totalQuestions} 题正确`,
      timestamp: result.submittedAt,
    });
  },
  getQuizResults(userId: string): QuizResult[] {
    return db.quizResults.filter((r) => r.userId === userId);
  },

  // ========== Conversations ==========
  addConversation(record: ConversationRecord) {
    db.conversations.unshift(record);
    if (db.conversations.length > 100) {
      db.conversations = db.conversations.slice(0, 100);
    }
    db.activityLog.unshift({
      type: "chat",
      description: record.message.slice(0, 50),
      timestamp: record.createdAt,
    });
  },
  getConversations(userId: string, limit = 20): ConversationRecord[] {
    return db.conversations.filter((c) => c.userId === userId).slice(0, limit);
  },

  // ========== Stats ==========
  getStats(userId: string): DashboardStats {
    const profile = db.profiles.get(userId);
    const courses = db.courses.get(userId) ?? [];
    const plan = db.plans.get(userId);
    const quizResults = db.quizResults.filter((r) => r.userId === userId);
    const totalTasks = plan?.tasks.length ?? 0;
    const completedTasks = plan?.tasks.filter((t) => t.done).length ?? 0;

    return {
      userId,
      totalQuestions: profile?.stats.totalQuestions ?? 0,
      accuracy: profile?.stats.accuracy ?? 0,
      studyDays: profile?.stats.studyDays ?? 0,
      activeCourses: courses.length,
      totalTasks,
      completedTasks,
      totalQuizSubmissions: quizResults.length,
      recentActivity: db.activityLog.slice(0, 10),
    };
  },

  // ========== Activity ==========
  logActivity(activity: RecentActivity) {
    db.activityLog.unshift(activity);
    if (db.activityLog.length > 50) {
      db.activityLog = db.activityLog.slice(0, 50);
    }
  },
};
