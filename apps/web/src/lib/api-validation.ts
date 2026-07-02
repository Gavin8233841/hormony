import type { LearningProfileSnapshot } from "@/lib/types";
import { isJsonObject } from "@/lib/request-json";

export type ValidationResult<T> =
  | { ok: true; value: T }
  | { ok: false; response: Response };

export function validationError(
  error: string,
  code: string,
  status = 400
): ValidationResult<never> {
  return {
    ok: false,
    response: Response.json({ error, code }, { status }),
  };
}

export function readBoundedInteger(
  value: unknown,
  defaultValue: number,
  min: number,
  max: number,
  code: string,
  label: string
): ValidationResult<number> {
  if (value === undefined) return { ok: true, value: defaultValue };
  if (typeof value !== "number" || !Number.isFinite(value) || !Number.isInteger(value)) {
    return validationError(`${label} 必须是整数`, code);
  }
  if (value < min || value > max) {
    return validationError(`${label} 必须在 ${min}-${max} 之间`, code);
  }
  return { ok: true, value };
}

export function sanitizeLearningProfile(
  profile: unknown
): ValidationResult<LearningProfileSnapshot | undefined> {
  if (profile === undefined) return { ok: true, value: undefined };
  if (!isJsonObject(profile)) {
    return validationError("profile 必须是对象", "INVALID_PROFILE");
  }

  const stage = readOptionalString(profile, "stage", 40, "profile.stage");
  if (!stage.ok) return stage;
  const learningStyle = readOptionalString(
    profile,
    "learningStyle",
    40,
    "profile.learningStyle"
  );
  if (!learningStyle.ok) return learningStyle;
  const weakTopics = readOptionalStringArray(profile.weakTopics, "profile.weakTopics", 10, 40);
  if (!weakTopics.ok) return weakTopics;
  const strongTopics = readOptionalStringArray(
    profile.strongTopics,
    "profile.strongTopics",
    10,
    40
  );
  if (!strongTopics.ok) return strongTopics;
  const stats = sanitizeProfileStats(profile.stats);
  if (!stats.ok) return stats;

  return {
    ok: true,
    value: {
      stage: stage.value,
      weakTopics: weakTopics.value,
      strongTopics: strongTopics.value,
      learningStyle: learningStyle.value,
      stats: stats.value,
    },
  };
}

function readOptionalString(
  source: Record<string, unknown>,
  key: string,
  maxLength: number,
  label: string
): ValidationResult<string> {
  const value = source[key];
  if (value === undefined) return { ok: true, value: "" };
  if (typeof value !== "string") {
    return validationError(`${label} 必须是字符串`, "INVALID_PROFILE");
  }
  return { ok: true, value: value.trim().slice(0, maxLength) };
}

function readOptionalStringArray(
  value: unknown,
  label: string,
  maxItems: number,
  maxLength: number
): ValidationResult<string[]> {
  if (value === undefined) return { ok: true, value: [] };
  if (!Array.isArray(value)) {
    return validationError(`${label} 必须是字符串数组`, "INVALID_PROFILE");
  }
  const items: string[] = [];
  for (const item of value.slice(0, maxItems)) {
    if (typeof item !== "string") {
      return validationError(`${label} 必须只包含字符串`, "INVALID_PROFILE");
    }
    const trimmed = item.trim();
    if (trimmed.length > 0) items.push(trimmed.slice(0, maxLength));
  }
  return { ok: true, value: items };
}

function sanitizeProfileStats(
  value: unknown
): ValidationResult<LearningProfileSnapshot["stats"]> {
  if (value === undefined) {
    return {
      ok: true,
      value: { totalQuestions: 0, accuracy: 0, studyDays: 0 },
    };
  }
  if (!isJsonObject(value)) {
    return validationError("profile.stats 必须是对象", "INVALID_PROFILE");
  }

  const totalQuestions = readOptionalNonNegativeNumber(
    value.totalQuestions,
    "profile.stats.totalQuestions"
  );
  if (!totalQuestions.ok) return totalQuestions;
  const accuracy = readOptionalRatio(value.accuracy, "profile.stats.accuracy");
  if (!accuracy.ok) return accuracy;
  const studyDays = readOptionalNonNegativeNumber(value.studyDays, "profile.stats.studyDays");
  if (!studyDays.ok) return studyDays;

  return {
    ok: true,
    value: {
      totalQuestions: totalQuestions.value,
      accuracy: accuracy.value,
      studyDays: studyDays.value,
    },
  };
}

function readOptionalNonNegativeNumber(
  value: unknown,
  label: string
): ValidationResult<number> {
  if (value === undefined) return { ok: true, value: 0 };
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    return validationError(`${label} 必须是非负数字`, "INVALID_PROFILE");
  }
  return { ok: true, value };
}

function readOptionalRatio(value: unknown, label: string): ValidationResult<number> {
  if (value === undefined) return { ok: true, value: 0 };
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > 1) {
    return validationError(`${label} 必须在 0-1 之间`, "INVALID_PROFILE");
  }
  return { ok: true, value };
}
