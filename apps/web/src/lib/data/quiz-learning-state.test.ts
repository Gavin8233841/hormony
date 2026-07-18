import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { TextEncoder } from "node:util";
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

interface RuntimeState {
  schemaVersion: number;
  pendingResults: RuntimeResult[];
  appliedQuizIds: string[];
  appliedQuizProofs: RuntimeAppliedQuizProof[];
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

interface RuntimeAppliedQuizProof {
  quizId: string;
  verification: "verified" | "legacy-unverifiable";
  fingerprintVersion: number;
  payloadSha256: string;
}

interface RuntimeAiQuizDraft {
  schemaVersion: number;
  attemptId: string;
  sourceQuizId: string;
  courseId: string;
  courseTitle: string;
  topic: string;
  focusTag: string;
  difficulty: string;
  questionCount: number;
  questions: Array<{
    id: string;
    type: string;
    stem: string;
    options: string[];
    difficulty: string;
    tags: string[];
  }>;
  grading: Array<{
    questionId: string;
    answer: string;
    explanation: string;
    difficulty: string;
    tags: string[];
  }>;
  answers: string[];
  currentIndex: number;
  attemptSubmittedAt?: string;
  updatedAt: string;
}

interface RuntimePracticeDraft {
  schemaVersion: number;
  attemptId: string;
  courseId: string;
  courseTitle: string;
  topic: string;
  selectedReviewItemId: string;
  questions: Array<{
    id: string;
    courseId: string;
    topic: string;
    question: string;
    options: string[];
    answer: string;
    explanation: string;
    difficulty: string;
    tags: string[];
  }>;
  reviewItemIds: string[];
  answers: string[];
  currentIndex: number;
  attemptSubmittedAt?: string;
  updatedAt: string;
}

interface ReducerRuntime {
  createEmptyState(): RuntimeState;
  preparePersistentState(state: RuntimeState): boolean;
  mergeQuizEvents(state: RuntimeState, incomingEvents: RuntimeStudyEvent[]): void;
  enqueueResult(state: RuntimeState, result: RuntimeResult): boolean;
  applyPendingResults(state: RuntimeState, proofs: RuntimeAppliedQuizProof[]): number;
  applyResult(state: RuntimeState, result: RuntimeResult, proof: RuntimeAppliedQuizProof): boolean;
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
  createAnswerDraftAttemptId(prefix: string): string;
  getProfile(): Promise<RuntimeProfile | null>;
  getCourses(): Promise<RuntimeCourse[] | null>;
  appendQuizResult(result: RuntimeResult): Promise<RuntimeReceipt>;
  getLessonProgress(courseId?: string): Promise<RuntimeLessonProgress[]>;
  completeLessonChunk(courseId: string, topic: string, chunkId: string, topicChunkCount: number): Promise<void>;
  getStudyEvents(): Promise<RuntimeStudyEvent[]>;
  appendStudyEvent(event: RuntimeStudyEvent): Promise<void>;
  getAiQuizDraft(courseId: string, topic: string, focusTag: string): Promise<RuntimeAiQuizDraft | null>;
  createAiQuizDraft(draft: RuntimeAiQuizDraft, isCurrent: () => boolean): Promise<boolean>;
  saveAiQuizDraft(draft: RuntimeAiQuizDraft): Promise<void>;
  clearAiQuizDraft(attemptId: string): Promise<void>;
  getCuratedPracticeDraft(courseId: string, topic: string,
    selectedReviewItemId: string): Promise<RuntimePracticeDraft | null>;
  createCuratedPracticeDraft(draft: RuntimePracticeDraft, isCurrent: () => boolean): Promise<boolean>;
  saveCuratedPracticeDraft(draft: RuntimePracticeDraft): Promise<void>;
  clearCuratedPracticeDraft(attemptId: string): Promise<void>;
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
  private readonly writeCounts = new Map<string, number>();
  private readonly failingWrites = new Map<string, number>();
  private transactionRows: Map<string, ArkDataRow> | null = null;

  constructor(private readonly rows: Map<string, ArkDataRow>) {}

  failWrite(key: string, offset: number = 1): void {
    const current = this.writeCounts.get(key) ?? 0;
    this.failingWrites.set(key, current + offset);
  }

  private activeRows(): Map<string, ArkDataRow> {
    return this.transactionRows ?? this.rows;
  }

  private executeWrite(sql: string, bindArgs: unknown[] = []): void {
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
    this.activeRows().set(key, { payload, updatedAt });
  }

  async executeSql(sql: string, bindArgs: unknown[] = []): Promise<void> {
    this.executeWrite(sql, bindArgs);
  }

  executeSync(sql: string, bindArgs: unknown[] = []): null {
    this.executeWrite(sql, bindArgs);
    return null;
  }

  async querySql(sql: string, bindArgs: unknown[]): Promise<MemoryResultSet> {
    return this.querySqlSync(sql, bindArgs);
  }

  querySqlSync(sql: string, bindArgs: unknown[]): MemoryResultSet {
    if (sql !== "SELECT payload FROM app_state WHERE state_key = ?") {
      throw new Error(`未实现的 ArkData 查询 SQL: ${sql}`);
    }
    const [key] = bindArgs;
    if (typeof key !== "string") throw new Error("ArkData 查询键无效");
    this.queriedKeys.push(key);
    return new MemoryResultSet(this.activeRows().get(key)?.payload ?? null);
  }

  beginTransaction(): void {
    if (this.transactionRows !== null) throw new Error("ArkData fixture 已存在事务");
    this.transactionRows = new Map<string, ArkDataRow>();
    for (const [key, row] of this.rows.entries()) {
      this.transactionRows.set(key, { payload: row.payload, updatedAt: row.updatedAt });
    }
  }

  commit(): void {
    if (this.transactionRows === null) throw new Error("ArkData fixture 不存在可提交事务");
    this.rows.clear();
    for (const [key, row] of this.transactionRows.entries()) {
      this.rows.set(key, { payload: row.payload, updatedAt: row.updatedAt });
    }
    this.transactionRows = null;
  }

