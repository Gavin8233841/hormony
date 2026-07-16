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
  courseId: string;
  topic: string;
  attempts: number;
  totalQuestions: number;
  correctQuestions: number;
  accuracy: number;
  mastered: boolean;
  lastPracticedAt?: string;
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
  accuracy: number;
  wrongQuestions: number;
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
  quizEvents: Array<{
    id: string;
    type: string;
    accuracy?: number;
    totalQuestions?: number;
    correctCount?: number;
  }>;
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
  source?: string;
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
  preparePersistentState(state: RuntimeState): boolean;
  enqueueResult(state: RuntimeState, result: RuntimeResult): boolean;
  applyPendingResults(state: RuntimeState): number;
  applyResult(state: RuntimeState, result: RuntimeResult): boolean;
  applyLearningInsightEvent(state: RuntimeState, event: RuntimeStudyEvent): boolean;
  createReceipt(state: RuntimeState, result: RuntimeResult, applied: boolean, now?: string): RuntimeReceipt;
  localDateKey(timestamp: string): string;
  tagInsightKey(courseId: string, topic: string, tag: string): string;
}

interface RuntimeProfile {
  stats: {
    totalQuestions: number;
    accuracy: number;
    studyDays: number;
    streakDays: number;
  };
}

interface RuntimeCourse {
  id: string;
  progress: number;
}

interface RepositoryRuntime {
  initialize(context: object): Promise<void>;
  getProfile(): Promise<RuntimeProfile | null>;
  getCourses(): Promise<RuntimeCourse[] | null>;
}

interface ArkDataRow {
  payload: string;
  updatedAt: number;
}

class MemoryResultSet {
  constructor(private readonly payload: string | null) {}

  goToFirstRow(): boolean {
    return this.payload !== null;
  }

  getString(index: number): string {
    if (index !== 0 || this.payload === null) throw new Error("ResultSet payload 不存在");
    return this.payload;
  }

  close(): void {}
}

class MemoryRdbStore {
  readonly queriedKeys: string[] = [];

  constructor(private readonly rows: Map<string, ArkDataRow>) {}

  async executeSql(sql: string, bindArgs: unknown[] = []): Promise<void> {
    if (sql === "CREATE TABLE IF NOT EXISTS app_state " +
      "(state_key TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)") return;
    if (sql !== "INSERT OR REPLACE INTO app_state " +
      "(state_key, payload, updated_at) VALUES (?, ?, ?)") {
      throw new Error(`未实现的 ArkData 写入 SQL: ${sql}`);
    }
    const [key, payload, updatedAt] = bindArgs;
    if (typeof key !== "string" || typeof payload !== "string" || typeof updatedAt !== "number") {
      throw new Error("ArkData 写入参数结构无效");
    }
    this.rows.set(key, { payload, updatedAt });
  }

  async querySql(sql: string, bindArgs: unknown[]): Promise<MemoryResultSet> {
    if (sql !== "SELECT payload FROM app_state WHERE state_key = ?") {
      throw new Error(`未实现的 ArkData 查询 SQL: ${sql}`);
    }
    const [key] = bindArgs;
    if (typeof key !== "string") throw new Error("ArkData 查询键无效");
    this.queriedKeys.push(key);
    return new MemoryResultSet(this.rows.get(key)?.payload ?? null);
  }
}

