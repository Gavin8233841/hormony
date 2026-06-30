import { describe, it, expect } from "vitest";
import { store } from "@/lib/store/db";

describe("Store 数据存储", () => {
  describe("Profile 操作", () => {
    it("getProfile 应返回演示用户", () => {
      const profile = store.getProfile("demo");
      expect(profile).toBeDefined();
      expect(profile!.userId).toBe("demo");
      expect(profile!.name).toBe("演示同学");
    });

    it("getProfile 不存在的用户应返回 undefined", () => {
      const profile = store.getProfile("nonexistent_user");
      expect(profile).toBeUndefined();
    });

    it("updateProfile 应更新用户画像字段", () => {
      const updated = store.updateProfile("demo", { name: "测试用户" });
      expect(updated).toBeDefined();
      expect(updated!.name).toBe("测试用户");
      // 恢复
      store.updateProfile("demo", { name: "演示同学" });
    });
  });

  describe("Courses 操作", () => {
    it("getCourses 应返回演示课程列表", () => {
      const courses = store.getCourses("demo");
      expect(courses.length).toBeGreaterThan(0);
      expect(courses.some((c) => c.id === "cs101")).toBe(true);
    });

    it("getCourses 不存在的用户应返回空数组", () => {
      const courses = store.getCourses("nonexistent_user");
      expect(courses).toEqual([]);
    });

    it("addCourse 应添加新课程", () => {
      const initialCount = store.getCourses("demo").length;
      store.addCourse("demo", {
        id: "test_course",
        title: "测试课程",
        progress: 0,
        docCount: 0,
        topics: [],
      });
      const courses = store.getCourses("demo");
      expect(courses.length).toBe(initialCount + 1);
      expect(courses.some((c) => c.id === "test_course")).toBe(true);
    });
  });

  describe("Knowledge 操作", () => {
    it("getKnowledge 应返回知识切片列表", () => {
      const chunks = store.getKnowledge();
      expect(chunks.length).toBeGreaterThanOrEqual(15);
    });

    it("getKnowledge 指定 courseId 应只返回该课程的切片", () => {
      const chunks = store.getKnowledge("cs101");
      expect(chunks.length).toBeGreaterThan(0);
      for (const c of chunks) {
        expect(c.courseId).toBe("cs101");
      }
    });

    it("addKnowledgeBatch 应批量添加切片", () => {
      const initialCount = store.getKnowledge().length;
      store.addKnowledgeBatch([
        { id: "test_k1", text: "测试知识1", source: "test.pdf", courseId: "test" },
        { id: "test_k2", text: "测试知识2", source: "test.pdf", courseId: "test" },
      ]);
      expect(store.getKnowledge().length).toBe(initialCount + 2);
    });
  });

  describe("Plan 操作", () => {
    it("getPlan 应返回演示学习计划", () => {
      const plan = store.getPlan("demo");
      expect(plan).toBeDefined();
      expect(plan!.tasks.length).toBeGreaterThan(0);
    });

    it("updatePlanTask 应更新任务完成状态", () => {
      const plan = store.getPlan("demo")!;
      const firstTask = plan.tasks[0];
      const originalDone = Boolean(firstTask.done);
      const updated = store.updatePlanTask("demo", firstTask.id, !originalDone);
      expect(updated).toBeDefined();
      expect(updated!.tasks[0].done).toBe(!originalDone);
      // 恢复
      store.updatePlanTask("demo", firstTask.id, originalDone);
    });
  });

  describe("Quiz 操作", () => {
    it("saveQuiz + getQuiz 应正确存储和读取", () => {
      const quiz = {
        quizId: "test_quiz_001",
        courseId: "cs101",
        topic: "测试",
        questions: [
          { id: "q1", type: "choice" as const, stem: "测试题", options: ["A", "B"], answer: "A", explanation: "测试" },
        ],
      };
      store.saveQuiz(quiz);
      const retrieved = store.getQuiz("test_quiz_001");
      expect(retrieved).toBeDefined();
      expect(retrieved!.quizId).toBe("test_quiz_001");
      expect(retrieved!.questions.length).toBe(1);
    });
  });

  describe("Quiz Results 操作", () => {
    it("recordQuizResult 应记录结果并更新画像统计", () => {
      const profileBefore = store.getProfile("demo")!;
      const totalBefore = profileBefore.stats.totalQuestions;

      store.recordQuizResult({
        quizId: "test_quiz_001",
        userId: "demo",
        totalQuestions: 5,
        correctCount: 3,
        accuracy: 0.6,
        details: [],
        evaluation: "测试评估",
        weakTopics: ["测试薄弱点"],
        submittedAt: new Date().toISOString(),
      });

      const profileAfter = store.getProfile("demo")!;
      expect(profileAfter.stats.totalQuestions).toBe(totalBefore + 5);
      expect(profileAfter.weakTopics).toContain("测试薄弱点");

      const results = store.getQuizResults("demo");
      expect(results.length).toBeGreaterThan(0);
      expect(results.some((r) => r.quizId === "test_quiz_001")).toBe(true);
    });
  });

  describe("Conversations 操作", () => {
    it("addConversation + getConversations 应正确存储和读取", () => {
      store.addConversation({
        sessionId: "test_session_001",
        userId: "demo",
        message: "测试消息",
        response: "测试回复",
        intent: "tutor",
        citations: [],
        createdAt: new Date().toISOString(),
      });

      const conversations = store.getConversations("demo", 10);
      expect(conversations.length).toBeGreaterThan(0);
      expect(conversations.some((c) => c.sessionId === "test_session_001")).toBe(true);
    });

    it("getConversations limit 参数应生效", () => {
      // 添加多条对话
      for (let i = 0; i < 5; i++) {
        store.addConversation({
          sessionId: `test_session_batch_${i}`,
          userId: "demo",
          message: `批量测试${i}`,
          response: `批量回复${i}`,
          intent: "general",
          citations: [],
          createdAt: new Date().toISOString(),
        });
      }
      const limited = store.getConversations("demo", 3);
      expect(limited.length).toBeLessThanOrEqual(3);
    });
  });

  describe("Stats 操作", () => {
    it("getStats 应返回聚合统计数据", () => {
      const stats = store.getStats("demo");
      expect(stats.userId).toBe("demo");
      expect(stats.totalQuestions).toBeGreaterThan(0);
      expect(stats.activeCourses).toBeGreaterThan(0);
      expect(stats.totalTasks).toBeGreaterThan(0);
      expect(stats.recentActivity).toBeDefined();
      expect(Array.isArray(stats.recentActivity)).toBe(true);
    });
  });

  describe("Activity 操作", () => {
    it("logActivity 应记录活动", () => {
      store.logActivity({
        userId: "demo",
        type: "study",
        description: "测试活动记录",
        timestamp: new Date().toISOString(),
      });
      const stats = store.getStats("demo");
      expect(stats.recentActivity.some((a) => a.description === "测试活动记录")).toBe(true);
    });

    it("getStats 不应返回其他用户的活动", () => {
      store.logActivity({
        userId: "other_user",
        type: "study",
        description: "其他用户活动",
        timestamp: new Date().toISOString(),
      });
      const stats = store.getStats("demo");
      expect(stats.recentActivity.some((a) => a.description === "其他用户活动")).toBe(false);
    });
  });
});