  rollBack(): void {
    if (this.transactionRows === null) throw new Error("ArkData fixture 不存在可回滚事务");
    this.transactionRows = null;
  }
}

class HarmonyTextEncoder {
  constructor(_encoding?: string) {}

  encodeInto(input: string): Uint8Array {
    return new TextEncoder().encode(input);
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

function appliedQuizProofFor(result: RuntimeResult): RuntimeAppliedQuizProof {
  return {
    quizId: result.quizId,
    verification: "verified",
    fingerprintVersion: 1,
    payloadSha256: "a".repeat(64),
  };
}

function applyReducerResult(state: RuntimeState, result: RuntimeResult): boolean {
  return reducer.applyResult(state, result, appliedQuizProofFor(result));
}

function applyPendingReducerResults(state: RuntimeState): number {
  return reducer.applyPendingResults(state, state.pendingResults.map(appliedQuizProofFor));
}

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
const buildersSource = readFileSync(
  fileURLToPath(
    new URL(
      "../../../../harmonyos/entry/src/main/ets/common/Builders.ets",
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
    cryptoFramework: {
      createMd: (algorithm: string) => {
        if (algorithm !== "SHA256") throw new Error(`未实现的摘要算法: ${algorithm}`);
        const hash = createHash("sha256");
        return {
          updateSync: (input: { data: Uint8Array }): void => {
            hash.update(input.data);
          },
          digestSync: (): { data: Uint8Array } => ({ data: new Uint8Array(hash.digest()) }),
        };
      },
    },
    util: { TextEncoder: HarmonyTextEncoder },
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

function keepDraft(): boolean {
  return true;
}

function aiDraft(attemptId: string, focusTag = ""): RuntimeAiQuizDraft {
  return {
    schemaVersion: 1,
    attemptId,
    sourceQuizId: `source-${attemptId}`,
    courseId: "cs101",
    courseTitle: "数据结构",
    topic: "二叉树与BST",
    focusTag,
    difficulty: "medium",
    questionCount: 5,
    questions: Array.from({ length: 5 }, (_, index) => ({
      id: `ai-${attemptId}-${index}`,
      type: "choice",
      stem: `AI 题目 ${index}`,
      options: OPTIONS.slice(),
      difficulty: "medium",
      tags: ["树结构"],
    })),
    grading: Array.from({ length: 5 }, (_, index) => ({
      questionId: `ai-${attemptId}-${index}`,
      answer: "A",
      explanation: `AI 解析 ${index}`,
      difficulty: "medium",
      tags: ["树结构"],
    })),
    answers: [OPTIONS[0], "", "", "", ""],
    currentIndex: 0,
    updatedAt: "2026-07-17T08:00:00.000Z",
  };
}

function practiceDraft(attemptId: string, selectedReviewItemId = ""): RuntimePracticeDraft {
  return {
    schemaVersion: 1,
    attemptId,
    courseId: "cs101",
    courseTitle: "数据结构",
    topic: "二叉树与BST",
    selectedReviewItemId,
    questions: [{
      id: `curated-${attemptId}`,
      courseId: "cs101",
      topic: "二叉树与BST",
      question: "精选练习题",
      options: OPTIONS.slice(),
      answer: "A",
      explanation: "精选练习解析",
      difficulty: "medium",
      tags: ["树结构"],
    }],
    reviewItemIds: [selectedReviewItemId],
    answers: [OPTIONS[1]],
    currentIndex: 0,
    updatedAt: "2026-07-17T08:00:00.000Z",
  };
}

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
      "LocalLearningRepository.applyPendingQuizResults(state)",
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
    expect(recoverySource).toContain("LocalLearningRepository.applyPendingQuizResults(state)");
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
    applyReducerResult(currentState, result("post-v10-wrong", "2026-07-17T11:00:00.000Z", false));
    applyReducerResult(currentState, result("post-v10-correct", "2026-07-17T12:00:00.000Z", true));
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
    applyReducerResult(state, result("quiz-wrong-first", "2026-07-17T11:00:00.000Z", false));
    applyReducerResult(state, result("quiz-correct-second", "2026-07-17T12:00:00.000Z", true));

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
    expect(applyPendingReducerResults(state)).toBe(1);
    expect(applyReducerResult(state, attempt)).toBe(false);

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

    expect(applyPendingReducerResults(afterRestart)).toBe(1);
    expect(applyPendingReducerResults(afterRestart)).toBe(0);
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

    expect(applyReducerResult(state, first)).toBe(true);
    expect(applyReducerResult(state, second)).toBe(true);
    expect(applyReducerResult(state, second)).toBe(false);
    expect(state.stats).toMatchObject({ totalAttempts: 2, totalQuestions: 2, correctQuestions: 1 });
    expect(state.appliedQuizIds).toEqual(["attempt-source-1", "attempt-source-2"]);
    expect(state.recentResults.map((item) => item.sourceQuizId)).toEqual([
      "quiz_cs101_tree",
      "quiz_cs101_tree",
    ]);
    expect(quizPageSource).toContain("LocalLearningRepository.createAnswerDraftAttemptId(");
    expect(quizPageSource).toContain("'quiz_attempt_' + validation.quizId");
    expect(quizPageSource).not.toContain("private attemptCounter:");
    expect(quizPageSource).toContain("this.attemptId = attemptId");
    expect(quizPageSource).toContain("quizId: this.attemptId");
    expect(quizPageSource).toContain("sourceQuizId: this.quizId");
    expect(quizPageSource).toContain("submittedAt: this.attemptSubmittedAt");
  });

  it("结果与活动明细截断时，605 次终身统计、掌握度与活动总数仍完整", () => {
    const state = reducer.createEmptyState();
    for (let index = 0; index < 605; index += 1) {
      const day = (index % 28 + 1).toString().padStart(2, "0");
      applyReducerResult(
        state,
        result(`quiz-long-${index}`, `2026-06-${day}T06:00:00.000Z`, index % 2 === 0)
      );
    }

    expect(state.recentResults).toHaveLength(20);
    expect(state.appliedQuizIds).toHaveLength(605);
    expect(state.appliedQuizProofs).toHaveLength(605);
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
    applyReducerResult(state, result("quiz-wrong", "2026-07-01T08:00:00.000Z", false));
    const reviewId = state.reviewItems[0].id;

    applyReducerResult(state, result("quiz-review-1", "2026-07-02T08:00:00.000Z", true, "二叉树与BST", reviewId));
    expect(state.reviewItems[0]).toMatchObject({ intervalDays: 3, resolved: false });
    applyReducerResult(state, result("quiz-review-2", "2026-07-05T08:00:00.000Z", true, "二叉树与BST", reviewId));
    expect(state.reviewItems[0]).toMatchObject({ intervalDays: 7, resolved: false });
    applyReducerResult(state, result("quiz-review-3", "2026-07-12T08:00:00.000Z", true, "二叉树与BST", reviewId));
    expect(state.reviewItems[0]).toMatchObject({ intervalDays: 14, resolved: false });
    applyReducerResult(state, result("quiz-review-4", "2026-07-26T08:00:00.000Z", true, "二叉树与BST", reviewId));
    expect(state.reviewItems[0]).toMatchObject({ intervalDays: 14, resolved: true, attempts: 5 });
    expect(state.strongTopics).toEqual(["二叉树与BST"]);
    expect(state.weakTopics).toEqual([]);
  });

  it("未到期提前答对只记录尝试，不推进复习间隔或 nextReviewAt", () => {
    const state = reducer.createEmptyState();
    applyReducerResult(state, result("quiz-early-wrong", "2026-07-01T08:00:00.000Z", false));
    const reviewId = state.reviewItems[0].id;
    const scheduledAt = state.reviewItems[0].nextReviewAt;

    applyReducerResult(
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
    applyReducerResult(state, result("quiz-invalid-schedule-wrong", "2026-07-01T08:00:00.000Z", false));
    const reviewId = state.reviewItems[0].id;
    state.reviewItems[0].nextReviewAt = "invalid-review-time";

    const receipt = reducer.createReceipt(
      state,
      result("quiz-invalid-schedule-receipt", "2026-07-02T08:00:00.000Z", true),
      false,
      "2026-07-02T08:00:00.000Z"
    );
    expect(receipt.dueReviewCount).toBe(1);

    applyReducerResult(
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
    applyReducerResult(state, aiWrong);
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
    applyReducerResult(state, replacementCorrect);

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
    applyReducerResult(state, replacementWrong);
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
    applyReducerResult(state, result("quiz-mastered-once", masteredAt, true));
    applyReducerResult(state, result("quiz-mastery-decline", "2026-07-11T08:00:00.000Z", false));

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
    applyReducerResult(state, result("quiz-topic-a", "2026-07-10T08:00:00.000Z", false));
    applyReducerResult(state, result("quiz-topic-b", "2026-07-11T08:00:00.000Z", true, "动态规划"));

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

  it("AI 与精选练习草稿按精确上下文持久恢复、替换和清除", async () => {
    const rows = repositoryRows();
    const first = loadRepository(rows);
    await first.repository.initialize({});

    const firstAiDraft = aiDraft("ai-draft-1");
    const focusedAiDraft = aiDraft("ai-draft-focused", "边界条件");
    const generalPracticeDraft = practiceDraft("practice-draft-1");
    const reviewPracticeDraft = practiceDraft("practice-review-draft", "review-1");
    await expect(first.repository.createAiQuizDraft(aiDraft(" ai-draft-spaced "), keepDraft))
      .rejects.toThrow("AI 测验草稿结构无效");
    await expect(first.repository.createCuratedPracticeDraft(
      practiceDraft(" practice-draft-spaced "), keepDraft))
      .rejects.toThrow("精选练习草稿结构无效");
    await expect(first.repository.clearAiQuizDraft(" ai-draft-1 "))
      .rejects.toThrow("AI 测验草稿标识无效");
    await expect(first.repository.clearCuratedPracticeDraft(" practice-draft-1 "))
      .rejects.toThrow("精选练习草稿标识无效");
    await Promise.all([
      first.repository.createAiQuizDraft(firstAiDraft, keepDraft),
      first.repository.createAiQuizDraft(focusedAiDraft, keepDraft),
      first.repository.createCuratedPracticeDraft(generalPracticeDraft, keepDraft),
      first.repository.createCuratedPracticeDraft(reviewPracticeDraft, keepDraft),
    ]);

    const firstAttemptId = first.repository.createAnswerDraftAttemptId("ai-draft");
    const secondAttemptId = first.repository.createAnswerDraftAttemptId("ai-draft");
    expect(firstAttemptId).not.toBe(secondAttemptId);
    await expect(() => first.repository.createAnswerDraftAttemptId(" invalid "))
      .toThrow("草稿标识前缀无效");

    const updatedAiDraft = aiDraft("ai-draft-1");
    updatedAiDraft.answers[1] = OPTIONS[0];
    updatedAiDraft.currentIndex = 1;
    await first.repository.saveAiQuizDraft(updatedAiDraft);
    const updatedPracticeDraft = practiceDraft("practice-review-draft", "review-1");
    updatedPracticeDraft.answers[0] = updatedPracticeDraft.questions[0].options[0];
    await first.repository.saveCuratedPracticeDraft(updatedPracticeDraft);

    const second = loadRepository(rows);
    await second.repository.initialize({});
    await expect(second.repository.getAiQuizDraft("cs101", "二叉树与BST", ""))
      .resolves.toMatchObject({ attemptId: "ai-draft-1", currentIndex: 1 });
    await expect(second.repository.getAiQuizDraft("cs101", "二叉树与BST", "边界条件"))
      .resolves.toMatchObject({ attemptId: "ai-draft-focused" });
    await expect(second.repository.getAiQuizDraft("cs101", "图的遍历", ""))
      .resolves.toBeNull();
    await expect(second.repository.getCuratedPracticeDraft("cs101", "二叉树与BST", ""))
      .resolves.toMatchObject({ attemptId: "practice-draft-1" });
    await expect(second.repository.getCuratedPracticeDraft("cs101", "二叉树与BST", "review-1"))
      .resolves.toMatchObject({ attemptId: "practice-review-draft", answers: ["A. 正确项"] });

    await second.repository.clearAiQuizDraft("ai-draft-1");
    await second.repository.clearCuratedPracticeDraft("practice-review-draft");
    await expect(second.repository.getAiQuizDraft("cs101", "二叉树与BST", ""))
      .resolves.toBeNull();
    await expect(second.repository.getCuratedPracticeDraft("cs101", "二叉树与BST", "review-1"))
      .resolves.toBeNull();
    await expect(second.repository.saveAiQuizDraft(updatedAiDraft))
      .rejects.toThrow("AI 测验草稿已被其他页面结束");
    await expect(second.repository.saveCuratedPracticeDraft(updatedPracticeDraft))
      .rejects.toThrow("精选练习草稿已被其他页面结束");

    const nextAiDraft = aiDraft("ai-draft-3");
    const nextPracticeDraft = practiceDraft("practice-review-draft-2", "review-1");
    await second.repository.createAiQuizDraft(nextAiDraft, keepDraft);
    await second.repository.createCuratedPracticeDraft(nextPracticeDraft, keepDraft);
    await expect(second.repository.getAiQuizDraft("cs101", "二叉树与BST", ""))
      .resolves.toMatchObject({ attemptId: "ai-draft-3" });
    await expect(second.repository.getCuratedPracticeDraft("cs101", "二叉树与BST", "review-1"))
      .resolves.toMatchObject({ attemptId: "practice-review-draft-2" });

    const replacementAiDraft = aiDraft("ai-draft-4");
    const replacementPracticeDraft = practiceDraft("practice-review-draft-3", "review-1");
    await expect(second.repository.createAiQuizDraft(replacementAiDraft, keepDraft))
      .rejects.toThrow("AI 测验已有其他页面创建的草稿");
    await expect(second.repository.createCuratedPracticeDraft(replacementPracticeDraft, keepDraft))
      .rejects.toThrow("精选练习已有其他页面创建的草稿");
    await expect(second.repository.getAiQuizDraft("cs101", "二叉树与BST", ""))
      .resolves.toMatchObject({ attemptId: "ai-draft-3" });
    await expect(second.repository.getCuratedPracticeDraft("cs101", "二叉树与BST", "review-1"))
      .resolves.toMatchObject({ attemptId: "practice-review-draft-2" });

    await second.repository.clearAiQuizDraft("ai-draft-3");
    await second.repository.clearCuratedPracticeDraft("practice-review-draft-2");
    await second.repository.createAiQuizDraft(replacementAiDraft, keepDraft);
    await second.repository.createCuratedPracticeDraft(replacementPracticeDraft, keepDraft);
    await expect(second.repository.saveAiQuizDraft(nextAiDraft))
      .rejects.toThrow("AI 测验草稿已被其他页面结束");
    await expect(second.repository.saveCuratedPracticeDraft(nextPracticeDraft))
      .rejects.toThrow("精选练习草稿已被其他页面结束");
    await expect(second.repository.getAiQuizDraft("cs101", "二叉树与BST", ""))
      .resolves.toMatchObject({ attemptId: "ai-draft-4" });
    await expect(second.repository.getCuratedPracticeDraft("cs101", "二叉树与BST", "review-1"))
      .resolves.toMatchObject({ attemptId: "practice-review-draft-3" });

    const queue = staticPromiseQueue("answerDraftQueue");
    const guard = queueGuardMethod(queue.name);
    for (const methodName of ["getAiQuizDraft", "createAiQuizDraft", "saveAiQuizDraft", "clearAiQuizDraft",
      "getCuratedPracticeDraft", "createCuratedPracticeDraft", "saveCuratedPracticeDraft",
      "clearCuratedPracticeDraft"]) {
      expect(repositoryMethodSource(methodName)).toContain(`LocalLearningRepository.${guard.name}(`);
    }
  });

  it("草稿清除写失败保留原 attempt，恢复后仍可更新", async () => {
    const rows = repositoryRows();
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});
    const draft = aiDraft("clear-write-failure");
    await loaded.repository.createAiQuizDraft(draft, keepDraft);
    loaded.store.failWrite("ai_quiz_drafts");
    await expect(loaded.repository.clearAiQuizDraft(draft.attemptId))
      .rejects.toThrow("ArkData fixture 写入失败: ai_quiz_drafts");

    draft.answers[0] = OPTIONS[0];
    await loaded.repository.saveAiQuizDraft(draft);
    await expect(loaded.repository.getAiQuizDraft("cs101", "二叉树与BST", ""))
      .resolves.toMatchObject({ attemptId: draft.attemptId, answers: [OPTIONS[0], "", "", "", ""] });
  });

  it("clear 后排入的跨实例 late save 不得复活 AI 或 Practice 草稿", async () => {
    const rows = repositoryRows();
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});
    const ai = aiDraft("interleaved-ai");
    const practice = practiceDraft("interleaved-practice");
    await loaded.repository.createAiQuizDraft(ai, keepDraft);
    await loaded.repository.createCuratedPracticeDraft(practice, keepDraft);

    const aiClear = loaded.repository.clearAiQuizDraft(ai.attemptId);
    const aiLateSave = expect(loaded.repository.saveAiQuizDraft(ai))
      .rejects.toThrow("AI 测验草稿已被其他页面结束");
    const practiceClear = loaded.repository.clearCuratedPracticeDraft(practice.attemptId);
    const practiceLateSave = expect(loaded.repository.saveCuratedPracticeDraft(practice))
      .rejects.toThrow("精选练习草稿已被其他页面结束");
    await aiClear;
    await practiceClear;
    await aiLateSave;
    await practiceLateSave;
    await expect(loaded.repository.getAiQuizDraft("cs101", "二叉树与BST", ""))
      .resolves.toBeNull();
    await expect(loaded.repository.getCuratedPracticeDraft("cs101", "二叉树与BST", ""))
      .resolves.toBeNull();
  });

  it("无效旧草稿不占用精确上下文，新 create 可替换并恢复", async () => {
    const rows = repositoryRows();
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});
    await loaded.repository.createAiQuizDraft(aiDraft("invalid-stored-ai"), keepDraft);
    const row = rows.get("ai_quiz_drafts");
    expect(row).toBeDefined();
    const stored = JSON.parse(row?.payload ?? "[]") as RuntimeAiQuizDraft[];
    stored[0].answers = [];
    rows.set("ai_quiz_drafts", { payload: JSON.stringify(stored), updatedAt: row?.updatedAt ?? 0 });

    const replacement = aiDraft("replacement-valid-ai");
    await loaded.repository.createAiQuizDraft(replacement, keepDraft);
    await expect(loaded.repository.getAiQuizDraft("cs101", "二叉树与BST", ""))
      .resolves.toMatchObject({ attemptId: replacement.attemptId });
  });