interface LoadedRepository {
  repository: RepositoryRuntime;
  store: MemoryRdbStore;
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
const practicePageSource = readFileSync(
  fileURLToPath(
    new URL(
      "../../../../harmonyos/entry/src/main/ets/pages/Practice.ets",
      import.meta.url
    )
  ),
  "utf8"
);
const lessonPageSource = readFileSync(
  fileURLToPath(
    new URL(
      "../../../../harmonyos/entry/src/main/ets/pages/Lesson.ets",
      import.meta.url
    )
  ),
  "utf8"
);

function loadRepository(rows: Map<string, ArkDataRow>): LoadedRepository {
  const sourceFile = ts.createSourceFile(
    "LocalLearningRepository.ets",
    repositorySource,
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

  const store = new MemoryRdbStore(rows);
  const runtimeExports: Record<string, unknown> = {};
  runInNewContext(transpiled.outputText, {
    exports: runtimeExports,
    module: { exports: runtimeExports },
    relationalStore: {
      SecurityLevel: { S1: "S1" },
      getRdbStore: async (): Promise<MemoryRdbStore> => store,
    },
    LearningContentRepository: {
      getTopics: (courseId: string): string[] =>
        courseId === "cs101" ? ["二叉树与BST", "图的遍历"] : [],
    },
    QuizLearningStateReducer: reducer,
  });
  const repository = runtimeExports.LocalLearningRepository;
  if (typeof repository !== "function") {
    throw new Error("LocalLearningRepository 未导出可执行类");
  }
  return { repository: repository as unknown as RepositoryRuntime, store };
}

function v10Rows(): Map<string, ArkDataRow> {
  const values: Record<string, unknown> = {
    schema_version: 10,
    profile: {
      userId: "demo",
      name: "历史用户",
      stage: "本科二年级",
      weakTopics: [],
      strongTopics: ["二叉树与BST"],
      learningStyle: "视觉型",
      stats: { totalQuestions: 40, accuracy: 0.725, studyDays: 3, streakDays: 3 },
    },
    courses: [
      {
        id: "cs101",
        title: "数据结构",
        progress: 0.5,
        docCount: 52,
        topics: ["二叉树与BST", "图的遍历"],
      },
    ],
    quiz_results: [],
    study_events: [
      {
        id: "event-v10-mastered",
        type: "quiz_mastered",
        timestamp: "2026-07-10T08:00:00.000Z",
        courseId: "cs101",
        topic: "二叉树与BST",
        source: "curated",
        difficulty: "medium",
        accuracy: 1,
        tags: ["树结构"],
        totalQuestions: 5,
        correctCount: 5,
      },
    ],
    review_items: [],
    topic_mastery: [
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 4,
        totalQuestions: 10,
        correctQuestions: 8,
        accuracy: 0.8,
        mastered: true,
        lastPracticedAt: "2026-07-10T08:00:00.000Z",
      },
    ],
    quiz_stats: {
      totalQuestions: 40,
      accuracy: 0.725,
      studyDates: ["2026-07-08", "2026-07-09", "2026-07-10"],
      updatedAt: "2026-07-10T08:00:00.000Z",
    },
    tag_insights: [
      {
        tag: "树结构",
        totalQuestions: 10,
        correctQuestions: 8,
        accuracy: 0.8,
        wrongQuestions: 2,
        lastPracticedAt: "2026-07-10T08:00:00.000Z",
        easyQuestions: 2,
        mediumQuestions: 8,
        hardQuestions: 0,
        lastDifficulty: "medium",
        lastCourseId: "cs101",
        lastTopic: "二叉树与BST",
        weakReason: "错题重复出现，建议按标签集中复盘",
        nextStep: "练 5 道同标签题，再查看错题解析",
      },
    ],
  };
  return new Map(
    Object.entries(values).map(([key, value], index): [string, ArkDataRow] => [
      key,
      { payload: JSON.stringify(value), updatedAt: index + 1 },
    ])
  );
}

function rowValue<T>(rows: Map<string, ArkDataRow>, key: string): T {
  const row = rows.get(key);
  if (row === undefined) throw new Error(`ArkData fixture 缺少 ${key}`);
  return JSON.parse(row.payload) as T;
}

interface PageMethodSource {
  name: string;
  source: string;
}

function pageMethods(pageSource: string): PageMethodSource[] {
  const declaration = /\n  (?:(?:private|public|protected)\s+)?(?:async\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\([^;\n]*\)\s*(?::\s*[^\n{]+)?\s*\{/g;
  const matches = Array.from(pageSource.matchAll(declaration));
  return matches.map((match, index): PageMethodSource => {
    const start = (match.index ?? 0) + 1;
    const end = index + 1 < matches.length ? (matches[index + 1].index ?? pageSource.length) + 1 : pageSource.length;
    return {
      name: match[1],
      source: pageSource.slice(start, end),
    };
  });
}

function pageMethod(pageSource: string, methodName: string): PageMethodSource {
  const method = pageMethods(pageSource).find((item) => item.name === methodName);
  if (method === undefined) throw new Error(`页面缺少可执行方法 ${methodName}`);
  return method;
}

function pageRouteMethod(pageSource: string, url: string): PageMethodSource {
  const methods = pageMethods(pageSource).filter((item) =>
    item.source.includes(`pushUrl({ url: '${url}' })`)
  );
  expect(methods).toHaveLength(1);
  return methods[0];
}

function expectNavigationFailureMessage(method: PageMethodSource, destination: RegExp): void {
  const catchIndex = method.source.indexOf(".catch(");
  expect(catchIndex).toBeGreaterThan(-1);
  const catchSource = method.source.slice(catchIndex);
  expect(catchSource).toMatch(/this\.message\s*=\s*'[^']*无法打开[^']*'/);
  expect(catchSource).toMatch(destination);
}
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

  it("从已发布 schema v10 行迁移后保留累计统计，并在 JSON 重读后保持一致", async () => {
    const rows = v10Rows();
    const legacyTagInsightsPayload = rows.get("tag_insights")?.payload;
    expect(legacyTagInsightsPayload).toBeDefined();
    const first = loadRepository(rows);
    await first.repository.initialize({});

    expect(first.store.queriedKeys).toEqual(expect.arrayContaining([
      "schema_version",
      "quiz_stats",
      "topic_mastery",
    ]));
    expect(rowValue<number>(rows, "schema_version")).toBeGreaterThan(10);

    const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(migrated.stats).toMatchObject({
      totalAttempts: 4,
      totalQuestions: 40,
      correctQuestions: 29,
    });
    expect(migrated.stats.quizDates.slice().sort()).toEqual([
      "2026-07-08",
      "2026-07-09",
      "2026-07-10",
    ]);
    expect(migrated.topicMastery).toEqual([
      expect.objectContaining({
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 4,
        totalQuestions: 10,
        correctQuestions: 8,
        accuracy: 0.8,
        mastered: true,
        lastPracticedAt: "2026-07-10T08:00:00.000Z",
      }),
    ]);
    expect(rows.get("tag_insights")?.payload).toBe(legacyTagInsightsPayload);
    expect(migrated.masteryMilestones).toEqual([
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        masteredAt: "2026-07-10T08:00:00.000Z",
      },
    ]);

    const firstProfile = await first.repository.getProfile();
    const firstCourses = await first.repository.getCourses();
    expect(firstProfile?.stats.totalQuestions).toBe(40);
    expect(firstProfile?.stats.accuracy).toBeCloseTo(0.725, 10);
    expect(firstCourses).toEqual([
      expect.objectContaining({ id: "cs101", progress: 0.5 }),
    ]);

    const persistedSnapshot = JSON.parse(JSON.stringify(migrated)) as RuntimeState;
    const second = loadRepository(rows);
    await second.repository.initialize({});
    const reloaded = rowValue<RuntimeState>(rows, "quiz_learning_state");
    const secondProfile = await second.repository.getProfile();
    const secondCourses = await second.repository.getCourses();

    expect(reloaded).toEqual(persistedSnapshot);
    expect(rows.get("tag_insights")?.payload).toBe(legacyTagInsightsPayload);
    expect(secondProfile?.stats.totalQuestions).toBe(40);
    expect(secondProfile?.stats.accuracy).toBeCloseTo(0.725, 10);
    expect(secondCourses).toEqual(firstCourses);
  });

  it("v10 被旧版降到 v8 后产生的新答题与历史聚合按时间边界合并且重读稳定", async () => {
    const currentState = reducer.createEmptyState();
    reducer.applyResult(currentState, result("post-v10-wrong", "2026-07-17T11:00:00.000Z", false));
    reducer.applyResult(currentState, result("post-v10-correct", "2026-07-17T12:00:00.000Z", true));
    const rows = v10Rows();
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 100 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 101 });

    const first = loadRepository(rows);
    await first.repository.initialize({});
    const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(migrated.stats).toMatchObject({
      totalAttempts: 6,
      totalQuestions: 42,
      correctQuestions: 30,
    });
    expect(migrated.topicMastery).toEqual([
      expect.objectContaining({
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 6,
        totalQuestions: 12,
        correctQuestions: 9,
        accuracy: 0.75,
        mastered: false,
      }),
    ]);
    expect(migrated.masteryMilestones).toEqual([
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        masteredAt: "2026-07-10T08:00:00.000Z",
      },
    ]);
    const firstProfile = await first.repository.getProfile();
    const firstCourses = await first.repository.getCourses();
    expect(firstProfile?.stats.totalQuestions).toBe(42);
    expect(firstProfile?.stats.accuracy).toBeCloseTo(30 / 42, 10);
    expect(firstCourses).toEqual([
      expect.objectContaining({ id: "cs101", progress: 0.5 }),
    ]);

    const persistedSnapshot = JSON.parse(JSON.stringify(migrated)) as RuntimeState;
    const second = loadRepository(rows);
    await second.repository.initialize({});
    expect(rowValue<RuntimeState>(rows, "quiz_learning_state")).toEqual(persistedSnapshot);
    expect(await second.repository.getCourses()).toEqual(firstCourses);
  });

  it("自由回答的已覆盖与有遗漏都只保留自评事实，不改变客观题统计", () => {
    const state = reducer.createEmptyState();
    expect(reducer.applyLearningInsightEvent(state, {
      id: "lesson-objective",
      type: "lesson_activity",
      timestamp: "2026-07-17T08:00:00.000Z",
      courseId: "cs101",
      topic: "二叉树与BST",
      source: "lesson_interactive",
      difficulty: "medium",
      tags: ["树结构"],
      totalQuestions: 1,
      correctCount: 1,
    })).toBe(true);
    const objectiveSnapshot = JSON.parse(JSON.stringify(state.tagInsights));

    for (const covered of [true, false]) {
      expect(reducer.applyLearningInsightEvent(state, {
        id: `lesson-self-assessment-covered-${covered.toString()}`,
        type: "lesson_activity",
        timestamp: covered ? "2026-07-17T09:00:00.000Z" : "2026-07-17T10:00:00.000Z",
        courseId: "cs101",
        topic: "二叉树与BST",
        source: "lesson_self_assessment",
        difficulty: "medium",
        tags: ["树结构"],
      })).toBe(true);
    }

    expect(state.tagInsights).toEqual(objectiveSnapshot);
    expect(state.appliedInsightEventIds).toEqual([
      "lesson-objective",
      "lesson-self-assessment-covered-true",
      "lesson-self-assessment-covered-false",
    ]);

    const selfAssessSource = pageMethod(lessonPageSource, "selfAssess").source;
    expect(selfAssessSource).toContain("this.markActivityAttempted(activity, covered, true)");
    expect(lessonPageSource).toContain("this.selfAssess(this.activeActivity()!, false)");
    expect(lessonPageSource).toContain("this.selfAssess(this.activeActivity()!, true)");
    const persistSource = pageMethod(lessonPageSource, "persistActivityEvidence").source;
    const selfAssessedBranch = persistSource.slice(
      persistSource.indexOf("if (selfAssessed)"),
      persistSource.indexOf("} else {")
    );
    expect(selfAssessedBranch).toContain("source: 'lesson_self_assessment'");
    expect(selfAssessedBranch).not.toContain("totalQuestions");
    expect(selfAssessedBranch).not.toContain("correctCount");
    expect(selfAssessedBranch).not.toContain("accuracy:");
  });

  it("先错后对仍按累计正确率记为未掌握，保存重读后 milestone 与课程进度不突变", async () => {
    const state = reducer.createEmptyState();
    reducer.applyResult(state, result("quiz-wrong-first", "2026-07-17T11:00:00.000Z", false));
    reducer.applyResult(state, result("quiz-correct-second", "2026-07-17T12:00:00.000Z", true));

    expect(state.topicMastery[0]).toMatchObject({
      attempts: 2,
      totalQuestions: 2,
      correctQuestions: 1,
      accuracy: 0.5,
      mastered: false,
    });
    expect(state.quizEvents.map((event) => event.type)).toEqual([
      "quiz_submitted",
      "quiz_submitted",
    ]);
    expect(state.quizEvents.map((event) => event.accuracy)).toEqual([0, 0.5]);
    expect(state.masteryMilestones).toEqual([]);

    const rows = v10Rows();
    rows.set("schema_version", { payload: JSON.stringify(11), updatedAt: 100 });
    rows.set("study_events", { payload: JSON.stringify([]), updatedAt: 101 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(state), updatedAt: 102 });
    const first = loadRepository(rows);
    await first.repository.initialize({});
    const firstPersisted = rowValue<RuntimeState>(rows, "quiz_learning_state");
    const firstCourses = await first.repository.getCourses();
    expect(firstPersisted.masteryMilestones).toEqual([]);
    expect(firstCourses).toEqual([
      expect.objectContaining({ id: "cs101", progress: 0 }),
    ]);

    const second = loadRepository(rows);
    await second.repository.initialize({});
    const reloaded = rowValue<RuntimeState>(rows, "quiz_learning_state");
    const secondCourses = await second.repository.getCourses();
    expect(reloaded).toEqual(firstPersisted);
    expect(reloaded.masteryMilestones).toEqual([]);
    expect(secondCourses).toEqual(firstCourses);
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

describe("Quiz 与 Practice 结果页下一步动作", () => {
  it("Quiz 有错题时主动作直接进入错题本，导航失败显示明确消息", () => {
    const routeMethod = pageRouteMethod(quizPageSource, "pages/MistakeBook");
    expectNavigationFailureMessage(routeMethod, /错题本/);

    const resultSource = pageMethod(quizPageSource, "ResultState").source;
    const conditionIndex = resultSource.indexOf("if (this.resultCorrectCount < this.resultTotalQuestions)");
    const actionIndex = resultSource.indexOf(`this.${routeMethod.name}();`, conditionIndex);
    expect(conditionIndex).toBeGreaterThan(-1);
    expect(actionIndex).toBeGreaterThan(conditionIndex);
  });

  it("Quiz 高正确率主动作按 easy→medium→hard 提升难度并重置生成态", () => {
    const transitionMethods = pageMethods(quizPageSource).filter((method) =>
      /this\.difficulty\s*===\s*'easy'[\s\S]*return\s+'medium'/.test(method.source) &&
      /return\s+'hard'/.test(method.source)
    );
    expect(transitionMethods).toHaveLength(1);
    const transitionMethod = transitionMethods[0];
    const difficultyActions = pageMethods(quizPageSource).filter((method) =>
      method.source.includes(`this.${transitionMethod.name}()`) &&
      method.source.includes("this.resultAccuracy < 0.8") &&
      method.source.includes("this.resetQuiz()") &&
      /this\.difficulty\s*=/.test(method.source)
    );
    expect(difficultyActions).toHaveLength(1);
    const actionMethod = difficultyActions[0];
    const nextDifficultyIndex = actionMethod.source.indexOf(`this.${transitionMethod.name}()`);
    const resetIndex = actionMethod.source.lastIndexOf("this.resetQuiz()");
    const assignmentIndex = actionMethod.source.lastIndexOf("this.difficulty =");
    expect(nextDifficultyIndex).toBeGreaterThan(-1);
    expect(resetIndex).toBeGreaterThan(nextDifficultyIndex);
    expect(assignmentIndex).toBeGreaterThan(resetIndex);

    const resultSource = pageMethod(quizPageSource, "ResultState").source;
    expect(resultSource).toContain(`this.${actionMethod.name}();`);
  });

  it("Practice 有错题时进入错题本，全对时保留进入 AI 测验", () => {
    const mistakeRoute = pageRouteMethod(practicePageSource, "pages/MistakeBook");
    expectNavigationFailureMessage(mistakeRoute, /错题本/);
    const quizRoute = pageRouteMethod(practicePageSource, "pages/Quiz");

    const resultSource = pageMethod(practicePageSource, "ResultView").source;
    const wrongConditionIndex = resultSource.indexOf("if (this.correctCount < this.questions.length)");
    const mistakeActionIndex = resultSource.indexOf(`this.${mistakeRoute.name}();`, wrongConditionIndex);
    const quizActionIndex = resultSource.indexOf(`else this.${quizRoute.name}();`, mistakeActionIndex);
    expect(wrongConditionIndex).toBeGreaterThan(-1);
    expect(mistakeActionIndex).toBeGreaterThan(wrongConditionIndex);
    expect(quizActionIndex).toBeGreaterThan(mistakeActionIndex);
  });

  it("Practice 的 AI 测验导航失败也显示明确消息", () => {
    const quizRoute = pageRouteMethod(practicePageSource, "pages/Quiz");
    expectNavigationFailureMessage(quizRoute, /AI 测验|测验/);
  });
});
