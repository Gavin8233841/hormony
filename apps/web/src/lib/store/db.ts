// 简化版内存数据存储（初期零依赖，验证流程后再换 SQLite/PostgreSQL）
// 使用 globalThis 单例，避免 Next.js 开发模式下模块多实例导致数据丢失

import type { UserProfile, Course, StudyPlan, Quiz, KnowledgeChunk, QuizResult, ConversationRecord, DashboardStats, RecentActivity, ExternalResource } from "@/lib/types";
import { allKnowledgeChunks, allQuizzes, externalResources } from "@/lib/data";
import { loadPersistedState, savePersistedState } from "@/lib/store/persistence";

interface DB {
  curriculumDataVersion?: string;
  profiles: Map<string, UserProfile>;
  courses: Map<string, Course[]>;
  plans: Map<string, StudyPlan>;
  quizzes: Map<string, Quiz>;
  knowledge: KnowledgeChunk[];
  quizResults: QuizResult[];
  conversations: ConversationRecord[];
  activityLog: RecentActivity[];
  externalResources: ExternalResource[];
}

declare global {
  // eslint-disable-next-line no-var
  var __APP_DB__: DB | undefined;
}

const db: DB = globalThis.__APP_DB__ ?? {
  curriculumDataVersion: undefined,
  profiles: new Map(),
  courses: new Map(),
  plans: new Map(),
  quizzes: new Map(),
  knowledge: [],
  quizResults: [],
  conversations: [],
  activityLog: [],
  externalResources: [],
};

if (!Array.isArray(db.externalResources)) {
  db.externalResources = [];
}

if (!globalThis.__APP_DB__) {
  const persisted = loadPersistedState();
  if (persisted) {
    db.profiles = new Map(persisted.profiles.map((profile) => [profile.userId, profile]));
    db.courses = new Map(
      persisted.courseGroups.map((group) => [group.userId, group.courses])
    );
    db.plans = new Map(persisted.plans.map((plan) => [plan.userId, plan]));
    db.quizzes = new Map(
      persisted.generatedQuizzes.map((quiz) => [quiz.quizId, quiz])
    );
    db.knowledge = [...persisted.uploadedKnowledge];
    db.quizResults = [...persisted.quizResults];
    db.conversations = [...persisted.conversations];
    db.activityLog = [...persisted.activityLog];
  }
}

if (!globalThis.__APP_DB__) {
  globalThis.__APP_DB__ = db;
}