  it("create 的失效 guard 在同一事务回滚，后排读取看不到中间草稿", async () => {
    const rows = repositoryRows();
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});
    let guardChecks = 0;
    let queuedRead: Promise<RuntimeAiQuizDraft | null> | undefined;

    const kept = await loaded.repository.createAiQuizDraft(aiDraft("rolled-back-ai"), (): boolean => {
      guardChecks += 1;
      if (guardChecks === 2) {
        queuedRead = loaded.repository.getAiQuizDraft("cs101", "二叉树与BST", "");
      }
      return guardChecks === 1;
    });

    expect(kept).toBe(false);
    expect(guardChecks).toBe(2);
    expect(queuedRead).toBeDefined();
    await expect(queuedRead).resolves.toBeNull();
    expect(rows.has("ai_quiz_drafts")).toBe(false);
  });

  it("Practice create 回滚完成前后排 create 不可插入，回滚后新 attempt 正常落盘", async () => {
    const rows = repositoryRows();
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});
    const stale = practiceDraft("rolled-back-practice");
    const replacement = practiceDraft("replacement-practice");
    let guardChecks = 0;
    let queuedCreate: Promise<boolean> | undefined;

    const kept = await loaded.repository.createCuratedPracticeDraft(stale, (): boolean => {
      guardChecks += 1;
      if (guardChecks === 2) {
        queuedCreate = loaded.repository.createCuratedPracticeDraft(replacement, keepDraft);
      }
      return guardChecks === 1;
    });

    expect(kept).toBe(false);
    expect(queuedCreate).toBeDefined();
    await expect(queuedCreate).resolves.toBe(true);
    await expect(loaded.repository.getCuratedPracticeDraft("cs101", "二叉树与BST", ""))
      .resolves.toMatchObject({ attemptId: replacement.attemptId });
  });

  it("create guard 抛错时先回滚，不留下已取消草稿", async () => {
    const rows = repositoryRows();
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});
    let guardChecks = 0;

    await expect(loaded.repository.createAiQuizDraft(aiDraft("throwing-guard"), (): boolean => {
      guardChecks += 1;
      if (guardChecks === 2) throw new Error("生命周期 guard 失败");
      return true;
    })).rejects.toThrow("生命周期 guard 失败");

    await expect(loaded.repository.getAiQuizDraft("cs101", "二叉树与BST", ""))
      .resolves.toBeNull();
  });

  it("同 attempt create 仅允许同载荷幂等重试，不得覆盖后续答案", async () => {
    const rows = repositoryRows();
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});
    const originalAi = aiDraft("same-attempt-ai");
    const originalPractice = practiceDraft("same-attempt-practice");
    await expect(loaded.repository.createAiQuizDraft(originalAi, keepDraft)).resolves.toBe(true);
    await expect(loaded.repository.createCuratedPracticeDraft(originalPractice, keepDraft)).resolves.toBe(true);
    await expect(loaded.repository.createAiQuizDraft(originalAi, keepDraft)).resolves.toBe(true);
    await expect(loaded.repository.createCuratedPracticeDraft(originalPractice, keepDraft)).resolves.toBe(true);

    const updatedAi = aiDraft("same-attempt-ai");
    updatedAi.answers[1] = OPTIONS[1];
    updatedAi.currentIndex = 1;
    const updatedPractice = practiceDraft("same-attempt-practice");
    updatedPractice.answers[0] = OPTIONS[0];
    await loaded.repository.saveAiQuizDraft(updatedAi);
    await loaded.repository.saveCuratedPracticeDraft(updatedPractice);

    await expect(loaded.repository.createAiQuizDraft(originalAi, keepDraft))
      .rejects.toThrow("AI 测验草稿创建载荷冲突");
    await expect(loaded.repository.createCuratedPracticeDraft(originalPractice, keepDraft))
      .rejects.toThrow("精选练习草稿创建载荷冲突");
    await expect(loaded.repository.getAiQuizDraft("cs101", "二叉树与BST", ""))
      .resolves.toMatchObject({ answers: [OPTIONS[0], OPTIONS[1], "", "", ""], currentIndex: 1 });
    await expect(loaded.repository.getCuratedPracticeDraft("cs101", "二叉树与BST", ""))
      .resolves.toMatchObject({ answers: [OPTIONS[0]] });
  });

  it("同一答题 ID 只接受完全相同的重试载荷，不允许页面与 ArkData 分叉", async () => {
    const rows = repositoryRows();
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});
    const submittedAt = "2026-07-17T08:00:00.000Z";
    const firstResult = result("payload-conflict", submittedAt, false);
    const changedResult = result("payload-conflict", submittedAt, true);

    await expect(loaded.repository.appendQuizResult(firstResult)).resolves.toMatchObject({ applied: true });
    await expect(loaded.repository.appendQuizResult(firstResult)).resolves.toMatchObject({ applied: false });
    await expect(loaded.repository.appendQuizResult(changedResult))
      .rejects.toThrow("答题记录 ID 与已保存内容冲突");
    const persisted = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(persisted.stats).toMatchObject({ totalAttempts: 1, totalQuestions: 1, correctQuestions: 0 });
    expect(persisted.appliedQuizProofs).toEqual([
      expect.objectContaining({
        quizId: "payload-conflict",
        verification: "verified",
        fingerprintVersion: 1,
        payloadSha256: expect.stringMatching(/^[0-9a-f]{64}$/),
      }),
    ]);
  });

  it("结果被 recent window 淘汰后仍以持久 proof 证明同载荷幂等并拒绝异载荷", async () => {
    const rows = repositoryRows();
    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});
    const first = result("long-proof-0", "2026-07-01T08:00:00.000Z", false);
    await loaded.repository.appendQuizResult(first);
    for (let index = 1; index < 25; index += 1) {
      const day = (index + 1).toString().padStart(2, "0");
      await loaded.repository.appendQuizResult(
        result(`long-proof-${index}`, `2026-07-${day}T08:00:00.000Z`, index % 2 === 0)
      );
    }

    const beforeRetry = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(beforeRetry.recentResults).toHaveLength(20);
    expect(beforeRetry.recentResults.some((item) => item.quizId === first.quizId)).toBe(false);
    expect(beforeRetry.appliedQuizIds).toHaveLength(25);
    expect(beforeRetry.appliedQuizProofs).toHaveLength(25);
    await expect(loaded.repository.appendQuizResult(first)).resolves.toMatchObject({ applied: false });
    await expect(loaded.repository.appendQuizResult(
      result(first.quizId, first.submittedAt, true)
    )).rejects.toThrow("答题记录 ID 与已保存内容冲突");

    const afterRetry = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(afterRetry.stats.totalAttempts).toBe(25);
    expect(afterRetry.appliedQuizProofs.find((proof) => proof.quizId === first.quizId))
      .toMatchObject({ verification: "verified", fingerprintVersion: 1 });
  });

  it("schema 2 迁移仅升级 recent 内 proof，已截断历史 ID 独立 fail-closed", async () => {
    const legacy = reducer.createEmptyState();
    for (let index = 0; index < 25; index += 1) {
      applyReducerResult(
        legacy,
        result(`legacy-proof-${index}`, `2026-06-${(index + 1).toString().padStart(2, "0")}T08:00:00.000Z`,
          index % 2 === 0)
      );
    }
    const legacyPayload = JSON.parse(JSON.stringify(legacy)) as Record<string, unknown>;
    legacyPayload.schemaVersion = 2;
    delete legacyPayload.appliedQuizProofs;
    const rows = repositoryRows(12);
    rows.set("quiz_learning_state", { payload: JSON.stringify(legacyPayload), updatedAt: 99 });

    const loaded = loadRepository(rows);
    await loaded.repository.initialize({});
    const migrated = rowValue<RuntimeState>(rows, "quiz_learning_state");
    expect(rowValue<number>(rows, "schema_version")).toBe(13);
    expect(migrated.schemaVersion).toBe(3);
    expect(migrated.appliedQuizProofs).toHaveLength(25);
    expect(migrated.appliedQuizProofs.slice(0, 5).every(
      (proof) => proof.verification === "legacy-unverifiable" && proof.payloadSha256 === ""
    )).toBe(true);
    expect(migrated.appliedQuizProofs.slice(5).every(
      (proof) => proof.verification === "verified" && /^[0-9a-f]{64}$/.test(proof.payloadSha256)
    )).toBe(true);

    await expect(loaded.repository.appendQuizResult(
      result("legacy-proof-24", "2026-06-25T08:00:00.000Z", true)
    )).resolves.toMatchObject({ applied: false });
    await expect(loaded.repository.appendQuizResult(
      result("legacy-proof-0", "2026-06-01T08:00:00.000Z", true)
    )).rejects.toThrow("历史答题记录缺少可验证摘要");
    expect(rowValue<RuntimeState>(rows, "quiz_learning_state").stats.totalAttempts).toBe(25);
  });

  it("SHA-256 canonical payload 覆盖原同载荷比较全部字段且页面区分确定性错误", () => {
    const fingerprint = repositoryMethodSource("quizResultFingerprintPayload");
    const sha256 = repositoryMethodSource("sha256");
    for (const field of ["quizId", "sourceQuizId", "userId", "courseId", "topic", "source", "difficulty",
      "totalQuestions", "correctCount", "accuracy", "evaluation", "submittedAt", "weakTopics", "details"]) {
      expect(fingerprint).toContain(`result.${field}`);
    }
    for (const field of ["questionId", "stem", "options", "userAnswer", "correctAnswer", "isCorrect",
      "explanation", "difficulty", "tags", "reviewItemId"]) {
      expect(fingerprint).toContain(`detail.${field}`);
    }
    expect(sha256).toContain("cryptoFramework.createMd('SHA256')");
    expect(sha256).toContain("digest.updateSync");
    expect(sha256).toContain("digest.digestSync().data");

    for (const pageSource of [quizPageSource, practicePageSource]) {
      const submit = pageSource === quizPageSource ?
        pageMethod(pageSource, "submitQuiz").source : pageMethod(pageSource, "submit").source;
      const conflict = submit.indexOf("instanceof QuizResultConflictError");
      const unavailable = submit.indexOf("instanceof QuizResultVerificationUnavailableError");
      const transient = submit.indexOf("答题结果写回未确认");
      expect(conflict).toBeGreaterThan(-1);
      expect(unavailable).toBeGreaterThan(conflict);
      expect(transient).toBeGreaterThan(unavailable);
      expect(submit).toContain("已阻止重复写回；请放弃草稿后重新开始");
      expect(submit).toContain("已阻止重复累计；请放弃草稿后重新开始");
      expect(submit).toContain("this.writeBackBlocked = true");
      expect(pageSource).toContain("this.writeBackBlocked ? '写回已阻止'");
      expect(pageSource).toContain("!this.writeBackBlocked");
      expect(pageSource).toContain("本机完整性校验已阻止写回；请放弃草稿后重新开始");
    }
  });
});

