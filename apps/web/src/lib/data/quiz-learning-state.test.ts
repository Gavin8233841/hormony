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
  quizId?: string;
  questionId?: string;
  source?: string;
  stem?: string;
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

interface RuntimeLegacyQuizTopicHistorySnapshot {
  courseId: string;
  topic: string;
  attempts: number;
  totalQuestions: number;
  correctQuestions: number;
  lastPracticedAt?: string;
}

interface RuntimeLegacyQuizHistorySnapshot {
  updatedAt: string;
  totalQuestions: number;
  correctQuestions: number;
  resultIds: string[];
  topicMastery: RuntimeLegacyQuizTopicHistorySnapshot[];
}

interface RuntimeState {
  legacyHistorySnapshot?: RuntimeLegacyQuizHistorySnapshot;
  pendingResults: RuntimeResult[];
  appliedQuizIds: string[];
  appliedInsightEventIds: string[];
  recentResults: RuntimeResult[];
  stats: {
    totalAttempts: number;
    totalQuestions: number;
    correctQuestions: number;
    quizDates: string[];
    firstSubmittedAt?: string;
  };
  reviewItems: RuntimeReviewItem[];
  topicMastery: RuntimeMastery[];
  tagInsights: RuntimeTagInsight[];
  quizEvents: Array<{
    id: string;
    type: string;
    timestamp: string;
    courseId?: string;
    topic?: string;
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

interface RuntimeLessonProgress {
  courseId: string;
  topic: string;
  completedChunkIds: string[];
  completedAt?: string;
  completionEventId?: string;
  completionEventSyncedAt?: string;
  updatedAt: string;
}

interface RuntimeReceipt {
  applied: boolean;
  totalAttempts: number;
  totalQuestions: number;
  activeReviewCount: number;
  dueReviewCount: number;
  activityCount: number;
  courseProgress: number;
}

interface ReducerRuntime {
  createEmptyState(): RuntimeState;
  preparePersistentState(state: RuntimeState): boolean;
  mergeQuizEvents(state: RuntimeState, incomingEvents: RuntimeStudyEvent[]): void;
  enqueueResult(state: RuntimeState, result: RuntimeResult): boolean;
  applyPendingResults(state: RuntimeState): number;
  applyResult(state: RuntimeState, result: RuntimeResult): boolean;
  masteryTotals(mastery: RuntimeMastery[]): RuntimeState["stats"];
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
  appendQuizResult(result: RuntimeResult): Promise<RuntimeReceipt>;
  getLessonProgress(courseId?: string): Promise<RuntimeLessonProgress[]>;
  completeLessonChunk(courseId: string, topic: string, chunkId: string, topicChunkCount: number): Promise<void>;
  getStudyEvents(): Promise<RuntimeStudyEvent[]>;
  appendStudyEvent(event: RuntimeStudyEvent): Promise<void>;
}

interface ArkDataRow {
  payload: string;
  updatedAt: number;
}

class MemoryResultSet {
  constructor(private readonly row: ArkDataRow | null) {}

  goToFirstRow(): boolean {
    return this.row !== null;
  }

  getString(index: number): string {
    if (index !== 0 || this.row === null) throw new Error("ResultSet payload 不存在");
    return this.row.payload;
  }

  getLong(index: number): number {
    if (index !== 1 || this.row === null) throw new Error("ResultSet updated_at 不存在");
    return this.row.updatedAt;
  }

  close(): void {}
}

class MemoryRdbStore {
  readonly queriedKeys: string[] = [];
  private readonly writeCounts = new Map<string, number>();
  private readonly failingWrites = new Map<string, number>();

  constructor(private readonly rows: Map<string, ArkDataRow>) {}

  failWrite(key: string, offset: number = 1): void {
    const current = this.writeCounts.get(key) ?? 0;
    this.failingWrites.set(key, current + offset);
  }

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
    const writeCount = (this.writeCounts.get(key) ?? 0) + 1;
    this.writeCounts.set(key, writeCount);
    if (this.failingWrites.get(key) === writeCount) {
      this.failingWrites.delete(key);
      throw new Error(`ArkData fixture 写入失败: ${key}`);
    }
    this.rows.set(key, { payload, updatedAt });
  }

  async querySql(sql: string, bindArgs: unknown[]): Promise<MemoryResultSet> {
    if (sql !== "SELECT payload FROM app_state WHERE state_key = ?" &&
      sql !== "SELECT payload, updated_at FROM app_state WHERE state_key = ?") {
      throw new Error(`未实现的 ArkData 查询 SQL: ${sql}`);
    }
    const [key] = bindArgs;
    if (typeof key !== "string") throw new Error("ArkData 查询键无效");
    this.queriedKeys.push(key);
    return new MemoryResultSet(this.rows.get(key) ?? null);
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
      getTopics: (courseId: string): string[] => {
        if (courseId === "cs101") return ["二叉树与BST", "图的遍历"];
        if (courseId === "a") return ["b_c", "b:c"];
        if (courseId === "a_b") return ["c"];
        if (courseId === "a:b") return ["c"];
        return [];
      },
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

function repositoryRows(
  schemaVersion: number = 12,
  lessonProgress: RuntimeLessonProgress[] = [],
  studyEvents: RuntimeStudyEvent[] = []
): Map<string, ArkDataRow> {
  const values: Record<string, unknown> = {
    schema_version: schemaVersion,
    profile: {
      userId: "demo",
      name: "测试用户",
      stage: "本科二年级",
      weakTopics: [],
      strongTopics: [],
      learningStyle: "视觉型",
      stats: { totalQuestions: 0, accuracy: 0, studyDays: 0, streakDays: 0 },
    },
    courses: [
      {
        id: "cs101",
        title: "数据结构",
        progress: 0,
        docCount: 52,
        topics: ["二叉树与BST", "图的遍历"],
      },
    ],
    lesson_progress: lessonProgress,
    study_events: studyEvents,
    quiz_learning_state: reducer.createEmptyState(),
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

function staticPromiseQueue(queueName: string): { name: string; source: string } {
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
  const queue = queues.find((property) => repositoryMemberName(property) === queueName);
  if (queue === undefined) throw new Error(`LocalLearningRepository 缺少静态队列 ${queueName}`);
  return {
    name: repositoryMemberName(queue),
    source: queue.getText(repositorySourceFile),
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
  it("首答时间按真实时间戳比较带时区偏移的合法时间", () => {
    const later = "2026-07-17T02:00:00.000Z";
    const earlierWithOffset = "2026-07-17T09:30:00.000+08:00";
    const state = reducer.createEmptyState();
    reducer.applyResult(state, result("timezone-later", later, false));
    reducer.applyResult(state, result("timezone-earlier", earlierWithOffset, true));
    expect(state.stats.firstSubmittedAt).toBe(earlierWithOffset);

    const totals = reducer.masteryTotals([
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 1,
        totalQuestions: 1,
        correctQuestions: 0,
        accuracy: 0,
        mastered: false,
        lastPracticedAt: later,
      },
      {
        courseId: "cs101",
        topic: "图的遍历",
        attempts: 1,
        totalQuestions: 1,
        correctQuestions: 1,
        accuracy: 1,
        mastered: true,
        lastPracticedAt: earlierWithOffset,
      },
    ]);
    expect(totals.firstSubmittedAt).toBe(earlierWithOffset);
  });

  it("状态清洗重算首答时间时不按 ISO 字符串字典序", async () => {
    const later = "2026-07-17T02:00:00.000Z";
    const earlierWithOffset = "2026-07-17T09:30:00.000+08:00";
    const currentState = reducer.createEmptyState();
    reducer.applyResult(currentState, result("sanitize-timezone-later", later, false));
    currentState.recentResults.push(result("sanitize-invalid-topic", later, true, "不存在的Topic"));
    currentState.quizEvents.push({
      id: "sanitize-timezone-earlier-event",
      type: "lesson_activity",
      timestamp: earlierWithOffset,
      courseId: "cs101",
      topic: "二叉树与BST",
      totalQuestions: 1,
      correctCount: 1,
    });
    const rows = v10Rows();
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 100 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 101 });
    rows.set("study_events", { payload: JSON.stringify([]), updatedAt: 102 });
    rows.set("quiz_stats", {
      payload: JSON.stringify({
        totalQuestions: 40,
        accuracy: null,
        studyDates: [],
        updatedAt: "2026-07-10T08:00:00.000Z",
      }),
      updatedAt: 103,
    });

    await loadRepository(rows).repository.initialize({});
    expect(rowValue<RuntimeState>(rows, "quiz_learning_state").stats.firstSubmittedAt)
      .toBe(earlierWithOffset);
  });

  it("Quiz 事件按真实时间重放，不因 offset 字典序伪造掌握里程碑", () => {
    const state = reducer.createEmptyState();
    state.topicMastery = [
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 6,
        totalQuestions: 6,
        correctQuestions: 4,
        accuracy: 4 / 6,
        mastered: false,
        lastPracticedAt: "2026-07-17T02:00:00.000Z",
      },
    ];
    reducer.mergeQuizEvents(state, [
      {
        id: "offset-earlier-wrong",
        type: "quiz_submitted",
        timestamp: "2026-07-17T09:30:00.000+08:00",
        courseId: "cs101",
        topic: "二叉树与BST",
        totalQuestions: 1,
        correctCount: 0,
      },
      {
        id: "offset-later-correct",
        type: "quiz_mastered",
        timestamp: "2026-07-17T02:00:00.000Z",
        courseId: "cs101",
        topic: "二叉树与BST",
        totalQuestions: 1,
        correctCount: 1,
      },
    ]);
    expect(state.masteryMilestones).toEqual([]);
    expect(state.quizEvents.map((event) => event.id)).toEqual([
      "offset-earlier-wrong",
      "offset-later-correct",
    ]);
  });

  it("最近结果满 20 条时迟到旧结果不会挤掉真实较新记录", () => {
    const state = reducer.createEmptyState();
    for (let index = 0; index < 20; index += 1) {
      reducer.applyResult(state, result(
        `recent-newer-${index}`,
        `2026-07-17T10:${index.toString().padStart(2, "0")}:00.000Z`,
        true
      ));
    }
    reducer.applyResult(state, result("recent-late-old", "2026-07-01T08:00:00.000Z", false));
    expect(state.recentResults).toHaveLength(20);
    expect(state.recentResults.map((item) => item.quizId)).not.toContain("recent-late-old");
    expect(state.recentResults.map((item) => item.quizId)).toContain("recent-newer-0");
  });

  it("Quiz 事件满 500 条时最后补入的迟到旧事件不会挤掉较新事件", () => {
    const state = reducer.createEmptyState();
    const newerEvents: RuntimeStudyEvent[] = [];
    const start = new Date("2026-07-17T08:00:00.000Z").getTime();
    for (let index = 0; index < 500; index += 1) {
      newerEvents.push({
        id: `event-newer-${index}`,
        type: "quiz_submitted",
        timestamp: new Date(start + index * 1000).toISOString(),
        courseId: "cs101",
        topic: "二叉树与BST",
        totalQuestions: 1,
        correctCount: 0,
      });
    }
    reducer.mergeQuizEvents(state, newerEvents.concat([{
      id: "event-late-old",
      type: "quiz_submitted",
      timestamp: "2026-07-01T08:00:00.000Z",
      courseId: "cs101",
      topic: "二叉树与BST",
      totalQuestions: 1,
      correctCount: 0,
    }]));

    expect(state.quizEvents).toHaveLength(500);
    expect(state.quizEvents.map((event) => event.id)).not.toContain("event-late-old");
    expect(state.quizEvents.map((event) => event.id)).toContain("event-newer-0");
  });

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
    const queue = staticPromiseQueue("quizStateQueue");
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
    const legacyResultValidationSource = repositoryMethodSource("isValidLegacyQuizResult");
    const sanitizeSource = repositoryMethodSource("sanitizeQuizLearningState");
    expect(exactTopicSource).toContain("LearningContentRepository.getTopics(courseId).includes(topic)");
    expect(exactTopicSource).not.toContain("'综合'");
    expect(migrationSource).toContain("validateLegacyResultWindow(legacyResults)");
    expect(legacyResultValidationSource).toContain("isExactCourseTopic(result.courseId, result.topic)");
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
    expect(sanitizeSource).toContain("!statsWereValid || retainedStatsSourceCount !== originalStatsSourceCount");
    expect(sanitizeSource).toContain("QuizLearningStateReducer.masteryTotals(state.topicMastery)");
  });

