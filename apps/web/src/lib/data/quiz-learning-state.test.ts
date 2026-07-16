import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import { fileURLToPath } from "node:url";
import ts from "typescript";
import { describe, expect, it } from "vitest";

interface RuntimeDetail {
  questionId: string;
  stem: string;
  options: string[];
  userAnswer: string;
  correctAnswer: string;
  isCorrect: boolean;
  explanation: string;
  difficulty: string;
  tags: string[];
  reviewItemId?: string;
}

interface RuntimeResult {
  quizId: string;
  sourceQuizId?: string;
  userId: string;
  courseId: string;
  topic: string;
  source: string;
  difficulty: string;
  totalQuestions: number;
  correctCount: number;
  accuracy: number;
  details: RuntimeDetail[];
  evaluation: string;
  weakTopics: string[];
  submittedAt: string;
}

interface RuntimeMastery {
  attempts: number;
  totalQuestions: number;
  correctQuestions: number;
  accuracy: number;
  mastered: boolean;
}

interface RuntimeReviewItem {
  id: string;
  attempts: number;
  resolved: boolean;
  intervalDays: number;
  nextReviewAt: string;
  options?: string[];
}

interface RuntimeTagInsight {
  tag: string;
  courseId: string;
  topic: string;
  totalQuestions: number;
  correctQuestions: number;
}

interface RuntimeState {
  pendingResults: RuntimeResult[];
  appliedQuizIds: string[];
  appliedInsightEventIds: string[];
  recentResults: RuntimeResult[];
  stats: {
    totalAttempts: number;
    totalQuestions: number;
    correctQuestions: number;
    quizDates: string[];
  };
  reviewItems: RuntimeReviewItem[];
  topicMastery: RuntimeMastery[];
  tagInsights: RuntimeTagInsight[];
  quizEvents: Array<{ id: string }>;
  masteryMilestones: Array<{ courseId: string; topic: string; masteredAt: string }>;
  weakTopics: string[];
  strongTopics: string[];
}

interface RuntimeStudyEvent {
  id: string;
  type: string;
  timestamp: string;
  courseId?: string;
  topic?: string;
  difficulty?: string;
  tags?: string[];
  totalQuestions?: number;
  correctCount?: number;
}

interface RuntimeReceipt {
  applied: boolean;
  totalAttempts: number;
  totalQuestions: number;
  activeReviewCount: number;
  dueReviewCount: number;
  activityCount: number;
}

interface ReducerRuntime {
  createEmptyState(): RuntimeState;
  enqueueResult(state: RuntimeState, result: RuntimeResult): boolean;
  applyPendingResults(state: RuntimeState): number;
  applyResult(state: RuntimeState, result: RuntimeResult): boolean;
  applyLearningInsightEvent(state: RuntimeState, event: RuntimeStudyEvent): boolean;
  createReceipt(state: RuntimeState, result: RuntimeResult, applied: boolean, now?: string): RuntimeReceipt;
  localDateKey(timestamp: string): string;
  tagInsightKey(courseId: string, topic: string, tag: string): string;
}

const reducerSource = readFileSync(
  fileURLToPath(
    new URL(
      "../../../../harmonyos/entry/src/main/ets/common/QuizLearningStateReducer.ets",
      import.meta.url
    )
  ),
  "utf8"
);

function loadReducer(): ReducerRuntime {
  const sourceFile = ts.createSourceFile(
    "QuizLearningStateReducer.ets",
    reducerSource,
    ts.ScriptTarget.ES2022,
    true,
    ts.ScriptKind.TS
  );
  const withoutImports = ts.factory.updateSourceFile(
    sourceFile,
    sourceFile.statements.filter((statement) => !ts.isImportDeclaration(statement))
  );
  const printableSource = ts.createPrinter().printFile(withoutImports);
  const transpiled = ts.transpileModule(printableSource, {
    compilerOptions: {
      target: ts.ScriptTarget.ES2022,
      module: ts.ModuleKind.CommonJS,
      strict: true,
    },
    reportDiagnostics: true,
  });
  const errors = (transpiled.diagnostics ?? []).filter(
    (diagnostic) => diagnostic.category === ts.DiagnosticCategory.Error
  );
  expect(errors).toEqual([]);

  const runtimeExports: Record<string, unknown> = {};
  runInNewContext(transpiled.outputText, {
    exports: runtimeExports,
    module: { exports: runtimeExports },
  });
  const reducer = runtimeExports.QuizLearningStateReducer;
  if (typeof reducer !== "function") {
    throw new Error("QuizLearningStateReducer 未导出可执行类");
  }
  return reducer as unknown as ReducerRuntime;
}