describe("Quiz 与 Practice 结果页下一步动作", () => {
  it("答题选项与逐题解析提供稳定读屏状态和不小于 48 vp 的操作区", () => {
    const answerStart = buildersSource.indexOf("export function AnswerOption(");
    const reviewStart = buildersSource.indexOf("export function ReviewDetailRow(", answerStart);
    const answerSource = buildersSource.slice(answerStart, reviewStart);
    const reviewSource = buildersSource.slice(reviewStart);
    expect(answerStart).toBeGreaterThan(-1);
    expect(reviewStart).toBeGreaterThan(answerStart);
    expect(answerSource).toContain("enabled: boolean");
    expect(answerSource).toContain(".constraintSize({ minHeight: 58 })");
    expect(answerSource).toContain(".enabled(enabled)");
    expect(answerSource).toContain("option + (selected ? '，已选择' : '，未选择')");
    expect(answerSource).toContain("答案已冻结，等待确认写回");
    expect(reviewSource).toContain(".constraintSize({ minHeight: 48 })");
    expect(reviewSource).toContain(".accessibilityGroup(true)");
    expect(reviewSource).toContain("回答正确");
    expect(reviewSource).toContain("解析已展开");
    expect(reviewSource).toContain(".height(48)");
    expect(reviewSource).toContain("向学伴追问第 ");
    expect(quizPageSource).toContain("this.attemptSubmittedAt.length === 0 && !this.discardingDraft");
    expect(practicePageSource).toContain("this.attemptSubmittedAt.length === 0 && !this.discardingDraft");
  });

  it("Quiz 只接受与本次请求课程、Topic、重点标签和题数完全一致的题组", () => {
    const validation = pageMethod(quizPageSource, "validateQuizPackage").source;
    expect(validation).toContain("response.courseId !== this.courseId");
    expect(validation).toContain("response.topic !== this.topic");
    expect(validation).toContain("responseFocusTag !== this.focusTag");
    expect(validation).toContain("response.questions.length !== this.questionCount");
  });

  it("Quiz 长等待离页会取消精确请求，旧回调不能覆盖重进页面", () => {
    const pageShow = pageMethod(quizPageSource, "onPageShow").source;
    const pageHide = pageMethod(quizPageSource, "onPageHide").source;
    const generate = pageMethod(quizPageSource, "generateQuiz").source;
    const activeGuard = pageMethod(quizPageSource, "isActiveGeneration").source;
    const lifecycleGuard = pageMethod(quizPageSource, "isActiveLifecycle").source;
    const cancel = pageMethod(quizPageSource, "cancelQuizGeneration").source;
    expect(pageShow).toContain("this.lifecycleRunId += 1");
    expect(pageHide).toContain("this.cancelQuizGeneration(false)");
    expect(generate).toContain("new HttpRequestCancellation()");
    expect(generate).toContain("requestCancellation");
    expect(generate).toContain("this.isActiveGeneration(runId, lifecycleRunId, requestCancellation)");
    expect(activeGuard).toContain("this.isActiveLifecycle(lifecycleRunId)");
    expect(lifecycleGuard).toContain("this.lifecycleRunId === lifecycleRunId");
    expect(activeGuard).toContain("this.activeRequest === request");
    expect(cancel).toContain("request.cancel()");
    expect(quizPageSource).toContain("现在离开会取消请求，返回后可按原设置重新开始");
    expect(quizPageSource).not.toContain("返回后会自动进入答题");
  });

  it("Quiz 与 Practice 每次作答保存草稿，首次提交后冻结答案并复用提交时间", () => {
    const quizChoose = pageMethod(quizPageSource, "chooseAnswer").source;
    const quizSubmit = pageMethod(quizPageSource, "submitQuiz").source;
    const practiceChoose = pageMethod(practicePageSource, "choose").source;
    const practiceSubmit = pageMethod(practicePageSource, "submit").source;
    expect(quizChoose).toContain("this.attemptSubmittedAt.length > 0");
    expect(quizChoose).toContain("this.queueDraftSave()");
    expect(quizSubmit).toContain("if (this.attemptSubmittedAt.length === 0)");
    expect(quizSubmit).toContain("await this.persistDraft()");
    expect(quizSubmit).toContain("let draftPersisted = false");
    expect(quizSubmit).toContain("提交前草稿保存失败，本次尚未写回");
    expect(quizSubmit).toContain("clearAiQuizDraft");
    expect(practiceChoose).toContain("this.attemptSubmittedAt.length > 0");
    expect(practiceChoose).toContain("this.queueDraftSave()");
    expect(practiceSubmit).toContain("if (this.attemptSubmittedAt.length === 0)");
    expect(practiceSubmit).toContain("await this.persistDraft()");
    expect(practiceSubmit).toContain("let draftPersisted = false");
    expect(practiceSubmit).toContain("提交前草稿保存失败，本次尚未写回");
    expect(practiceSubmit).toContain("clearCuratedPracticeDraft");
  });

  it("Quiz 与 Practice 放弃草稿期间阻止后排保存重建已清除草稿", () => {
    for (const pageSource of [quizPageSource, practicePageSource]) {
      const queueSave = pageMethod(pageSource, "queueDraftSave").source;
      const discard = pageMethod(pageSource, "discardCurrentDraft").source;
      const choose = pageSource === quizPageSource ?
        pageMethod(pageSource, "chooseAnswer").source : pageMethod(pageSource, "choose").source;
      const submit = pageSource === quizPageSource ?
        pageMethod(pageSource, "submitQuiz").source : pageMethod(pageSource, "submit").source;
      const clearCall = pageSource === quizPageSource ?
        "await LocalLearningRepository.clearAiQuizDraft(attemptId)" :
        "await LocalLearningRepository.clearCuratedPracticeDraft(attemptId)";

      expect(pageSource).toContain("@State discardingDraft: boolean = false");
      expect(queueSave).toContain("this.discardingDraft");
      expect(choose).toContain("this.discardingDraft");
      expect(submit).toContain("this.discardingDraft");
      expect(pageMethod(pageSource, "goToPreviousQuestion").source).toContain("this.discardingDraft");
      expect(pageMethod(pageSource, "goToNextQuestion").source).toContain("this.discardingDraft");
      expect(pageMethod(pageSource, "goBack").source).toContain("this.discardingDraft");
      expect(pageMethod(pageSource, "onBackPress").source).toContain("this.discardingDraft");

      const discardStart = discard.indexOf("this.discardingDraft = true");
      const invalidateSaves = discard.indexOf("this.draftSaveRunId += 1");
      const clearStart = discard.indexOf(clearCall);
      expect(discardStart).toBeGreaterThan(-1);
      expect(invalidateSaves).toBeGreaterThan(discardStart);
      expect(clearStart).toBeGreaterThan(invalidateSaves);
      expect(discard).toContain("finally");
      expect(discard).toContain("this.discardingDraft = false");
      expect(pageSource).toContain("this.discardingDraft ? '正在放弃...' : '放弃草稿'");
      expect(pageSource).toContain(".enabled(!this.discardingDraft)");
      expect(pageSource).toContain("this.attemptSubmittedAt.length === 0 && !this.discardingDraft");
    }
  });

  it("Quiz 在同一事务内按精确请求 guard 决定提交或回滚生成草稿", () => {
    const generate = pageMethod(quizPageSource, "generateQuiz").source;
    const createIndex = generate.indexOf("await LocalLearningRepository.createAiQuizDraft(draft, (): boolean =>");
    const guardIndex = generate.indexOf(
      "this.isActiveGeneration(runId, lifecycleRunId, requestCancellation)", createIndex);
    const keptIndex = generate.indexOf("if (!created) return;", guardIndex);
    expect(createIndex).toBeGreaterThan(-1);
    expect(guardIndex).toBeGreaterThan(createIndex);
    expect(keptIndex).toBeGreaterThan(guardIndex);
    expect(generate).not.toContain("stale generated draft cleanup");
    expect(generate).not.toContain("clearAiQuizDraft(attemptId)");
    expect(generate).toContain("error instanceof AnswerDraftClearedError");
  });

  it("Practice 首次 create 使用精确加载 guard，离页不排第二次 create", () => {
    const persist = pageMethod(practicePageSource, "persistDraft").source;
    const reload = pageMethod(practicePageSource, "reloadQuestions").source;
    const discard = pageMethod(practicePageSource, "discardCurrentDraft").source;
    const pageHide = pageMethod(practicePageSource, "onPageHide").source;
    const queueSave = pageMethod(practicePageSource, "queueDraftSave").source;
    const createIndex = reload.indexOf(
      "await LocalLearningRepository.createCuratedPracticeDraft(draft, (): boolean =>");
    const guardIndex = reload.indexOf(
      "this.isActiveLoad(runId, lifecycleRunId) && this.attemptId === attemptId", createIndex);
    expect(createIndex).toBeGreaterThan(-1);
    expect(guardIndex).toBeGreaterThan(createIndex);
    expect(reload).toContain("if (!created || !this.isActiveLoad(runId, lifecycleRunId)) return;");
    expect(reload).toContain("this.draftCreated = true");
    expect(reload).not.toContain("clearCuratedPracticeDraft(attemptId)");
    expect(persist).not.toContain("createCuratedPracticeDraft");
    expect(persist).toContain("if (!this.draftCreated) throw new Error");
    expect(pageHide).toContain("this.draftCreated");
    expect(queueSave).toContain("!this.draftCreated");
    expect(reload).toContain("error instanceof AnswerDraftClearedError");
    expect(discard).toContain("const lifecycleRunId = this.lifecycleRunId");
    expect(discard).toContain("if (!this.isActiveLifecycle(lifecycleRunId)) return;");
  });

  it("旧页面更新已结束 attempt 时显示终态并移除必然失败的保存重试", () => {
    for (const pageSource of [quizPageSource, practicePageSource]) {
      const queueSave = pageMethod(pageSource, "queueDraftSave").source;
      const submit = pageSource === quizPageSource ?
        pageMethod(pageSource, "submitQuiz").source : pageMethod(pageSource, "submit").source;
      const handler = pageMethod(pageSource, "handleClearedDraft").source;
      const pageShow = pageMethod(pageSource, "onPageShow").source;
      const revalidate = pageMethod(pageSource, "revalidateDraft").source;
      expect(queueSave).toContain("error instanceof AnswerDraftClearedError");
      expect(queueSave.indexOf("error instanceof AnswerDraftClearedError"))
        .toBeLessThan(queueSave.indexOf("if (!showFailure) return"));
      expect(submit).toContain("instanceof AnswerDraftClearedError");
      expect(handler).toContain("reset");
      expect(handler).toContain("本轮草稿已在其他页面结束");
      expect(handler).toContain("this.hasError = false");
      expect(handler).toContain("this.restoreDraft(this.lifecycleRunId)");
      expect(pageShow).toContain("this.revalidateDraft(lifecycleRunId)");
      expect(revalidate).toContain("draft.attemptId !== attemptId");
      expect(revalidate).toContain("this.handleClearedDraft()");
    }
  });

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
    expect(rowValue<number>(rows, "schema_version")).toBe(13);
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
    expect(rowValue<number>(rows, "schema_version")).toBe(13);
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