  it("schema 12 日常加载清除非法时间、空 detail 和非法 tags 的 pending", async () => {
    const rows = repositoryRows();
    const state = rowValue<RuntimeState>(rows, "quiz_learning_state");
    const invalidTime = result("pending-invalid-time", "not-a-time", false);
    const nullDetail = result("pending-null-detail", "2026-07-18T08:00:00.000Z", false);
    nullDetail.details = [null as unknown as RuntimeDetail];
    const invalidTags = result("pending-invalid-tags", "2026-07-18T09:00:00.000Z", false);
    invalidTags.details[0].tags = [42 as unknown as string];
    state.pendingResults = [invalidTime, nullDetail, invalidTags];
    rows.set("quiz_learning_state", { payload: JSON.stringify(state), updatedAt: 100 });

    await loadRepository(rows).repository.initialize({});

    const persisted = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(persisted.pendingResults).toEqual([]);
    expect(persisted.appliedQuizIds).toEqual([]);
    expect(persisted.stats).toMatchObject({ totalAttempts: 0, totalQuestions: 0, correctQuestions: 0 });
  });

  it("schema 12 顶层原始值、损坏容器和 null 事件都恢复为可持久化空状态", async () => {
    for (const payload of [JSON.stringify(42), JSON.stringify({
      schemaVersion: 2,
      pendingResults: {},
      appliedQuizIds: [null, "", "kept", "kept"],
      appliedInsightEventIds: null,
      recentResults: null,
      stats: [],
      reviewItems: [null],
      topicMastery: [null],
      tagInsights: [null],
      quizEvents: [null],
      masteryMilestones: [null],
      weakTopics: null,
      strongTopics: null,
    })]) {
      const rows = repositoryRows(12, [], [null as unknown as RuntimeStudyEvent]);
      rows.set("quiz_learning_state", { payload, updatedAt: 100 });
      const loaded = loadRepository(rows);

      await loaded.repository.initialize({});

      const persisted = rowValue<RuntimeState>(rows, "quiz_learning_state");
      expect(persisted.pendingResults).toEqual([]);
      expect(persisted.recentResults).toEqual([]);
      expect(persisted.reviewItems).toEqual([]);
      expect(persisted.topicMastery).toEqual([]);
      expect(persisted.tagInsights).toEqual([]);
      expect(persisted.quizEvents).toEqual([]);
      expect(persisted.masteryMilestones).toEqual([]);
      expect(persisted.stats).toMatchObject({ totalAttempts: 0, totalQuestions: 0, correctQuestions: 0 });
      expect(await loaded.repository.getStudyEvents()).toEqual([]);
    }
  });

  it("仅 weakTopics 与 strongTopics 陈旧时日常加载也持久化刷新结果", async () => {
    const rows = repositoryRows();
    const state = rowValue<RuntimeState>(rows, "quiz_learning_state");
    state.stats = {
      totalAttempts: 1,
      totalQuestions: 5,
      correctQuestions: 5,
      quizDates: ["2026-07-18"],
      firstSubmittedAt: "2026-07-18T08:00:00.000Z",
    };
    state.topicMastery = [{
      courseId: "cs101",
      topic: "二叉树与BST",
      attempts: 1,
      totalQuestions: 5,
      correctQuestions: 5,
      accuracy: 1,
      mastered: true,
      lastPracticedAt: "2026-07-18T08:00:00.000Z",
    }];
    state.weakTopics = ["二叉树与BST"];
    state.strongTopics = [];
    rows.set("quiz_learning_state", { payload: JSON.stringify(state), updatedAt: 100 });

    await loadRepository(rows).repository.initialize({});

    const persisted = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(persisted.weakTopics).toEqual([]);
    expect(persisted.strongTopics).toEqual(["二叉树与BST"]);
    expect(rows.get("quiz_learning_state")?.updatedAt).not.toBe(100);
  });

  it("公开学习事件按真实时间而不是 offset 字符串顺序返回", async () => {
    const rows = repositoryRows(12, [], [{
      id: "stored-later",
      type: "task_completed",
      timestamp: "2026-07-17T02:00:00.000Z",
      taskId: "task-later",
    } as RuntimeStudyEvent]);
    const state = rowValue<RuntimeState>(rows, "quiz_learning_state");
    state.quizEvents = [{
      id: "quiz-offset-earlier",
      type: "quiz_submitted",
      timestamp: "2026-07-17T09:30:00.000+08:00",
      courseId: "cs101",
      topic: "二叉树与BST",
      totalQuestions: 1,
      correctCount: 0,
    }];
    rows.set("quiz_learning_state", { payload: JSON.stringify(state), updatedAt: 100 });
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});

    expect((await loaded.repository.getStudyEvents()).map((event) => event.id)).toEqual([
      "quiz-offset-earlier",
      "stored-later",
    ]);
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

