import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import path from "node:path";
import { isStatelessDeployment } from "@/lib/deployment";
import type {
  ConversationRecord,
  Course,
  KnowledgeChunk,
  Quiz,
  QuizResult,
  RecentActivity,
  StudyPlan,
  UserProfile,
} from "@/lib/types";

const STATE_VERSION = 1;

export interface PersistedCourseGroup {
  userId: string;
  courses: Course[];
}

export interface PersistedAppState {
  version: number;
  profiles: UserProfile[];
  courseGroups: PersistedCourseGroup[];
  plans: StudyPlan[];
  generatedQuizzes: Quiz[];
  uploadedKnowledge: KnowledgeChunk[];
  quizResults: QuizResult[];
  conversations: ConversationRecord[];
  activityLog: RecentActivity[];
}

export function isAppStatePersistenceEnabled(): boolean {
  if (isStatelessDeployment()) return false;
  const mode = process.env.APP_STATE_PERSISTENCE?.trim().toLowerCase();
  return mode === "on";
}

function stateFilePath(): string {
  const configured = process.env.APP_STATE_FILE?.trim();
  return configured || path.join(process.cwd(), ".runtime", "hongxueban-state.json");
}

function isPersistedState(value: PersistedAppState): boolean {
  return value.version === STATE_VERSION
    && Array.isArray(value.profiles)
    && Array.isArray(value.courseGroups)
    && Array.isArray(value.plans)
    && Array.isArray(value.generatedQuizzes)
    && Array.isArray(value.uploadedKnowledge)
    && Array.isArray(value.quizResults)
    && Array.isArray(value.conversations)
    && Array.isArray(value.activityLog);
}

export function loadPersistedState(): PersistedAppState | undefined {
  if (!isAppStatePersistenceEnabled()) return undefined;

  try {
    const raw = readFileSync(stateFilePath(), "utf8");
    const parsed = JSON.parse(raw) as PersistedAppState;
    return isPersistedState(parsed) ? parsed : undefined;
  } catch {
    return undefined;
  }
}

export function savePersistedState(state: Omit<PersistedAppState, "version">): void {
  if (!isAppStatePersistenceEnabled()) return;

  try {
    const filePath = stateFilePath();
    mkdirSync(path.dirname(filePath), { recursive: true });
    const temporaryPath = `${filePath}.tmp`;
    const payload: PersistedAppState = { version: STATE_VERSION, ...state };
    writeFileSync(temporaryPath, JSON.stringify(payload, null, 2), "utf8");
    renameSync(temporaryPath, filePath);
  } catch (error) {
    console.error(
      "[store/persistence] save failed:",
      error instanceof Error ? error.message : String(error)
    );
  }
}