const reducer = loadReducer();
const repositorySource = readFileSync(
  fileURLToPath(
    new URL(
      "../../../../harmonyos/entry/src/main/ets/common/LocalLearningRepository.ets",
      import.meta.url
    )
  ),
  "utf8"
);
const quizPageSource = readFileSync(
  fileURLToPath(
    new URL(
      "../../../../harmonyos/entry/src/main/ets/pages/Quiz.ets",
      import.meta.url
    )
  ),
  "utf8"
);
const repositorySourceFile = ts.createSourceFile(
  "LocalLearningRepository.ets",
  repositorySource,
  ts.ScriptTarget.ES2022,
  true,
  ts.ScriptKind.TS
);
const repositoryClass = repositorySourceFile.statements.find(
  (statement): statement is ts.ClassDeclaration =>
    ts.isClassDeclaration(statement) && statement.name?.text === "LocalLearningRepository"
);

function repositoryMemberName(member: ts.ClassElement): string {
  if (!("name" in member) || member.name === undefined) return "";
  return member.name.getText(repositorySourceFile);
}

function repositoryMethodSource(methodName: string): string {
  if (repositoryClass === undefined) throw new Error("LocalLearningRepository 未导出可检查类");
  const method = repositoryClass.members.find(
    (member): member is ts.MethodDeclaration =>
      ts.isMethodDeclaration(member) && repositoryMemberName(member) === methodName
  );
  if (method === undefined) throw new Error(`LocalLearningRepository 缺少 ${methodName}`);
  return method.getText(repositorySourceFile);
}

function staticPromiseQueue(): { name: string; source: string } {
  if (repositoryClass === undefined) throw new Error("LocalLearningRepository 未导出可检查类");
  const properties = repositoryClass.members.filter(
    (member): member is ts.PropertyDeclaration => ts.isPropertyDeclaration(member)
  );
  const queues = properties.filter((property) => {
    const isStatic = property.modifiers?.some(
      (modifier) => modifier.kind === ts.SyntaxKind.StaticKeyword
    ) ?? false;
    const typeSource = property.type?.getText(repositorySourceFile) ?? "";
    const initializerSource = property.initializer?.getText(repositorySourceFile) ?? "";
    return isStatic && typeSource === "Promise<void>" && initializerSource.includes("Promise.resolve()");
  });
  expect(queues).toHaveLength(1);
  return {
    name: repositoryMemberName(queues[0]),
    source: queues[0].getText(repositorySourceFile),
  };
}

function queueGuardMethod(queueName: string): { name: string; source: string } {
  if (repositoryClass === undefined) throw new Error("LocalLearningRepository 未导出可检查类");
  const methods = repositoryClass.members.filter(
    (member): member is ts.MethodDeclaration => ts.isMethodDeclaration(member)
  );
  const guardMethods = methods.filter((method) =>
    method.getText(repositorySourceFile).includes(`LocalLearningRepository.${queueName}`)
  );
  expect(guardMethods).toHaveLength(1);
  return {
    name: repositoryMemberName(guardMethods[0]),
    source: guardMethods[0].getText(repositorySourceFile),
  };
}
const OPTIONS = ["A. 正确项", "B. 干扰项", "C. 其他项", "D. 边界项"];

function result(
  quizId: string,
  submittedAt: string,
  correct: boolean,
  topic = "二叉树与BST",
  reviewItemId?: string,
  sourceQuizId?: string
): RuntimeResult {
  const detail: RuntimeDetail = {
    questionId: `question-${quizId}`,
    stem: `题目 ${quizId}`,
    options: OPTIONS.slice(),
    userAnswer: correct ? OPTIONS[0] : OPTIONS[1],
    correctAnswer: OPTIONS[0],
    isCorrect: correct,
    explanation: "基于真实选项核对答案。",
    difficulty: "medium",
    tags: ["树结构"],
    reviewItemId,
  };
  return {
    quizId,
    sourceQuizId,
    userId: "demo",
    courseId: "cs101",
    topic,
    source: "curated",
    difficulty: "medium",
    totalQuestions: 1,
    correctCount: correct ? 1 : 0,
    accuracy: correct ? 1 : 0,
    details: [detail],
    evaluation: correct ? "答对" : "待复习",
    weakTopics: correct ? [] : [topic],
    submittedAt,
  };
}