  it("活动明细截断后仍由 LessonProgress 保持课程进度、学习天数和答题回执", async () => {
    const completedAt = "2026-07-12T08:00:00.000Z";
    const rows = repositoryRows(12, [
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        completedChunkIds: ["chunk-1"],
        completedAt,
        completionEventId: "lesson_completed:v1:5:cs101:7:二叉树与BST",
        completionEventSyncedAt: completedAt,
        updatedAt: completedAt,
      },
      {
        courseId: "cs101",
        topic: "不存在的Topic",
        completedChunkIds: ["legacy-chunk"],
        completedAt: "2026-07-11T08:00:00.000Z",
        completionEventId: "legacy-invalid-topic",
        completionEventSyncedAt: "2026-07-11T08:00:00.000Z",
        updatedAt: "2026-07-11T08:00:00.000Z",
      },
      {
        courseId: "cs101",
        topic: "图的遍历",
        completedChunkIds: ["legacy-chunk"],
        completedAt: "not-a-time",
        completionEventId: "legacy-invalid-time",
        completionEventSyncedAt: "2026-07-11T08:00:00.000Z",
        updatedAt: "2026-07-11T08:00:00.000Z",
      },
    ], []);
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});

    expect(await loaded.repository.getStudyEvents()).toEqual([]);
    expect(await loaded.repository.getCourses()).toEqual([
      expect.objectContaining({ id: "cs101", progress: 0.5 }),
    ]);
    expect((await loaded.repository.getProfile())?.stats.studyDays).toBe(1);

    const receipt = await loaded.repository.appendQuizResult(
      result("quiz-after-event-truncation", "2026-07-13T08:00:00.000Z", false, "图的遍历")
    );
    expect(receipt.courseProgress).toBe(0.5);
    expect(await loaded.repository.getCourses()).toEqual([
      expect.objectContaining({ id: "cs101", progress: 0.5 }),
    ]);
    expect(repositoryMethodSource("withCourseProgress")).toContain(
      "getValue<LessonProgress[]>(KEY_LESSON_PROGRESS)"
    );
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

  it("旧测验迁移在第二键写入失败后重入不重复累计历史", async () => {
    for (const failingKey of ["study_events", "schema_version"]) {
      const currentState = reducer.createEmptyState();
      reducer.applyResult(currentState, result("migration-retry-wrong", "2026-07-17T11:00:00.000Z", false));
      reducer.applyResult(currentState, result("migration-retry-correct", "2026-07-17T12:00:00.000Z", true));
      const rows = v10Rows();
      rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 100 });
      rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 101 });
      const loaded = loadRepository(rows);
      loaded.store.failWrite(failingKey);

      await expect(loaded.repository.initialize({})).rejects.toThrow(`ArkData fixture 写入失败: ${failingKey}`);
      expect(rowValue<number>(rows, "schema_version")).toBe(8);
      const firstPass = rowValue<RuntimeState>(rows, "quiz_learning_state");
      expect(firstPass.stats).toMatchObject({
        totalAttempts: 6,
        totalQuestions: 42,
        correctQuestions: 30,
        firstSubmittedAt: "2026-07-10T08:00:00.000Z",
      });
      expect(firstPass.legacyHistorySnapshot).toEqual({
        updatedAt: "2026-07-10T08:00:00.000Z",
        totalQuestions: 40,
        correctQuestions: 29,
        resultIds: [],
        topicMastery: [
          {
            courseId: "cs101",
            topic: "二叉树与BST",
            attempts: 4,
            totalQuestions: 10,
            correctQuestions: 8,
            lastPracticedAt: "2026-07-10T08:00:00.000Z",
          },
        ],
      });
      expect(rowValue<RuntimeStudyEvent[]>(rows, "study_events")).toHaveLength(
        failingKey === "study_events" ? 1 : 0
      );

      await loaded.repository.initialize({});
      const recovered = rowValue<RuntimeState>(rows, "quiz_learning_state");
      expect(recovered).toEqual(firstPass);
      expect(recovered.topicMastery).toEqual([
        expect.objectContaining({
          courseId: "cs101",
          topic: "二叉树与BST",
          attempts: 6,
          totalQuestions: 12,
          correctQuestions: 9,
        }),
      ]);
      expect(rowValue<RuntimeStudyEvent[]>(rows, "study_events")).toEqual([]);
      expect(rowValue<number>(rows, "schema_version")).toBe(12);
    }
  });

  it("旧历史快照不覆盖 pending 中更早的真实首答时间", async () => {
    const currentState = reducer.createEmptyState();
    reducer.applyResult(currentState, result("migration-pending-base", "2026-07-17T12:00:00.000Z", false));
    reducer.enqueueResult(currentState, result("migration-pending-earlier", "2026-07-05T08:00:00.000Z", true));
    const rows = v10Rows();
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 100 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 101 });

    await loadRepository(rows).repository.initialize({});
    const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(migrated.stats.firstSubmittedAt).toBe("2026-07-05T08:00:00.000Z");
    expect(migrated.stats).toMatchObject({
      totalAttempts: 5,
      totalQuestions: 41,
      correctQuestions: 30,
    });
    expect(migrated.legacyHistorySnapshot?.updatedAt).toBe("2026-07-10T08:00:00.000Z");
  });

  it("旧统计数值无效时不导入任何 aggregate 组件", async () => {
    const currentState = reducer.createEmptyState();
    reducer.applyResult(currentState, result("migration-invalid-stats-wrong", "2026-07-17T11:00:00.000Z", false));
    reducer.applyResult(currentState, result("migration-invalid-stats-correct", "2026-07-17T12:00:00.000Z", true));
    const rows = v10Rows();
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 100 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 101 });
    rows.set("quiz_stats", {
      payload: JSON.stringify({
        totalQuestions: 40,
        accuracy: null,
        studyDates: ["2026-07-08", "2026-07-09", "2026-07-10"],
        updatedAt: "2026-07-10T08:00:00.000Z",
      }),
      updatedAt: 102,
    });
    const loaded = loadRepository(rows);
    loaded.store.failWrite("study_events");

    await expect(loaded.repository.initialize({})).rejects.toThrow("ArkData fixture 写入失败: study_events");
    const firstPass = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(firstPass.legacyHistorySnapshot).toBeUndefined();
    expect(firstPass.stats).toMatchObject({ totalAttempts: 2, totalQuestions: 2, correctQuestions: 1 });
    await loaded.repository.initialize({});
    const recovered = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(recovered.topicMastery).toEqual([
      expect.objectContaining({
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 2,
        totalQuestions: 2,
        correctQuestions: 1,
      }),
    ]);
    expect(recovered.stats).toMatchObject({ totalAttempts: 2, totalQuestions: 2, correctQuestions: 1 });
    expect(recovered.legacyHistorySnapshot).toBeUndefined();
  });

  it("旧 Topic aggregate 含非法 Topic 时 existing 路径整体拒绝 aggregate", async () => {
    const currentState = reducer.createEmptyState();
    reducer.applyResult(currentState, result("migration-invalid-topic-wrong", "2026-07-17T11:00:00.000Z", false));
    reducer.applyResult(currentState, result("migration-invalid-topic-correct", "2026-07-17T12:00:00.000Z", true));
    const rows = v10Rows();
    const legacyMastery = rowValue<RuntimeMastery[]>(rows, "topic_mastery");
    legacyMastery.push({
      courseId: "cs101",
      topic: "不存在的Topic",
      attempts: 1,
      totalQuestions: 5,
      correctQuestions: 5,
      accuracy: 1,
      mastered: true,
      lastPracticedAt: "2026-07-10T09:00:00.000Z",
    });
    rows.set("topic_mastery", { payload: JSON.stringify(legacyMastery), updatedAt: 100 });
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 101 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 102 });

    await loadRepository(rows).repository.initialize({});
    const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(migrated.stats).toMatchObject({ totalAttempts: 2, totalQuestions: 2, correctQuestions: 1 });
    expect(migrated.topicMastery).toEqual([
      expect.objectContaining({ courseId: "cs101", topic: "二叉树与BST", totalQuestions: 2 }),
    ]);
    expect(migrated.legacyHistorySnapshot).toBeUndefined();
  });

  it("旧 Topic aggregate 含非法 Topic 时无 unified state 路径也不部分导入", async () => {
    const rows = v10Rows();
    const legacyMastery = rowValue<RuntimeMastery[]>(rows, "topic_mastery");
    legacyMastery.push({
      courseId: "cs101",
      topic: "不存在的Topic",
      attempts: 1,
      totalQuestions: 5,
      correctQuestions: 5,
      accuracy: 1,
      mastered: true,
      lastPracticedAt: "2026-07-10T09:00:00.000Z",
    });
    rows.set("topic_mastery", { payload: JSON.stringify(legacyMastery), updatedAt: 100 });

    await loadRepository(rows).repository.initialize({});
    const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(migrated.stats).toMatchObject({ totalAttempts: 0, totalQuestions: 0, correctQuestions: 0 });
    expect(migrated.topicMastery).toEqual([]);
    expect(migrated.legacyHistorySnapshot).toBeUndefined();
  });

  it("旧测验迁移第一键写入失败时不落快照并可完整重试", async () => {
    const currentState = reducer.createEmptyState();
    reducer.applyResult(currentState, result("migration-first-key-wrong", "2026-07-17T11:00:00.000Z", false));
    reducer.applyResult(currentState, result("migration-first-key-correct", "2026-07-17T12:00:00.000Z", true));
    const rows = v10Rows();
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 100 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 101 });
    const beforeMigration = rowValue<RuntimeState>(rows, "quiz_learning_state");
    const loaded = loadRepository(rows);
    loaded.store.failWrite("quiz_learning_state");

    await expect(loaded.repository.initialize({})).rejects.toThrow("ArkData fixture 写入失败: quiz_learning_state");
    expect(rowValue<RuntimeState>(rows, "quiz_learning_state")).toEqual(beforeMigration);
    expect(rowValue<RuntimeState>(rows, "quiz_learning_state").legacyHistorySnapshot).toBeUndefined();

    await loaded.repository.initialize({});
    const recovered = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(recovered.stats).toMatchObject({ totalAttempts: 6, totalQuestions: 42, correctQuestions: 30 });
    expect(recovered.legacyHistorySnapshot?.totalQuestions).toBe(40);
    expect(rowValue<RuntimeStudyEvent[]>(rows, "study_events")).toEqual([]);
    expect(rowValue<number>(rows, "schema_version")).toBe(12);
  });

  it("没有旧事件和练习时间时累计快照仍阻止第二键失败后的重复追加", async () => {
    const currentState = reducer.createEmptyState();
    reducer.applyResult(currentState, result("migration-stats-only-wrong", "2026-07-17T11:00:00.000Z", false));
    reducer.applyResult(currentState, result("migration-stats-only-correct", "2026-07-17T12:00:00.000Z", true));
    const rows = v10Rows();
    const legacyMastery = rowValue<RuntimeMastery[]>(rows, "topic_mastery");
    delete legacyMastery[0].lastPracticedAt;
    rows.set("topic_mastery", { payload: JSON.stringify(legacyMastery), updatedAt: 100 });
    rows.set("study_events", { payload: JSON.stringify([]), updatedAt: 101 });
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 102 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 103 });
    const loaded = loadRepository(rows);
    loaded.store.failWrite("study_events");

    await expect(loaded.repository.initialize({})).rejects.toThrow("ArkData fixture 写入失败: study_events");
    const firstPass = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(firstPass.stats).toMatchObject({
      totalAttempts: 6,
      totalQuestions: 42,
      correctQuestions: 30,
      firstSubmittedAt: "2026-07-17T11:00:00.000Z",
    });
    expect(firstPass.legacyHistorySnapshot?.totalQuestions).toBe(40);

    await loaded.repository.initialize({});
    expect(rowValue<RuntimeState>(rows, "quiz_learning_state")).toEqual(firstPass);
  });

  it("再次降级后的累计增量不受结果窗口和时间先后限制", async () => {
    const currentState = reducer.createEmptyState();
    reducer.applyResult(currentState, result("migration-repeat-wrong", "2026-07-17T11:00:00.000Z", false));
    reducer.applyResult(currentState, result("migration-repeat-correct", "2026-07-17T12:00:00.000Z", true));
    const rows = v10Rows();
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 100 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 101 });
    await loadRepository(rows).repository.initialize({});

    const downgradedResult = result("legacy-after-second-downgrade", "2026-07-18T08:00:00.000Z", true);
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 200 });
    rows.set("quiz_results", { payload: JSON.stringify([downgradedResult]), updatedAt: 201 });
    rows.set("study_events", {
      payload: JSON.stringify([
        {
          id: "event-after-second-downgrade",
          type: "quiz_mastered",
          timestamp: downgradedResult.submittedAt,
          courseId: downgradedResult.courseId,
          topic: downgradedResult.topic,
          source: downgradedResult.source,
          difficulty: downgradedResult.difficulty,
          accuracy: downgradedResult.accuracy,
          tags: ["树结构"],
          totalQuestions: 1,
          correctCount: 1,
        },
      ]),
      updatedAt: 202,
    });
    rows.set("topic_mastery", {
      payload: JSON.stringify([
        {
          courseId: "cs101",
          topic: "二叉树与BST",
          attempts: 5,
          totalQuestions: 11,
          correctQuestions: 9,
          accuracy: 9 / 11,
          mastered: true,
          lastPracticedAt: downgradedResult.submittedAt,
        },
      ]),
      updatedAt: 203,
    });
    rows.set("quiz_stats", {
      payload: JSON.stringify({
        totalQuestions: 41,
        accuracy: 30 / 41,
        studyDates: ["2026-07-08", "2026-07-09", "2026-07-10", "2026-07-18"],
        updatedAt: downgradedResult.submittedAt,
      }),
      updatedAt: 204,
    });

    await loadRepository(rows).repository.initialize({});
    const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(migrated.stats).toMatchObject({ totalAttempts: 7, totalQuestions: 43, correctQuestions: 31 });
    expect(migrated.topicMastery).toEqual([
      expect.objectContaining({ attempts: 7, totalQuestions: 13, correctQuestions: 10 }),
    ]);
    expect(migrated.appliedQuizIds).toContain("legacy-after-second-downgrade");
    expect(migrated.legacyHistorySnapshot).toEqual(expect.objectContaining({
      updatedAt: "2026-07-18T08:00:00.000Z",
      totalQuestions: 41,
      correctQuestions: 30,
      resultIds: ["legacy-after-second-downgrade"],
    }));

    const persistedSnapshot = JSON.parse(JSON.stringify(migrated)) as RuntimeState;
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 300 });
    await loadRepository(rows).repository.initialize({});
    expect(rowValue<RuntimeState>(rows, "quiz_learning_state")).toEqual(persistedSnapshot);
  });

  it("旧版已写 stats 但未写 Topic 时仍按结果窗口精确补齐一次", async () => {
    const currentState = reducer.createEmptyState();
    reducer.applyResult(currentState, result("migration-stats-prefix-wrong", "2026-07-17T11:00:00.000Z", false));
    reducer.applyResult(currentState, result("migration-stats-prefix-correct", "2026-07-17T12:00:00.000Z", true));
    const rows = v10Rows();
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 100 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 101 });
    await loadRepository(rows).repository.initialize({});

    const downgradedResult = result("legacy-stats-without-topic", "2026-07-18T08:00:00.000Z", true);
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 200 });
    rows.set("quiz_results", { payload: JSON.stringify([downgradedResult]), updatedAt: 201 });
    rows.set("quiz_stats", {
      payload: JSON.stringify({
        totalQuestions: 41,
        accuracy: 30 / 41,
        studyDates: ["2026-07-08", "2026-07-09", "2026-07-10", "2026-07-18"],
        updatedAt: downgradedResult.submittedAt,
      }),
      updatedAt: 202,
    });

    await loadRepository(rows).repository.initialize({});
    const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(migrated.stats).toMatchObject({ totalAttempts: 7, totalQuestions: 43, correctQuestions: 31 });
    expect(migrated.topicMastery).toEqual([
      expect.objectContaining({ attempts: 7, totalQuestions: 13, correctQuestions: 10 }),
    ]);
    expect(migrated.legacyHistorySnapshot).toEqual(expect.objectContaining({
      totalQuestions: 41,
      correctQuestions: 30,
      resultIds: ["legacy-stats-without-topic"],
      topicMastery: [expect.objectContaining({ totalQuestions: 10, correctQuestions: 8 })],
    }));

    const persistedSnapshot = JSON.parse(JSON.stringify(migrated)) as RuntimeState;
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 300 });
    await loadRepository(rows).repository.initialize({});
    expect(rowValue<RuntimeState>(rows, "quiz_learning_state")).toEqual(persistedSnapshot);
  });

  it("既有 schema 12 state 无快照时首次再次降级仍恢复新结果", async () => {
    const currentState = reducer.createEmptyState();
    reducer.applyResult(currentState, result("rollout-current-wrong", "2026-07-17T11:00:00.000Z", false));
    reducer.applyResult(currentState, result("rollout-current-correct", "2026-07-17T12:00:00.000Z", true));
    const rows = v10Rows();
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 100 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 101 });
    await loadRepository(rows).repository.initialize({});
    const deployedState = rowValue<RuntimeState>(rows, "quiz_learning_state");
    delete deployedState.legacyHistorySnapshot;
    rows.set("quiz_learning_state", { payload: JSON.stringify(deployedState), updatedAt: 200 });

    const downgradedResult = result("rollout-first-downgrade", "2026-07-18T08:00:00.000Z", true);
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 201 });
    rows.set("quiz_results", { payload: JSON.stringify([downgradedResult]), updatedAt: 202 });
    rows.set("quiz_stats", {
      payload: JSON.stringify({
        totalQuestions: 41,
        accuracy: 30 / 41,
        studyDates: ["2026-07-08", "2026-07-09", "2026-07-10", "2026-07-18"],
        updatedAt: downgradedResult.submittedAt,
      }),
      updatedAt: 203,
    });
    rows.set("topic_mastery", {
      payload: JSON.stringify([
        {
          courseId: "cs101",
          topic: "二叉树与BST",
          attempts: 5,
          totalQuestions: 11,
          correctQuestions: 9,
          accuracy: 9 / 11,
          mastered: true,
          lastPracticedAt: downgradedResult.submittedAt,
        },
      ]),
      updatedAt: 204,
    });

    await loadRepository(rows).repository.initialize({});
    const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(migrated.stats).toMatchObject({ totalAttempts: 7, totalQuestions: 43, correctQuestions: 31 });
    expect(migrated.topicMastery).toEqual([
      expect.objectContaining({ attempts: 7, totalQuestions: 13, correctQuestions: 10 }),
    ]);
    expect(migrated.appliedQuizIds).toContain("rollout-first-downgrade");
    expect(migrated.legacyHistorySnapshot?.resultIds).toEqual(["rollout-first-downgrade"]);
  });

  it("无 unified state 时旧版三个写入停点都恢复为同一完整结果", async () => {
    for (const stage of ["results", "stats", "topic"] as const) {
      const rows = v10Rows();
      const recoveredResult = result(`no-state-${stage}`, "2026-07-18T08:00:00.000Z", false);
      rows.set("quiz_results", { payload: JSON.stringify([recoveredResult]), updatedAt: 100 });
      if (stage !== "results") {
        rows.set("quiz_stats", {
          payload: JSON.stringify({
            totalQuestions: 41,
            accuracy: 29 / 41,
            studyDates: ["2026-07-08", "2026-07-09", "2026-07-10", "2026-07-18"],
            updatedAt: recoveredResult.submittedAt,
          }),
          updatedAt: 101,
        });
      }
      if (stage === "topic") {
        rows.set("study_events", {
          payload: JSON.stringify([
            ...rowValue<RuntimeStudyEvent[]>(v10Rows(), "study_events"),
            {
              id: "legacy-no-state-result-event",
              type: "quiz_submitted",
              timestamp: recoveredResult.submittedAt,
              courseId: recoveredResult.courseId,
              topic: recoveredResult.topic,
              source: recoveredResult.source,
              difficulty: recoveredResult.difficulty,
              totalQuestions: 1,
              correctCount: 0,
            },
          ]),
          updatedAt: 102,
        });
        rows.set("topic_mastery", {
          payload: JSON.stringify([
            {
              courseId: "cs101",
              topic: "二叉树与BST",
              attempts: 5,
              totalQuestions: 11,
              correctQuestions: 8,
              accuracy: 8 / 11,
              mastered: false,
              lastPracticedAt: recoveredResult.submittedAt,
            },
          ]),
          updatedAt: 103,
        });
      }

      await loadRepository(rows).repository.initialize({});
      const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
      expect(migrated.stats).toMatchObject({ totalAttempts: 5, totalQuestions: 41, correctQuestions: 29 });
      expect(migrated.topicMastery).toEqual([
        expect.objectContaining({ attempts: 5, totalQuestions: 11, correctQuestions: 8 }),
      ]);
      expect(migrated.reviewItems).toEqual([
        expect.objectContaining({ questionId: `question-no-state-${stage}`, resolved: false }),
      ]);
      expect(migrated.tagInsights).toEqual([
        expect.objectContaining({ courseId: "cs101", topic: "二叉树与BST", wrongQuestions: 1 }),
      ]);
      expect(migrated.quizEvents.filter((event) => event.timestamp === recoveredResult.submittedAt)).toHaveLength(1);
      expect(migrated.legacyHistorySnapshot?.resultIds).toEqual([`no-state-${stage}`]);
    }
  });

  it("无 unified state 时回填时间与缺失练习时间都不伪造 aggregate 已包含", async () => {
    const scenarios = [
      {
        quizId: "no-state-backdated",
        submittedAt: "2026-07-09T08:00:00.000Z",
        correct: true,
        removeLastPracticedAt: false,
        expectedCorrect: 30,
      },
      {
        quizId: "no-state-missing-practice-time",
        submittedAt: "2026-07-18T08:00:00.000Z",
        correct: false,
        removeLastPracticedAt: true,
        expectedCorrect: 29,
      },
      {
        quizId: "no-state-same-instant-offset",
        submittedAt: "2026-07-10T16:00:00.000+08:00",
        correct: true,
        removeLastPracticedAt: false,
        expectedCorrect: 30,
      },
    ];
    for (const scenario of scenarios) {
      const rows = v10Rows();
      if (scenario.removeLastPracticedAt) {
        const mastery = rowValue<RuntimeMastery[]>(rows, "topic_mastery");
        delete mastery[0].lastPracticedAt;
        rows.set("topic_mastery", { payload: JSON.stringify(mastery), updatedAt: 7 });
      }
      rows.set("quiz_results", {
        payload: JSON.stringify([
          result(scenario.quizId, scenario.submittedAt, scenario.correct),
        ]),
        updatedAt: 100,
      });

      await loadRepository(rows).repository.initialize({});

      const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
      expect(migrated.stats).toMatchObject({
        totalAttempts: 5,
        totalQuestions: 41,
        correctQuestions: scenario.expectedCorrect,
      });
      expect(migrated.topicMastery).toEqual([
        expect.objectContaining({
          attempts: 5,
          totalQuestions: 11,
          correctQuestions: scenario.expectedCorrect === 30 ? 9 : 8,
        }),
      ]);
      expect(migrated.appliedQuizIds).toContain(scenario.quizId);
    }
  });

  it("连续结果写入失败且 aggregate marker 在窗口外时完整回放全部结果", async () => {
    const rows = v10Rows();
    const first = result("no-state-results-only-first", "2026-07-18T08:00:00.000Z", true);
    const second = result("no-state-results-only-second", "2026-07-18T09:00:00.000Z", false);
    rows.set("quiz_results", { payload: JSON.stringify([second, first]), updatedAt: 100 });

    await loadRepository(rows).repository.initialize({});

    const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(migrated.stats).toMatchObject({
      totalAttempts: 6,
      totalQuestions: 42,
      correctQuestions: 30,
    });
    expect(migrated.topicMastery).toEqual([
      expect.objectContaining({ attempts: 6, totalQuestions: 12, correctQuestions: 9 }),
    ]);
    expect(migrated.appliedQuizIds).toEqual(expect.arrayContaining([
      "no-state-results-only-first",
      "no-state-results-only-second",
    ]));
  });

  it("无 unified 与已有 state 都按窗口物理顺序重放同一真实时刻的结果", async () => {
    for (const withUnifiedState of [false, true]) {
      const rows = v10Rows();
      const latest = result("same-time-latest-correct", "2026-07-10T16:00:00.000+08:00", true);
      const older = result("same-time-older-wrong", "2026-07-10T08:00:00.000Z", false);
      rows.set("quiz_results", { payload: JSON.stringify([latest, older]), updatedAt: 100 });
      rows.set("quiz_stats", {
        payload: JSON.stringify({
          totalQuestions: 40,
          accuracy: null,
          studyDates: [],
          updatedAt: "2026-07-10T08:00:00.000Z",
        }),
        updatedAt: 101,
      });
      rows.set("study_events", { payload: JSON.stringify([]), updatedAt: 102 });
      if (withUnifiedState) {
        rows.set("quiz_learning_state", {
          payload: JSON.stringify(reducer.createEmptyState()),
          updatedAt: 103,
        });
      }

      await loadRepository(rows).repository.initialize({});

      const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
      expect(migrated.stats).toMatchObject({ totalAttempts: 2, totalQuestions: 2, correctQuestions: 1 });
      expect(migrated.topicMastery).toEqual([
        expect.objectContaining({ attempts: 2, totalQuestions: 2, correctQuestions: 1, mastered: false }),
      ]);
      expect(migrated.masteryMilestones).toEqual([]);
      expect(migrated.quizEvents.map((event) => event.type)).toEqual([
        "quiz_submitted",
        "quiz_submitted",
      ]);
    }
  });

  it("无 unified state 从完整结果窗口重放时只在真实阈值跨越生成 mastered 事件", async () => {
    const rows = v10Rows();
    const storedWindow = [
      result("threshold-5", "2026-07-18T08:05:00.000Z", true),
      result("threshold-4", "2026-07-18T08:04:00.000Z", true),
      result("threshold-3", "2026-07-18T08:03:00.000Z", true),
      result("threshold-2", "2026-07-18T08:02:00.000Z", true),
      result("threshold-1", "2026-07-18T08:01:00.000Z", false),
    ];
    rows.set("quiz_results", { payload: JSON.stringify(storedWindow), updatedAt: 100 });
    rows.set("quiz_stats", {
      payload: JSON.stringify({
        totalQuestions: 5,
        accuracy: null,
        studyDates: ["2026-07-18"],
        updatedAt: storedWindow[0].submittedAt,
      }),
      updatedAt: 101,
    });
    rows.set("study_events", { payload: JSON.stringify([]), updatedAt: 102 });
    rows.set("topic_mastery", {
      payload: JSON.stringify([{
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 5,
        totalQuestions: 5,
        correctQuestions: 4,
        accuracy: 0.8,
        mastered: true,
        lastPracticedAt: storedWindow[0].submittedAt,
      }]),
      updatedAt: 103,
    });

    await loadRepository(rows).repository.initialize({});

    const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(migrated.stats).toMatchObject({ totalAttempts: 5, totalQuestions: 5, correctQuestions: 4 });
    expect(migrated.quizEvents.map((event) => event.type)).toEqual([
      "quiz_submitted",
      "quiz_submitted",
      "quiz_submitted",
      "quiz_submitted",
      "quiz_mastered",
    ]);
    expect(migrated.masteryMilestones).toEqual([{
      courseId: "cs101",
      topic: "二叉树与BST",
      masteredAt: storedWindow[0].submittedAt,
    }]);
  });

  it("aggregate marker 指向最旧结果时只补齐更新的结果", async () => {
    const rows = v10Rows();
    const included = result("marker-oldest-included", "2026-07-18T08:00:00.000Z", true);
    const missing = result("marker-newest-missing", "2026-07-18T09:00:00.000Z", false);
    rows.set("quiz_results", { payload: JSON.stringify([missing, included]), updatedAt: 103 });
    rows.set("quiz_stats", {
      payload: JSON.stringify({
        totalQuestions: 41,
        accuracy: 30 / 41,
        studyDates: ["2026-07-08", "2026-07-09", "2026-07-10", "2026-07-18"],
        updatedAt: included.submittedAt,
      }),
      updatedAt: 101,
    });
    rows.set("topic_mastery", {
      payload: JSON.stringify([{
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 5,
        totalQuestions: 11,
        correctQuestions: 9,
        accuracy: 9 / 11,
        mastered: true,
        lastPracticedAt: included.submittedAt,
      }]),
      updatedAt: 102,
    });

    await loadRepository(rows).repository.initialize({});

    const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(migrated.stats).toMatchObject({ totalAttempts: 6, totalQuestions: 42, correctQuestions: 30 });
    expect(migrated.topicMastery).toEqual([
      expect.objectContaining({ attempts: 6, totalQuestions: 12, correctQuestions: 9 }),
    ]);
  });

  it("aggregate marker 后仍有更旧结果时拒绝猜测连续写入", async () => {
    const rows = v10Rows();
    const missingOlder = result("marker-gap-older", "2026-07-18T08:00:00.000Z", true);
    const includedLatest = result("marker-gap-latest", "2026-07-18T09:00:00.000Z", false);
    rows.set("quiz_results", { payload: JSON.stringify([includedLatest, missingOlder]), updatedAt: 100 });
    rows.set("quiz_stats", {
      payload: JSON.stringify({
        totalQuestions: 41,
        accuracy: 29 / 41,
        studyDates: ["2026-07-08", "2026-07-09", "2026-07-10", "2026-07-18"],
        updatedAt: includedLatest.submittedAt,
      }),
      updatedAt: 101,
    });
    rows.set("topic_mastery", {
      payload: JSON.stringify([{
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 5,
        totalQuestions: 11,
        correctQuestions: 8,
        accuracy: 8 / 11,
        mastered: false,
        lastPracticedAt: includedLatest.submittedAt,
      }]),
      updatedAt: 102,
    });

    await expect(loadRepository(rows).repository.initialize({}))
      .rejects.toThrow("旧测验累计结果前缀无法证明");
    expect(rows.has("quiz_learning_state")).toBe(false);
  });

  it("aggregate 行时间相同或回拨且载荷声称包含最新结果时拒绝猜测", async () => {
    for (const aggregateRowTime of [100, 99]) {
      const rows = v10Rows();
      const latest = result(`clock-ambiguous-${aggregateRowTime}`, "2026-07-18T08:00:00.000Z", true);
      rows.set("quiz_results", { payload: JSON.stringify([latest]), updatedAt: 100 });
      rows.set("quiz_stats", {
        payload: JSON.stringify({
          totalQuestions: 41,
          accuracy: 30 / 41,
          studyDates: ["2026-07-18"],
          updatedAt: latest.submittedAt,
        }),
        updatedAt: aggregateRowTime,
      });
      rows.set("topic_mastery", {
        payload: JSON.stringify([{
          courseId: "cs101",
          topic: "二叉树与BST",
          attempts: 5,
          totalQuestions: 11,
          correctQuestions: 9,
          accuracy: 9 / 11,
          mastered: true,
          lastPracticedAt: latest.submittedAt,
        }]),
        updatedAt: aggregateRowTime,
      });

      await expect(loadRepository(rows).repository.initialize({}))
        .rejects.toThrow("写入阶段无法区分");
      expect(rows.has("quiz_learning_state")).toBe(false);
    }
  });

  it("同一 submittedAt 的前一结果 aggregate 不能冒充已包含最新结果", async () => {
    const rows = v10Rows();
    const submittedAt = "2026-07-18T08:00:00.000Z";
    const latest = result("same-submitted-at-latest", submittedAt, false);
    const older = result("same-submitted-at-older", submittedAt, true);
    rows.set("quiz_results", { payload: JSON.stringify([latest, older]), updatedAt: 100 });
    rows.set("quiz_stats", {
      payload: JSON.stringify({
        totalQuestions: 41,
        accuracy: 30 / 41,
        studyDates: ["2026-07-18"],
        updatedAt: submittedAt,
      }),
      updatedAt: 200,
    });
    rows.set("topic_mastery", {
      payload: JSON.stringify([{
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 5,
        totalQuestions: 11,
        correctQuestions: 9,
        accuracy: 9 / 11,
        mastered: true,
        lastPracticedAt: submittedAt,
      }]),
      updatedAt: 200,
    });

    await expect(loadRepository(rows).repository.initialize({}))
      .rejects.toThrow("同一提交时间的写入阶段无法区分");
    expect(rows.has("quiz_learning_state")).toBe(false);
  });

  it("无 unified state 时物理行较新但 aggregate 载荷不对应最新结果会拒绝推断", async () => {
    const rows = v10Rows();
    const latest = result("no-state-ambiguous-stage", "2026-07-18T08:00:00.000Z", true);
    rows.set("quiz_results", { payload: JSON.stringify([latest]), updatedAt: 100 });
    rows.set("quiz_stats", {
      payload: JSON.stringify({
        totalQuestions: 41,
        accuracy: 30 / 41,
        studyDates: ["2026-07-08", "2026-07-09", "2026-07-10"],
        updatedAt: "2026-07-17T08:00:00.000Z",
      }),
      updatedAt: 101,
    });

    await expect(loadRepository(rows).repository.initialize({}))
      .rejects.toThrow("旧测验累计写入阶段与最新结果不一致");
    expect(rows.has("quiz_learning_state")).toBe(false);
  });

  it("旧 quiz event 清理第二写失败后重入仍只保留一个统一事件", async () => {
    const rows = v10Rows();
    const latest = result("legacy-event-retry", "2026-07-18T08:00:00.000Z", false);
    rows.set("quiz_results", { payload: JSON.stringify([latest]), updatedAt: 100 });
    rows.set("quiz_stats", {
      payload: JSON.stringify({
        totalQuestions: 41,
        accuracy: 29 / 41,
        studyDates: ["2026-07-08", "2026-07-09", "2026-07-10", "2026-07-18"],
        updatedAt: latest.submittedAt,
      }),
      updatedAt: 101,
    });
    rows.set("study_events", {
      payload: JSON.stringify([{
        id: "legacy-event-retry-source",
        type: "quiz_submitted",
        timestamp: latest.submittedAt,
        courseId: latest.courseId,
        topic: latest.topic,
        source: latest.source,
        difficulty: latest.difficulty,
        totalQuestions: latest.totalQuestions,
        correctCount: latest.correctCount,
      }]),
      updatedAt: 102,
    });
    rows.set("topic_mastery", {
      payload: JSON.stringify([{
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 5,
        totalQuestions: 11,
        correctQuestions: 8,
        accuracy: 8 / 11,
        mastered: false,
        lastPracticedAt: latest.submittedAt,
      }]),
      updatedAt: 103,
    });
    const loaded = loadRepository(rows);
    loaded.store.failWrite("study_events");

    await expect(loaded.repository.initialize({})).rejects.toThrow("ArkData fixture 写入失败: study_events");
    const firstPass = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(firstPass.quizEvents.filter((event) => event.timestamp === latest.submittedAt))
      .toEqual([expect.objectContaining({ id: "quiz_legacy-event-retry" })]);

    await loaded.repository.initialize({});
    const recovered = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(recovered.quizEvents.filter((event) => event.timestamp === latest.submittedAt))
      .toEqual([expect.objectContaining({ id: "quiz_legacy-event-retry" })]);
    expect(rowValue<RuntimeStudyEvent[]>(rows, "study_events")).toEqual([]);
  });

  it("同载荷旧事件按一对一消费，保留额外不同 ID 的历史事件", async () => {
    const rows = v10Rows();
    const latest = result("legacy-event-multiset", "2026-07-18T08:00:00.000Z", true);
    rows.set("quiz_results", { payload: JSON.stringify([latest]), updatedAt: 100 });
    rows.set("quiz_stats", {
      payload: JSON.stringify({
        totalQuestions: 41,
        accuracy: 30 / 41,
        studyDates: ["2026-07-08", "2026-07-09", "2026-07-10", "2026-07-18"],
        updatedAt: latest.submittedAt,
      }),
      updatedAt: 101,
    });
    const duplicatePayload = {
      type: "quiz_mastered",
      timestamp: latest.submittedAt,
      courseId: latest.courseId,
      topic: latest.topic,
      source: latest.source,
      difficulty: latest.difficulty,
      totalQuestions: latest.totalQuestions,
      correctCount: latest.correctCount,
    };
    rows.set("study_events", {
      payload: JSON.stringify([
        { id: "legacy-event-window-result", ...duplicatePayload },
        { id: "legacy-event-older-result", ...duplicatePayload },
      ]),
      updatedAt: 102,
    });
    rows.set("topic_mastery", {
      payload: JSON.stringify([{
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 5,
        totalQuestions: 11,
        correctQuestions: 9,
        accuracy: 9 / 11,
        mastered: true,
        lastPracticedAt: latest.submittedAt,
      }]),
      updatedAt: 103,
    });

    await loadRepository(rows).repository.initialize({});

    const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(migrated.quizEvents.filter((event) => event.timestamp === latest.submittedAt)
      .map((event) => event.id).sort()).toEqual([
      "legacy-event-older-result",
      "quiz_legacy-event-multiset",
    ]);
  });

  it("完全相同 ID 与内容的重复旧事件先归一再与窗口结果一对一消费", async () => {
    const rows = v10Rows();
    const latest = result("legacy-event-exact-duplicate", "2026-07-18T08:00:00.000Z", false);
    rows.set("quiz_results", { payload: JSON.stringify([latest]), updatedAt: 100 });
    rows.set("quiz_stats", {
      payload: JSON.stringify({
        totalQuestions: 41,
        accuracy: 29 / 41,
        studyDates: ["2026-07-18"],
        updatedAt: latest.submittedAt,
      }),
      updatedAt: 101,
    });
    const duplicatedEvent = {
      id: "legacy-event-exact-duplicate-source",
      type: "quiz_submitted",
      timestamp: latest.submittedAt,
      courseId: latest.courseId,
      topic: latest.topic,
      source: latest.source,
      difficulty: latest.difficulty,
      totalQuestions: latest.totalQuestions,
      correctCount: latest.correctCount,
    };
    rows.set("study_events", {
      payload: JSON.stringify([duplicatedEvent, duplicatedEvent]),
      updatedAt: 102,
    });
    rows.set("topic_mastery", {
      payload: JSON.stringify([{
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 5,
        totalQuestions: 11,
        correctQuestions: 8,
        accuracy: 8 / 11,
        mastered: false,
        lastPracticedAt: latest.submittedAt,
      }]),
      updatedAt: 103,
    });

    await loadRepository(rows).repository.initialize({});

    expect(rowValue<RuntimeState>(rows, "quiz_learning_state").quizEvents
      .filter((event) => event.timestamp === latest.submittedAt))
      .toEqual([expect.objectContaining({ id: "quiz_legacy-event-exact-duplicate" })]);
  });

  it("旧 quiz event 同 ID 不同内容时明确拒绝迁移", async () => {
    const rows = v10Rows();
    rows.set("study_events", {
      payload: JSON.stringify([
        {
          id: "legacy-event-conflict",
          type: "quiz_submitted",
          timestamp: "2026-07-10T08:00:00.000Z",
          courseId: "cs101",
          topic: "二叉树与BST",
          totalQuestions: 1,
          correctCount: 0,
        },
        {
          id: "legacy-event-conflict",
          type: "quiz_mastered",
          timestamp: "2026-07-10T08:00:00.000Z",
          courseId: "cs101",
          topic: "二叉树与BST",
          totalQuestions: 1,
          correctCount: 1,
        },
      ]),
      updatedAt: 100,
    });

    await expect(loadRepository(rows).repository.initialize({}))
      .rejects.toThrow("旧测验事件 ID 与已保存内容冲突");
    expect(rows.has("quiz_learning_state")).toBe(false);
  });

  it("pending 与旧结果窗口同 ID 时保留完整 reducer 副作用且只应用一次", async () => {
    const rows = v10Rows();
    const currentState = reducer.createEmptyState();
    reducer.applyResult(currentState, result("pending-overlap-base", "2026-07-17T12:00:00.000Z", true));
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 100 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 101 });
    await loadRepository(rows).repository.initialize({});

    const pendingResult = result("pending-legacy-same-id", "2026-07-18T08:00:00.000Z", false);
    const persisted = rowValue<RuntimeState>(rows, "quiz_learning_state");
    reducer.enqueueResult(persisted, pendingResult);
    const beforeReviewCount = persisted.reviewItems.length;
    const beforeTagQuestions = persisted.tagInsights.find((item) => item.tag === "树结构")?.totalQuestions ?? 0;
    const beforeEventCount = persisted.quizEvents.length;
    rows.set("quiz_learning_state", { payload: JSON.stringify(persisted), updatedAt: 200 });
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 201 });
    rows.set("quiz_results", { payload: JSON.stringify([pendingResult]), updatedAt: 202 });

    await loadRepository(rows).repository.initialize({});
    const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(migrated.pendingResults).toEqual([]);
    expect(migrated.stats).toMatchObject({ totalAttempts: 6, totalQuestions: 42, correctQuestions: 30 });
    expect(migrated.reviewItems).toHaveLength(beforeReviewCount + 1);
    expect(migrated.tagInsights.find((item) => item.tag === "树结构")?.totalQuestions)
      .toBe(beforeTagQuestions + 1);
    expect(migrated.quizEvents).toHaveLength(beforeEventCount + 1);
    expect(migrated.quizEvents.filter((event) => event.id === "quiz_pending-legacy-same-id")).toHaveLength(1);
    expect(migrated.appliedQuizIds.filter((id) => id === "pending-legacy-same-id")).toHaveLength(1);
  });

  it("累计快照损坏或旧来源计数回退时明确拒绝迁移", async () => {
    const rows = v10Rows();
    const currentState = reducer.createEmptyState();
    reducer.applyResult(currentState, result("migration-snapshot-base", "2026-07-17T12:00:00.000Z", true));
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 100 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 101 });
    await loadRepository(rows).repository.initialize({});

    const damagedState = rowValue<RuntimeState>(rows, "quiz_learning_state");
    damagedState.legacyHistorySnapshot!.totalQuestions = -1;
    rows.set("quiz_learning_state", { payload: JSON.stringify(damagedState), updatedAt: 200 });
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 201 });
    await expect(loadRepository(rows).repository.initialize({})).rejects.toThrow("旧测验累计迁移快照无效");

    const restoredState = rowValue<RuntimeState>(rows, "quiz_learning_state");
    restoredState.legacyHistorySnapshot = {
      updatedAt: "2026-07-10T08:00:00.000Z",
      totalQuestions: 40,
      correctQuestions: 29,
      resultIds: [],
      topicMastery: [
        {
          courseId: "cs101",
          topic: "二叉树与BST",
          attempts: 4,
          totalQuestions: 10,
          correctQuestions: 8,
          lastPracticedAt: "2026-07-10T08:00:00.000Z",
        },
      ],
    };
    rows.set("quiz_learning_state", { payload: JSON.stringify(restoredState), updatedAt: 202 });
    rows.set("quiz_stats", {
      payload: JSON.stringify({
        totalQuestions: 39,
        accuracy: 28 / 39,
        studyDates: ["2026-07-08", "2026-07-09"],
        updatedAt: "2026-07-09T08:00:00.000Z",
      }),
      updatedAt: 203,
    });
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 204 });
    await expect(loadRepository(rows).repository.initialize({})).rejects.toThrow("旧测验累计统计发生回退");
  });

  it("Topic 累计回退、增量矛盾与已合并目标缺失时分别拒绝迁移", async () => {
    const scenarios = [
      { kind: "rollback", error: "旧测验 Topic 累计发生回退" },
      { kind: "invalid-delta", error: "旧测验 Topic 累计增量不一致" },
      { kind: "missing-target", error: "旧测验 Topic 迁移基线缺失" },
    ];
    for (const scenario of scenarios) {
      const rows = v10Rows();
      const currentState = reducer.createEmptyState();
      reducer.applyResult(currentState, result(`migration-topic-${scenario.kind}`, "2026-07-17T12:00:00.000Z", true));
      rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 100 });
      rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 101 });
      await loadRepository(rows).repository.initialize({});

      const legacyMastery = rowValue<RuntimeMastery[]>(rows, "topic_mastery");
      if (scenario.kind === "rollback") {
        legacyMastery[0].attempts = 3;
        legacyMastery[0].totalQuestions = 9;
        legacyMastery[0].correctQuestions = 7;
      } else if (scenario.kind === "invalid-delta") {
        legacyMastery[0].attempts = 5;
        legacyMastery[0].totalQuestions = 11;
        legacyMastery[0].correctQuestions = 10;
      } else {
        const persisted = rowValue<RuntimeState>(rows, "quiz_learning_state");
        persisted.topicMastery = [];
        rows.set("quiz_learning_state", { payload: JSON.stringify(persisted), updatedAt: 200 });
      }
      rows.set("topic_mastery", { payload: JSON.stringify(legacyMastery), updatedAt: 201 });
      rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 202 });

      await expect(loadRepository(rows).repository.initialize({})).rejects.toThrow(scenario.error);
      expect(rowValue<number>(rows, "schema_version")).toBe(8);
    }
  });

  it("旧版仅写结果窗口时从完整新前缀恢复统计和 Topic", async () => {
    const rows = v10Rows();
    const currentState = reducer.createEmptyState();
    reducer.applyResult(currentState, result("migration-window-base", "2026-07-17T12:00:00.000Z", true));
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 100 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 101 });
    await loadRepository(rows).repository.initialize({});

    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 200 });
    rows.set("quiz_results", {
      payload: JSON.stringify([result("migration-window-unseen", "2026-07-18T08:00:00.000Z", true)]),
      updatedAt: 201,
    });
    await loadRepository(rows).repository.initialize({});
    const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(migrated.stats).toMatchObject({ totalAttempts: 6, totalQuestions: 42, correctQuestions: 31 });
    expect(migrated.topicMastery).toEqual([
      expect.objectContaining({ attempts: 6, totalQuestions: 12, correctQuestions: 10 }),
    ]);
    expect(migrated.appliedQuizIds).toContain("migration-window-unseen");
    expect(migrated.legacyHistorySnapshot?.resultIds).toEqual(["migration-window-unseen"]);
  });

  it("旧结果窗口达到 20 条且与空基线无交集时明确拒绝推断", async () => {
    const rows = v10Rows();
    const currentState = reducer.createEmptyState();
    reducer.applyResult(currentState, result("migration-full-window-base", "2026-07-17T12:00:00.000Z", true));
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 100 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 101 });
    await loadRepository(rows).repository.initialize({});
    const persisted = rowValue<RuntimeState>(rows, "quiz_learning_state");

    const fullWindow: RuntimeResult[] = [];
    for (let index = 0; index < 20; index += 1) {
      fullWindow.push(result(`migration-full-window-${index}`, `2026-07-18T08:${index.toString().padStart(2, "0")}:00.000Z`, true));
    }
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 200 });
    rows.set("quiz_results", { payload: JSON.stringify(fullWindow), updatedAt: 201 });

    await expect(loadRepository(rows).repository.initialize({}))
      .rejects.toThrow("旧测验结果窗口无法证明完整");
    expect(rowValue<RuntimeState>(rows, "quiz_learning_state")).toEqual(persisted);
  });

  it("有效旧结果中的更早 submittedAt 参与首答时间", async () => {
    const currentState = reducer.createEmptyState();
    reducer.applyResult(currentState, result("migration-first-time-current", "2026-07-17T12:00:00.000Z", false));
    const rows = v10Rows();
    rows.set("schema_version", { payload: JSON.stringify(8), updatedAt: 100 });
    rows.set("quiz_learning_state", { payload: JSON.stringify(currentState), updatedAt: 101 });
    rows.set("quiz_results", {
      payload: JSON.stringify([result("migration-first-time-legacy", "2026-07-01T08:00:00.000Z", true)]),
      updatedAt: 102,
    });
    rows.set("study_events", { payload: JSON.stringify([]), updatedAt: 103 });

    await loadRepository(rows).repository.initialize({});
    expect(rowValue<RuntimeState>(rows, "quiz_learning_state").stats.firstSubmittedAt)
      .toBe("2026-07-01T08:00:00.000Z");
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
    const selfAssessedStart = persistSource.indexOf("if (selfAssessed)");
    const selfAssessedBranch = persistSource.slice(
      selfAssessedStart,
      persistSource.indexOf("} else {", selfAssessedStart)
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

  it("终身未掌握但最近一次全对时，按累计计数修正旧字段且不伪造 milestone", () => {
    const state = reducer.createEmptyState();
    state.topicMastery = [
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 2,
        totalQuestions: 10,
        correctQuestions: 5,
        accuracy: 1,
        mastered: true,
        lastPracticedAt: "2026-07-17T12:00:00.000Z",
      },
    ];
    state.quizEvents = [
      {
        id: "recent-perfect-not-lifetime-mastery",
        type: "quiz_mastered",
        timestamp: "2026-07-17T12:00:00.000Z",
        courseId: "cs101",
        topic: "二叉树与BST",
        totalQuestions: 5,
        correctCount: 5,
      },
    ];

    expect(reducer.preparePersistentState(state)).toBe(true);
    reducer.mergeQuizEvents(state, []);
    expect(state.topicMastery[0]).toMatchObject({ accuracy: 0.5, mastered: false });
    expect(state.masteryMilestones).toEqual([]);
  });

  it("旧弱历史合并新全对后累计仍低于 80%，不按事件后缀生成 milestone", () => {
    const state = reducer.createEmptyState();
    state.topicMastery = [
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 3,
        totalQuestions: 15,
        correctQuestions: 7,
        accuracy: 1,
        mastered: true,
        lastPracticedAt: "2026-07-17T12:00:00.000Z",
      },
    ];
    state.quizEvents = [
      {
        id: "new-perfect-after-weak-history",
        type: "quiz_mastered",
        timestamp: "2026-07-17T12:00:00.000Z",
        courseId: "cs101",
        topic: "二叉树与BST",
        totalQuestions: 5,
        correctCount: 5,
      },
    ];

    reducer.preparePersistentState(state);
    reducer.mergeQuizEvents(state, []);

    expect(state.topicMastery[0]).toMatchObject({ accuracy: 7 / 15, mastered: false });
    expect(state.masteryMilestones).toEqual([]);
  });

  it("事件合并只按精确 ID 去重，相同载荷的不同答题均参与重放", () => {
    const state = reducer.createEmptyState();
    state.topicMastery = [
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 2,
        totalQuestions: 2,
        correctQuestions: 2,
        accuracy: 1,
        mastered: true,
        lastPracticedAt: "2026-07-17T12:00:00.000Z",
      },
    ];
    const first: RuntimeStudyEvent = {
      id: "exact-id-a",
      type: "quiz_mastered",
      timestamp: "2026-07-17T12:00:00.000Z",
      courseId: "cs101",
      topic: "二叉树与BST",
      totalQuestions: 1,
      correctCount: 1,
    };
    state.quizEvents = [first];

    reducer.mergeQuizEvents(state, [
      { ...first, id: "exact-id-b" },
      { ...first, correctCount: 0 },
    ]);

    expect(state.quizEvents.map((event) => event.id)).toEqual(["exact-id-a", "exact-id-b"]);
    expect(state.quizEvents.map((event) => event.correctCount)).toEqual([1, 1]);
    expect(state.masteryMilestones).toEqual([
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        masteredAt: "2026-07-17T12:00:00.000Z",
      },
    ]);
  });

  it("空白事件 ID 与无效时间不会进入重放或生成 milestone", () => {
    const state = reducer.createEmptyState();
    const validEvent: RuntimeStudyEvent = {
      id: "valid-mastery-event",
      type: "quiz_mastered",
      timestamp: "2026-07-10T08:00:00.000Z",
      courseId: "cs101",
      topic: "二叉树与BST",
      totalQuestions: 5,
      correctCount: 5,
    };

    reducer.mergeQuizEvents(state, [
      { ...validEvent, id: "   " },
      { ...validEvent, id: "invalid-time-event", timestamp: "not-a-time" },
      validEvent,
    ]);

    expect(state.quizEvents.map((event) => event.id)).toEqual([validEvent.id]);
    expect(state.masteryMilestones).toEqual([
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        masteredAt: validEvent.timestamp,
      },
    ]);
  });

  it("完整 501 条事件先重放早期首次掌握，再压缩明细且保留 milestone", () => {
    const state = reducer.createEmptyState();
    const masteredAt = "2026-01-01T00:00:00.000Z";
    state.topicMastery = [
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        attempts: 501,
        totalQuestions: 505,
        correctQuestions: 4,
        accuracy: 4 / 505,
        mastered: false,
        lastPracticedAt: "2026-01-02T00:08:19.000Z",
      },
    ];
    const events: RuntimeStudyEvent[] = [
      {
        id: "early-first-mastery",
        type: "quiz_mastered",
        timestamp: masteredAt,
        courseId: "cs101",
        topic: "二叉树与BST",
        totalQuestions: 5,
        correctCount: 4,
      },
    ];
    for (let index = 0; index < 500; index += 1) {
      events.push({
        id: `later-wrong-${index}`,
        type: "quiz_submitted",
        timestamp: new Date(Date.UTC(2026, 0, 2, 0, 0, index)).toISOString(),
        courseId: "cs101",
        topic: "二叉树与BST",
        totalQuestions: 1,
        correctCount: 0,
      });
    }

    reducer.mergeQuizEvents(state, events);

    expect(state.quizEvents).toHaveLength(500);
    expect(state.quizEvents.some((event) => event.id === "early-first-mastery")).toBe(false);
    expect(state.masteryMilestones).toEqual([
      { courseId: "cs101", topic: "二叉树与BST", masteredAt },
    ]);
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

  it("无效旧复习时间应按已到期恢复并写回合法的下一次时间", () => {
    const state = reducer.createEmptyState();
    reducer.applyResult(state, result("quiz-invalid-schedule-wrong", "2026-07-01T08:00:00.000Z", false));
    const reviewId = state.reviewItems[0].id;
    state.reviewItems[0].nextReviewAt = "invalid-review-time";

    const receipt = reducer.createReceipt(
      state,
      result("quiz-invalid-schedule-receipt", "2026-07-02T08:00:00.000Z", true),
      false,
      "2026-07-02T08:00:00.000Z"
    );
    expect(receipt.dueReviewCount).toBe(1);

    reducer.applyResult(
      state,
      result("quiz-invalid-schedule-correct", "2026-07-02T08:00:00.000Z", true, "二叉树与BST", reviewId)
    );

    expect(state.reviewItems[0]).toMatchObject({
      id: reviewId,
      attempts: 2,
      intervalDays: 3,
      nextReviewAt: "2026-07-05T08:00:00.000Z",
      resolved: false,
    });
  });

  it("旧 AI 错题使用精选替代题时保留复习项 ID 并同步真实题目身份", () => {
    const state = reducer.createEmptyState();
    const aiWrong = result("ai-wrong", "2026-07-01T08:00:00.000Z", false);
    aiWrong.source = "ai";
    aiWrong.sourceQuizId = "ai-package-1";
    reducer.applyResult(state, aiWrong);
    const reviewId = state.reviewItems[0].id;

    const replacementCorrect = result(
      "curated-replacement-correct",
      "2026-07-02T08:00:00.000Z",
      true,
      "二叉树与BST",
      reviewId
    );
    replacementCorrect.details[0].questionId = "curated-fallback-1";
    replacementCorrect.details[0].stem = "同主题精选替代题";
    reducer.applyResult(state, replacementCorrect);

    expect(state.reviewItems).toHaveLength(1);
    expect(state.reviewItems[0]).toMatchObject({
      id: reviewId,
      questionId: "curated-fallback-1",
      source: "curated",
      quizId: "curated-replacement-correct",
      stem: "同主题精选替代题",
      attempts: 2,
      intervalDays: 3,
      resolved: false,
    });

    const replacementWrong = result(
      "curated-replacement-wrong",
      "2026-07-05T08:00:00.000Z",
      false,
      "二叉树与BST",
      reviewId
    );
    replacementWrong.details[0].questionId = "curated-fallback-1";
    replacementWrong.details[0].stem = "同主题精选替代题";
    reducer.applyResult(state, replacementWrong);
    expect(state.reviewItems).toHaveLength(1);
    expect(state.reviewItems[0]).toMatchObject({
      id: reviewId,
      questionId: "curated-fallback-1",
      source: "curated",
      attempts: 3,
      intervalDays: 1,
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
    const persistedMilestones = JSON.parse(JSON.stringify(state.masteryMilestones));
    reducer.preparePersistentState(state);
    reducer.mergeQuizEvents(state, []);
    expect(state.masteryMilestones).toEqual(persistedMilestones);
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

describe("Lesson 事件与完成进度 outbox", () => {
  it("互动事件第二写失败后重试仍只累计一次", async () => {
    const rows = repositoryRows();
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});
    const event: RuntimeStudyEvent = {
      id: "lesson-activity-retry",
      type: "lesson_activity",
      timestamp: "2026-07-17T08:00:00.000Z",
      courseId: "cs101",
      topic: "二叉树与BST",
      source: "lesson_interactive",
      difficulty: "medium",
      tags: ["树结构"],
      totalQuestions: 1,
      correctCount: 1,
    };

    loaded.store.failWrite("quiz_learning_state");
    await expect(loaded.repository.appendStudyEvent(event)).rejects.toThrow("ArkData fixture 写入失败");
    expect(rowValue<RuntimeStudyEvent[]>(rows, "study_events")).toHaveLength(1);

    await loaded.repository.appendStudyEvent(event);
    const persisted = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(persisted.appliedInsightEventIds).toEqual([event.id]);
    expect(persisted.tagInsights).toEqual([
      expect.objectContaining({
        courseId: "cs101",
        topic: "二叉树与BST",
        tag: "树结构",
        totalQuestions: 1,
        correctQuestions: 1,
      }),
    ]);
    expect(rowValue<RuntimeStudyEvent[]>(rows, "study_events")).toHaveLength(1);
  });

  it("完成事件写失败后重试复用稳定 ID 并保持首次完成时间", async () => {
    const rows = repositoryRows();
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});
    loaded.store.failWrite("study_events");

    await expect(
      loaded.repository.completeLessonChunk("cs101", "二叉树与BST", "chunk-1", 1)
    ).rejects.toThrow("ArkData fixture 写入失败");
    const pending = rowValue<RuntimeLessonProgress[]>(rows, "lesson_progress")[0];
    expect(pending.completedAt).toBeDefined();
    expect(pending.completionEventId).toBe(
      "lesson_completed:v1:5:cs101:7:二叉树与BST"
    );
    expect(pending.completionEventSyncedAt).toBeUndefined();

    await loaded.repository.completeLessonChunk("cs101", "二叉树与BST", "chunk-1", 1);
    await loaded.repository.completeLessonChunk("cs101", "二叉树与BST", "chunk-1", 1);
    const completed = rowValue<RuntimeLessonProgress[]>(rows, "lesson_progress")[0];
    const events = rowValue<RuntimeStudyEvent[]>(rows, "study_events").filter(
      (event) => event.type === "lesson_completed"
    );
    expect(completed.completedAt).toBe(pending.completedAt);
    expect(completed.completionEventId).toBe(pending.completionEventId);
    expect(completed.completionEventSyncedAt).toBeDefined();
    expect(events).toHaveLength(1);
    expect(events[0].id).toBe(pending.completionEventId);
  });

  it("完成事件 ID 与已存事件语义冲突时保持 outbox 未同步", async () => {
    const rows = repositoryRows();
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});
    const eventId = "lesson_completed:v1:5:cs101:7:二叉树与BST";
    await loaded.repository.appendStudyEvent({
      id: eventId,
      type: "task_completed",
      timestamp: "2026-07-10T08:00:00.000Z",
      courseId: "cs101",
      topic: "二叉树与BST",
    });

    await expect(
      loaded.repository.completeLessonChunk("cs101", "二叉树与BST", "chunk-1", 1)
    ).rejects.toThrow("学习活动 ID 与已保存内容冲突");

    const progress = rowValue<RuntimeLessonProgress[]>(rows, "lesson_progress")[0];
    expect(progress.completionEventId).toBe(eventId);
    expect(progress.completionEventSyncedAt).toBeUndefined();
    expect(rowValue<RuntimeStudyEvent[]>(rows, "study_events")).toEqual([
      expect.objectContaining({ id: eventId, type: "task_completed" }),
    ]);
  });

  it("事件成功但同步标记写失败时重试不重复完成事件", async () => {
    const rows = repositoryRows();
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});
    loaded.store.failWrite("lesson_progress", 2);

    await expect(
      loaded.repository.completeLessonChunk("cs101", "二叉树与BST", "chunk-1", 1)
    ).rejects.toThrow("ArkData fixture 写入失败");
    expect(rowValue<RuntimeStudyEvent[]>(rows, "study_events")).toHaveLength(1);
    expect(
      rowValue<RuntimeLessonProgress[]>(rows, "lesson_progress")[0].completionEventSyncedAt
    ).toBeUndefined();

    await loaded.repository.completeLessonChunk("cs101", "二叉树与BST", "chunk-1", 1);
    expect(rowValue<RuntimeStudyEvent[]>(rows, "study_events")).toHaveLength(1);
    expect(
      rowValue<RuntimeLessonProgress[]>(rows, "lesson_progress")[0].completionEventSyncedAt
    ).toBeDefined();
  });

  it("并发完成两个 chunk 不丢进度且只生成一个完成事件", async () => {
    const rows = repositoryRows();
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});

    await Promise.all([
      loaded.repository.completeLessonChunk("cs101", "二叉树与BST", "chunk-a", 2),
      loaded.repository.completeLessonChunk("cs101", "二叉树与BST", "chunk-b", 2),
    ]);

    const progress = rowValue<RuntimeLessonProgress[]>(rows, "lesson_progress")[0];
    expect(progress.completedChunkIds.slice().sort()).toEqual(["chunk-a", "chunk-b"]);
    expect(progress.completedAt).toBeDefined();
    expect(progress.completionEventSyncedAt).toBeDefined();
    expect(
      rowValue<RuntimeStudyEvent[]>(rows, "study_events").filter(
        (event) => event.type === "lesson_completed"
      )
    ).toHaveLength(1);

    const queue = staticPromiseQueue("lessonProgressQueue");
    const guard = queueGuardMethod(queue.name);
    expect(repositoryMethodSource("completeLessonChunk")).toContain(
      `LocalLearningRepository.${guard.name}(`
    );
  });

  it("schema 12 初始化冲刷写入或同步标记失败后可在同进程重试", async () => {
    const completedAt = "2026-07-10T08:00:00.000Z";
    for (const failingKey of ["study_events", "lesson_progress"]) {
      const eventId = "lesson_completed:v1:5:cs101:7:二叉树与BST";
      const rows = repositoryRows(12, [
        {
          courseId: "cs101",
          topic: "二叉树与BST",
          completedChunkIds: ["chunk-1"],
          completedAt,
          completionEventId: eventId,
          updatedAt: completedAt,
        },
      ]);
      const loaded = loadRepository(rows);
      loaded.store.failWrite(failingKey);

      await expect(loaded.repository.initialize({})).rejects.toThrow("ArkData fixture 写入失败");
      expect(
        rowValue<RuntimeLessonProgress[]>(rows, "lesson_progress")[0].completionEventSyncedAt
      ).toBeUndefined();

      await loaded.repository.initialize({});
      const events = rowValue<RuntimeStudyEvent[]>(rows, "study_events").filter(
        (event) => event.type === "lesson_completed"
      );
      expect(events).toHaveLength(1);
      expect(events[0].id).toBe(eventId);
      expect(
        rowValue<RuntimeLessonProgress[]>(rows, "lesson_progress")[0].completionEventSyncedAt
      ).toBeDefined();
    }
  });

  it("schema 12 空白完成事件 ID 会恢复为稳定 ID 后再冲刷", async () => {
    const completedAt = "2026-07-10T08:00:00.000Z";
    const rows = repositoryRows(12, [
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        completedChunkIds: ["chunk-1"],
        completedAt,
        completionEventId: "   ",
        updatedAt: completedAt,
      },
    ]);
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});

    const progress = rowValue<RuntimeLessonProgress[]>(rows, "lesson_progress")[0];
    expect(progress.completionEventId).toBe(
      "lesson_completed:v1:5:cs101:7:二叉树与BST"
    );
    expect(progress.completionEventSyncedAt).toBeDefined();
    expect(rowValue<RuntimeStudyEvent[]>(rows, "study_events")).toEqual([
      expect.objectContaining({
        id: progress.completionEventId,
        type: "lesson_completed",
        timestamp: completedAt,
      }),
    ]);
  });

  it("schema 11 迁移保留已有事件并补写缺失事件且重读稳定", async () => {
    const completedAt = "2026-07-10T08:00:00.000Z";
    const rows = repositoryRows(11, [
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        completedChunkIds: ["a"],
        completedAt,
        updatedAt: completedAt,
      },
      {
        courseId: "cs101",
        topic: "图的遍历",
        completedChunkIds: ["b"],
        completedAt,
        updatedAt: completedAt,
      },
      {
        courseId: "a",
        topic: "b_c",
        completedChunkIds: [],
        updatedAt: "2026-07-09T08:00:00.000Z",
      },
    ], [
      {
        id: "legacy-lesson-completed",
        type: "lesson_completed",
        timestamp: completedAt,
        courseId: "cs101",
        topic: "二叉树与BST",
      },
    ]);
    const first = loadRepository(rows);
    await first.repository.initialize({});

    const migrated = rowValue<RuntimeLessonProgress[]>(rows, "lesson_progress");
    expect(rowValue<number>(rows, "schema_version")).toBe(12);
    expect(migrated[0]).toMatchObject({
      completionEventId: "legacy-lesson-completed",
      completionEventSyncedAt: completedAt,
    });
    expect(migrated[1].completionEventId).toBe(
      "lesson_completed:v1:5:cs101:4:图的遍历"
    );
    expect(migrated[1].completionEventSyncedAt).toBeDefined();
    expect(migrated[2].completionEventId).toBeUndefined();
    expect(rowValue<RuntimeStudyEvent[]>(rows, "study_events")).toHaveLength(2);

    const snapshot = JSON.parse(rows.get("lesson_progress")!.payload) as RuntimeLessonProgress[];
    const second = loadRepository(rows);
    await second.repository.initialize({});
    expect(rowValue<RuntimeLessonProgress[]>(rows, "lesson_progress")).toEqual(snapshot);
    expect(rowValue<RuntimeStudyEvent[]>(rows, "study_events")).toHaveLength(2);
  });

  it("迁移写失败后同进程初始化可重试，长度前缀 ID 不发生分隔符碰撞", async () => {
    const completedAt = "2026-07-10T08:00:00.000Z";
    const rows = repositoryRows(11, [
      {
        courseId: "cs101",
        topic: "二叉树与BST",
        completedChunkIds: ["a"],
        completedAt,
        updatedAt: completedAt,
      },
    ]);
    const loaded = loadRepository(rows);
    loaded.store.failWrite("lesson_progress");
    await expect(loaded.repository.initialize({})).rejects.toThrow("ArkData fixture 写入失败");
    expect(rowValue<number>(rows, "schema_version")).toBe(11);

    await loaded.repository.initialize({});
    expect(rowValue<number>(rows, "schema_version")).toBe(12);
    expect(rowValue<RuntimeStudyEvent[]>(rows, "study_events")).toHaveLength(1);

    await loaded.repository.completeLessonChunk("a", "b:c", "one", 1);
    await loaded.repository.completeLessonChunk("a:b", "c", "one", 1);
    const special = rowValue<RuntimeLessonProgress[]>(rows, "lesson_progress").filter(
      (item) => item.courseId === "a" || item.courseId === "a:b"
    );
    expect(special).toHaveLength(2);
    expect(special[0].completionEventId).not.toBe(special[1].completionEventId);
  });
});