// 初始化演示数据
function seedDemoData() {
  const demoUser: UserProfile = {
    userId: "demo",
    name: "演示同学",
    stage: "本科二年级",
    weakTopics: ["AVL树与红黑树", "动态规划", "TCP拥塞控制", "虚拟内存页面置换", "死锁预防"],
    strongTopics: ["数组与线性表", "链表", "栈与队列", "OSI模型", "进程与线程"],
    learningStyle: "视觉型",
    stats: { totalQuestions: 128, accuracy: 0.76, studyDays: 23 },
  };
  db.profiles.set("demo", demoUser);

  const demoCourses: Course[] = [
    {
      id: "cs101",
      title: "数据结构",
      progress: 0.65,
      docCount: 52,
      topics: ["数组与线性表", "链表", "栈与队列", "二叉树与BST", "AVL树与红黑树", "图的遍历", "最短路径算法", "排序算法", "动态规划", "贪心算法与分治", "哈希表", "堆与优先队列"],
    },
    {
      id: "cs102",
      title: "操作系统",
      progress: 0.42,
      docCount: 48,
      topics: ["进程与线程", "CPU调度算法", "内存管理基础", "虚拟内存与分页", "分段与段页式", "文件系统", "I/O系统与磁盘调度", "死锁", "同步与互斥", "进程间通信"],
    },
    {
      id: "cs103",
      title: "计算机网络",
      progress: 0.30,
      docCount: 47,
      topics: ["OSI与TCP/IP模型", "物理层与数据链路层", "网络层与IP协议", "TCP握手与挥手", "流量控制与拥塞控制", "UDP协议", "HTTP协议", "HTTPS与TLS", "DNS系统", "路由算法与协议", "网络安全基础"],
    },
  ];
  db.courses.set("demo", demoCourses);

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
    { userId: "demo", type: "chat", description: "提问：什么是二叉搜索树", timestamp: new Date(Date.now() - 3600000).toISOString() },
    { userId: "demo", type: "quiz", description: "完成测验：4/5 题正确", timestamp: new Date(Date.now() - 7200000).toISOString() },
    { userId: "demo", type: "plan", description: "完成任务：练习栈与队列题目", timestamp: new Date(Date.now() - 10800000).toISOString() },
    { userId: "demo", type: "study", description: "检索知识库：动态规划", timestamp: new Date(Date.now() - 86400000).toISOString() },
    { userId: "demo", type: "chat", description: "提问：TCP 三次握手过程", timestamp: new Date(Date.now() - 172800000).toISOString() },
    { userId: "demo", type: "quiz", description: "完成测验：3/5 题正确", timestamp: new Date(Date.now() - 259200000).toISOString() },
    { userId: "demo", type: "plan", description: "保存学习计划：两周复习数据结构", timestamp: new Date(Date.now() - 345600000).toISOString() },
    { userId: "demo", type: "study", description: "上传知识：操作系统.pdf", timestamp: new Date(Date.now() - 432000000).toISOString() },
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

const CURRICULUM_DATA_VERSION = "2026-06-30-1";
const seedChunkIds = new Set(allKnowledgeChunks.map((chunk) => chunk.id));
const seedQuizIds = new Set(allQuizzes.map((quiz) => quiz.quizId));

function syncCurriculumData(): void {
  if (db.curriculumDataVersion === CURRICULUM_DATA_VERSION) return;

  const uploadedChunks = db.knowledge.filter((chunk) => !seedChunkIds.has(chunk.id));
  db.knowledge = [...allKnowledgeChunks, ...uploadedChunks];

  for (const quiz of allQuizzes) {
    db.quizzes.set(quiz.quizId, quiz);
  }

  db.externalResources = [...externalResources];
  db.curriculumDataVersion = CURRICULUM_DATA_VERSION;
}

function persistState(): void {
  savePersistedState({
    profiles: Array.from(db.profiles.values()),
    courseGroups: Array.from(db.courses.entries()).map(([userId, courses]) => ({
      userId,
      courses,
    })),
    plans: Array.from(db.plans.values()),
    generatedQuizzes: Array.from(db.quizzes.values()).filter(
      (quiz) => !seedQuizIds.has(quiz.quizId)
    ),
    uploadedKnowledge: db.knowledge.filter((chunk) => !seedChunkIds.has(chunk.id)),
    quizResults: db.quizResults,
    conversations: db.conversations,
    activityLog: db.activityLog,
  });
}

// 仅在首次创建时初始化演示数据
if (db.profiles.size === 0) {
  seedDemoData();
}
syncCurriculumData();

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
    persistState();
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
    persistState();
  },

  // ========== Knowledge ==========
  getKnowledge(courseId?: string): KnowledgeChunk[] {
    return courseId ? db.knowledge.filter((c) => c.courseId === courseId) : db.knowledge;
  },
  addKnowledgeBatch(chunks: KnowledgeChunk[]) {
    db.knowledge.push(...chunks);
    if (db.knowledge.length > 500) {
      db.knowledge = db.knowledge.slice(-500);
    }
    persistState();
  },

  // ========== Plans ==========
  savePlan(plan: StudyPlan) {
    db.plans.set(plan.userId, plan);
    persistState();
  },
  getPlan(userId: string): StudyPlan | undefined {
    return db.plans.get(userId);
  },
  updatePlanTask(userId: string, taskId: string, done: boolean): StudyPlan | undefined {
    const plan = db.plans.get(userId);
    if (!plan) return undefined;
    const task = plan.tasks.find((t) => t.id === taskId);
    if (!task) return undefined;
    task.done = done;
    persistState();
    return plan;
  },

  // ========== Quiz ==========
  saveQuiz(quiz: Quiz) {
    db.quizzes.set(quiz.quizId, quiz);
    persistState();
  },
  getQuiz(quizId: string): Quiz | undefined {
    return db.quizzes.get(quizId);
  },
  getQuizzesByCourse(courseId: string): Quiz[] {
    return Array.from(db.quizzes.values()).filter((q) => q.courseId === courseId);
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
      userId: result.userId,
      type: "quiz",
      description: `完成测验：${result.correctCount}/${result.totalQuestions} 题正确`,
      timestamp: result.submittedAt,
    });
    persistState();
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
      userId: record.userId,
      type: "chat",
      description: record.message.slice(0, 50),
      timestamp: record.createdAt,
    });
    persistState();
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
      recentActivity: db.activityLog
        .filter((activity) => activity.userId === userId)
        .slice(0, 10),
    };
  },

  // ========== Activity ==========
  logActivity(activity: RecentActivity) {
    db.activityLog.unshift(activity);
    if (db.activityLog.length > 50) {
      db.activityLog = db.activityLog.slice(0, 50);
    }
    persistState();
  },

  // ========== External Resources ==========
  getExternalResources(courseId?: string): ExternalResource[] {
    return courseId
      ? db.externalResources.filter((r) => r.courseId === courseId)
      : db.externalResources;
  },
  getExternalResourcesByType(type: ExternalResource["type"]): ExternalResource[] {
    return db.externalResources.filter((r) => r.type === type);
  },
};