describe("QuizLearningStateReducer 持久学习闭环", () => {
  it("Repository 先持久化 pending，再归并并以同一 ArkData 键完成写回", () => {
    expect(repositorySource).toContain("const KEY_QUIZ_LEARNING_STATE: string = 'quiz_learning_state'");
    const appendStart = repositorySource.indexOf("static async appendQuizResult");
    const appendEnd = repositorySource.indexOf("private static async withCourseProgress", appendStart);
    const appendSource = repositorySource.slice(appendStart, appendEnd);
    const enqueue = appendSource.indexOf("QuizLearningStateReducer.enqueueResult(state, result)");
    const pendingWrite = appendSource.indexOf(
      "putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state)",
      enqueue
    );
    const applyPending = appendSource.indexOf(
      "QuizLearningStateReducer.applyPendingResults(state)",
      pendingWrite
    );
    const completedWrite = appendSource.indexOf(
      "putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state)",
      applyPending
    );

    expect(enqueue).toBeGreaterThan(-1);
    expect(pendingWrite).toBeGreaterThan(enqueue);
    expect(applyPending).toBeGreaterThan(pendingWrite);
    expect(completedWrite).toBeGreaterThan(applyPending);
    expect(appendSource).not.toContain("KEY_QUIZ_RESULTS");
    expect(appendSource).not.toContain("KEY_REVIEW_ITEMS");
    expect(appendSource).not.toContain("KEY_TOPIC_MASTERY");

    const recoveryStart = repositorySource.indexOf("private static async getQuizLearningState");
    const recoveryEnd = repositorySource.indexOf("static async getProfile", recoveryStart);
    const recoverySource = repositorySource.slice(recoveryStart, recoveryEnd);
    expect(recoverySource).toContain("if (state.pendingResults.length > 0)");
    expect(recoverySource).toContain("QuizLearningStateReducer.applyPendingResults(state)");
    expect(recoverySource).toContain(
      "putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state)"
    );
  });

  it("quiz_learning_state 的公开读写共用一个静态 Promise 队列，锁内不回调加锁读取", () => {
    const queue = staticPromiseQueue();
    const guard = queueGuardMethod(queue.name);
    expect(queue.source).toContain("Promise<void>");
    expect(guard.source).toContain(`LocalLearningRepository.${queue.name}`);

    for (const methodName of [
      "getQuizLearningState",
      "appendQuizResult",
      "getStudyEvents",
      "appendStudyEvent",
    ]) {
      const source = repositoryMethodSource(methodName);
      expect(source).toContain(`LocalLearningRepository.${guard.name}(`);
    }

    const appendQuizSource = repositoryMethodSource("appendQuizResult");
    const appendEventSource = repositoryMethodSource("appendStudyEvent");
    const progressSource = repositoryMethodSource("withCourseProgress");
    const lockingGetters = [
      "getQuizLearningState",
      "getStudyEvents",
      "getCourses",
      "getTopicMastery",
      "getAllTagInsights",
    ];
    for (const methodName of lockingGetters) {
      expect(appendQuizSource).not.toContain(`LocalLearningRepository.${methodName}(`);
      expect(appendEventSource).not.toContain(`LocalLearningRepository.${methodName}(`);
      expect(progressSource).not.toContain(`LocalLearningRepository.${methodName}(`);
    }
    expect(progressSource).not.toContain(`LocalLearningRepository.${guard.name}(`);
    expect(progressSource).toContain("getValue<Course[]>(KEY_COURSES)");
  });

  it("schema 迁移按课程的 33 Topic 精确集合清洗全部历史派生状态", () => {
    const exactTopicSource = repositoryMethodSource("isExactCourseTopic");
    const migrationSource = repositoryMethodSource("migrateQuizLearningState");
    const sanitizeSource = repositoryMethodSource("sanitizeQuizLearningState");
    expect(exactTopicSource).toContain("LearningContentRepository.getTopics(courseId).includes(topic)");
    expect(exactTopicSource).not.toContain("'综合'");
    expect(migrationSource).toContain("isExactCourseTopic(result.courseId, result.topic)");
    for (const field of [
      "pendingResults",
      "recentResults",
      "reviewItems",
      "topicMastery",
      "tagInsights",
      "quizEvents",
      "masteryMilestones",
    ]) {
      expect(sanitizeSource).toContain(`state.${field} = state.${field}.filter`);
    }
    expect(sanitizeSource).toContain("if (retainedStatsSourceCount !== originalStatsSourceCount)");
    expect(sanitizeSource).toContain("QuizLearningStateReducer.masteryTotals(state.topicMastery)");
  });

  it("同一 quizId 重试只累计一次，并同步五类派生状态", () => {
    const state = reducer.createEmptyState();
    const attempt = result("quiz-idempotent", "2026-07-17T04:00:00.000Z", false);

    expect(reducer.enqueueResult(state, attempt)).toBe(true);
    expect(state.pendingResults).toHaveLength(1);
    expect(reducer.applyPendingResults(state)).toBe(1);
    expect(reducer.applyResult(state, attempt)).toBe(false);

    expect(state.stats).toMatchObject({ totalAttempts: 1, totalQuestions: 1, correctQuestions: 0 });
    expect(state.topicMastery[0]).toMatchObject({ attempts: 1, totalQuestions: 1, correctQuestions: 0 });
    expect(state.reviewItems).toHaveLength(1);
    expect(state.reviewItems[0].options).toEqual(OPTIONS);
    expect(state.tagInsights[0]).toMatchObject({ tag: "树结构", totalQuestions: 1, correctQuestions: 0 });
    expect(state.quizEvents).toHaveLength(1);
    expect(state.weakTopics).toEqual(["二叉树与BST"]);
    const submittedAt = new Date(attempt.submittedAt);
    const localDate = `${submittedAt.getFullYear()}-${(submittedAt.getMonth() + 1).toString().padStart(2, "0")}-${submittedAt.getDate().toString().padStart(2, "0")}`;
    expect(state.stats.quizDates).toEqual([localDate]);
    expect(reducer.localDateKey(attempt.submittedAt)).toBe(localDate);
  });

  it("pending 状态经持久化重建后可恢复，重复恢复不再累加", () => {
    const beforeRestart = reducer.createEmptyState();
    const attempt = result("quiz-restart", "2026-07-17T05:00:00.000Z", false);
    reducer.enqueueResult(beforeRestart, attempt);
    const afterRestart = JSON.parse(JSON.stringify(beforeRestart)) as RuntimeState;

    expect(reducer.applyPendingResults(afterRestart)).toBe(1);
    expect(reducer.applyPendingResults(afterRestart)).toBe(0);
    expect(afterRestart.pendingResults).toEqual([]);
    expect(afterRestart.appliedQuizIds).toEqual(["quiz-restart"]);

    const receipt = reducer.createReceipt(
      afterRestart,
      attempt,
      true,
      "2026-07-18T05:00:00.000Z"
    );
    expect(receipt).toMatchObject({
      applied: true,
      totalAttempts: 1,
      totalQuestions: 1,
      activeReviewCount: 1,
      dueReviewCount: 1,
      activityCount: 1,
    });
  });

  it("同一 sourceQuizId 的不同答题尝试分别累计，单次重试仍按 quizId 幂等", () => {
    const state = reducer.createEmptyState();
    const first = result(
      "attempt-source-1",
      "2026-07-17T06:00:00.000Z",
      true,
      "二叉树与BST",
      undefined,
      "quiz_cs101_tree"
    );
    const second = result(
      "attempt-source-2",
      "2026-07-18T06:00:00.000Z",
      false,
      "二叉树与BST",
      undefined,
      "quiz_cs101_tree"
    );

    expect(reducer.applyResult(state, first)).toBe(true);
    expect(reducer.applyResult(state, second)).toBe(true);
    expect(reducer.applyResult(state, second)).toBe(false);
    expect(state.stats).toMatchObject({ totalAttempts: 2, totalQuestions: 2, correctQuestions: 1 });
    expect(state.appliedQuizIds).toEqual(["attempt-source-1", "attempt-source-2"]);
    expect(state.recentResults.map((item) => item.sourceQuizId)).toEqual([
      "quiz_cs101_tree",
      "quiz_cs101_tree",
    ]);
    expect(quizPageSource).toContain("this.attemptId = 'quiz_attempt_' + validation.quizId");
    expect(quizPageSource).toContain("quizId: this.attemptId");
    expect(quizPageSource).toContain("sourceQuizId: this.quizId");
    expect(quizPageSource).toContain("submittedAt: this.attemptSubmittedAt");
  });

  it("结果与活动明细截断时，605 次终身统计、掌握度与活动总数仍完整", () => {
    const state = reducer.createEmptyState();
    for (let index = 0; index < 605; index += 1) {
      const day = (index % 28 + 1).toString().padStart(2, "0");
      reducer.applyResult(
        state,
        result(`quiz-long-${index}`, `2026-06-${day}T06:00:00.000Z`, index % 2 === 0)
      );
    }

    expect(state.recentResults).toHaveLength(20);
    expect(state.appliedQuizIds).toHaveLength(605);
    expect(state.stats.totalAttempts).toBe(605);
    expect(state.stats.totalQuestions).toBe(605);
    expect(state.stats.correctQuestions).toBe(303);
    expect(state.topicMastery[0]).toMatchObject({
      attempts: 605,
      totalQuestions: 605,
      correctQuestions: 303,
    });
    expect(state.tagInsights[0].totalQuestions).toBe(605);
    expect(state.quizEvents).toHaveLength(500);
    const receipt = reducer.createReceipt(
      state,
      result("quiz-long-604", "2026-06-17T06:00:00.000Z", true),
      false
    );
    expect(receipt.activityCount).toBe(605);
  });

  it("精确 reviewItemId 的连续正确复习按 1-3-7-14 天推进并最终解决", () => {
    const state = reducer.createEmptyState();
    reducer.applyResult(state, result("quiz-wrong", "2026-07-01T08:00:00.000Z", false));
    const reviewId = state.reviewItems[0].id;

    reducer.applyResult(state, result("quiz-review-1", "2026-07-02T08:00:00.000Z", true, "二叉树与BST", reviewId));
    expect(state.reviewItems[0]).toMatchObject({ intervalDays: 3, resolved: false });
    reducer.applyResult(state, result("quiz-review-2", "2026-07-05T08:00:00.000Z", true, "二叉树与BST", reviewId));
    expect(state.reviewItems[0]).toMatchObject({ intervalDays: 7, resolved: false });
    reducer.applyResult(state, result("quiz-review-3", "2026-07-12T08:00:00.000Z", true, "二叉树与BST", reviewId));
    expect(state.reviewItems[0]).toMatchObject({ intervalDays: 14, resolved: false });
    reducer.applyResult(state, result("quiz-review-4", "2026-07-26T08:00:00.000Z", true, "二叉树与BST", reviewId));
    expect(state.reviewItems[0]).toMatchObject({ intervalDays: 14, resolved: true, attempts: 5 });
    expect(state.strongTopics).toEqual(["二叉树与BST"]);
    expect(state.weakTopics).toEqual([]);
  });

  it("未到期提前答对只记录尝试，不推进复习间隔或 nextReviewAt", () => {
    const state = reducer.createEmptyState();
    reducer.applyResult(state, result("quiz-early-wrong", "2026-07-01T08:00:00.000Z", false));
    const reviewId = state.reviewItems[0].id;
    const scheduledAt = state.reviewItems[0].nextReviewAt;

    reducer.applyResult(
      state,
      result("quiz-early-correct", "2026-07-01T12:00:00.000Z", true, "二叉树与BST", reviewId)
    );

    expect(state.reviewItems[0]).toMatchObject({
      attempts: 2,
      intervalDays: 1,
      nextReviewAt: scheduledAt,
      resolved: false,
    });
  });

  it("首次掌握 milestone 在后续正确率下降后保留，成就读取持久 milestone", () => {
    const state = reducer.createEmptyState();
    const masteredAt = "2026-07-10T08:00:00.000Z";
    reducer.applyResult(state, result("quiz-mastered-once", masteredAt, true));
    reducer.applyResult(state, result("quiz-mastery-decline", "2026-07-11T08:00:00.000Z", false));

    expect(state.topicMastery[0].mastered).toBe(false);
    expect(state.masteryMilestones).toEqual([
      { courseId: "cs101", topic: "二叉树与BST", masteredAt },
    ]);
    const achievementSource = repositoryMethodSource("getAchievements");
    expect(achievementSource).toContain("state.masteryMilestones");
    expect(achievementSource).not.toContain("state.topicMastery.filter");
  });

  it("课程进度由首次掌握 milestone 推导，后续正确率下降不回退", () => {
    const getCoursesSource = repositoryMethodSource("getCourses");
    const progressSource = repositoryMethodSource("withCourseProgress");
    expect(getCoursesSource).toContain("state.masteryMilestones");
    expect(progressSource).toContain("state.masteryMilestones");
    expect(progressSource).not.toContain("state.topicMastery");
  });

  it("相同标签在不同精确 Topic 下分别累计", () => {
    const state = reducer.createEmptyState();
    reducer.applyResult(state, result("quiz-topic-a", "2026-07-10T08:00:00.000Z", false));
    reducer.applyResult(state, result("quiz-topic-b", "2026-07-11T08:00:00.000Z", true, "动态规划"));

    expect(state.tagInsights).toHaveLength(2);
    expect(state.tagInsights.map((item) => `${item.courseId}:${item.topic}:${item.tag}`).sort()).toEqual([
      "cs101:二叉树与BST:树结构",
      "cs101:动态规划:树结构",
    ]);
    expect(reducerSource).toContain("JSON.stringify([courseId, topic, tag])");
    expect(repositorySource).toContain("static async getAllTagInsights(): Promise<TagInsight[]>");
    expect(repositorySource).toContain("const insights = await LocalLearningRepository.getAllTagInsights()");
  });

  it("605 条 lesson_activity 在活动明细截断后仍保留全量复合键标签统计", () => {
    const state = reducer.createEmptyState();
    for (let index = 0; index < 605; index += 1) {
      expect(reducer.applyLearningInsightEvent(state, {
        id: `lesson-activity-${index}`,
        type: "lesson_activity",
        timestamp: `2026-07-${(index % 28 + 1).toString().padStart(2, "0")}T08:00:00.000Z`,
        courseId: "cs101",
        topic: "二叉树与BST",
        difficulty: "medium",
        tags: ["基础识别"],
        totalQuestions: 1,
        correctCount: index % 2,
      })).toBe(true);
    }
    expect(reducer.applyLearningInsightEvent(state, {
      id: "lesson-activity-604",
      type: "lesson_activity",
      timestamp: "2026-07-17T08:00:00.000Z",
      courseId: "cs101",
      topic: "二叉树与BST",
      tags: ["基础识别"],
      totalQuestions: 1,
      correctCount: 1,
    })).toBe(false);
    reducer.applyLearningInsightEvent(state, {
      id: "lesson-activity-other-topic",
      type: "lesson_activity",
      timestamp: "2026-07-18T08:00:00.000Z",
      courseId: "cs101",
      topic: "动态规划",
      tags: ["基础识别"],
      totalQuestions: 1,
      correctCount: 1,
    });

    expect(state.appliedInsightEventIds).toHaveLength(606);
    expect(state.tagInsights).toHaveLength(2);
    expect(state.tagInsights.find((item) => item.topic === "二叉树与BST")?.totalQuestions).toBe(605);
    expect(reducer.tagInsightKey("cs101", "二叉树与BST", "基础识别")).toBe(
      JSON.stringify(["cs101", "二叉树与BST", "基础识别"])
    );
    expect(reducerSource).toContain("JSON.stringify([courseId, topic, tag])");

    const appendEventSource = repositoryMethodSource("appendStudyEvent");
    expect(appendEventSource).toContain("QuizLearningStateReducer.applyLearningInsightEvent");
    expect(repositorySource).toContain(
      "putValue<QuizLearningState>(KEY_QUIZ_LEARNING_STATE, state)"
    );
  });

  it("getAllTagInsights 直接读取持久全量标签状态且不做 slice 或活动明细重算", () => {
    const source = repositoryMethodSource("getAllTagInsights");
    expect(source).toContain("await LocalLearningRepository.getQuizLearningState()");
    expect(source).toContain("state.tagInsights");
    expect(source).not.toContain("getStudyEvents");
    expect(source).not.toMatch(/\.slice\s*\(/);
    expect(source).not.toContain("for (const event");
  });
});
