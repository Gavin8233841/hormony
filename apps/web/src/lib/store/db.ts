// 简化版内存数据存储（初期零依赖，验证流程后再换 SQLite/PostgreSQL）
// 使用 globalThis 单例，避免 Next.js 开发模式下模块多实例导致数据丢失

import type { UserProfile, Course, StudyPlan, Quiz, KnowledgeChunk } from "@/lib/types";

interface DB {
  profiles: Map<string, UserProfile>;
  courses: Map<string, Course[]>;
  plans: Map<string, StudyPlan>;
  quizzes: Map<string, Quiz>;
  knowledge: KnowledgeChunk[];
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
    { id: "k1", text: "二叉搜索树（BST）是一种节点值满足左子树均小于根、右子树均大于根的二叉树。中序遍历 BST 可得到升序序列。", source: "数据结构.pdf", courseId: "cs101" },
    { id: "k2", text: "动态规划通过将复杂问题分解为重叠子问题并存储子问题解来避免重复计算，适用于具有最优子结构和重叠子问题性质的问题。", source: "数据结构.pdf", courseId: "cs101" },
    { id: "k3", text: "进程调度算法包括先来先服务（FCFS）、短作业优先（SJF）、时间片轮转、多级反馈队列等。", source: "操作系统.pdf", courseId: "cs102" },
    { id: "k4", text: "TCP 三次握手：SYN → SYN+ACK → ACK，建立可靠连接；四次挥手用于安全关闭连接。", source: "计算机网络.pdf", courseId: "cs103" },
    { id: "k5", text: "图的遍历分为深度优先搜索（DFS）和广度优先搜索（BFS），DFS 使用栈/递归，BFS 使用队列。", source: "数据结构.pdf", courseId: "cs101" },
  ];
  db.knowledge.push(...demoChunks);
}

// 仅在首次创建时初始化演示数据
if (db.profiles.size === 0) {
  seedDemoData();
}

export const store = {
  getProfile(userId: string): UserProfile | undefined {
    return db.profiles.get(userId);
  },
  getCourses(userId: string): Course[] {
    return db.courses.get(userId) ?? [];
  },
  getKnowledge(courseId?: string): KnowledgeChunk[] {
    return courseId ? db.knowledge.filter((c) => c.courseId === courseId) : db.knowledge;
  },
  addKnowledge(chunk: KnowledgeChunk) {
    db.knowledge.push(chunk);
  },
  savePlan(plan: StudyPlan) {
    db.plans.set(plan.userId, plan);
  },
  getPlan(userId: string): StudyPlan | undefined {
    return db.plans.get(userId);
  },
  saveQuiz(quiz: Quiz) {
    db.quizzes.set(quiz.quizId, quiz);
  },
};
