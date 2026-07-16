import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const fsMock = vi.hoisted(() => ({
  mkdirSync: vi.fn(),
  readFileSync: vi.fn(),
  renameSync: vi.fn(),
  writeFileSync: vi.fn(),
}));

vi.mock("node:fs", () => fsMock);

import {
  isAppStatePersistenceEnabled,
  loadPersistedState,
  savePersistedState,
} from "./persistence";

const originalDeploymentMode = process.env.DEPLOYMENT_MODE;
const originalPersistenceMode = process.env.APP_STATE_PERSISTENCE;

const emptyState = {
  profiles: [],
  courseGroups: [],
  plans: [],
  generatedQuizzes: [],
  uploadedKnowledge: [],
  quizResults: [],
  conversations: [],
  activityLog: [],
};

beforeEach(() => {
  delete process.env.DEPLOYMENT_MODE;
  delete process.env.APP_STATE_PERSISTENCE;
  vi.clearAllMocks();
});

afterEach(() => {
  vi.unstubAllEnvs();
  if (originalDeploymentMode === undefined) delete process.env.DEPLOYMENT_MODE;
  else process.env.DEPLOYMENT_MODE = originalDeploymentMode;

  if (originalPersistenceMode === undefined) delete process.env.APP_STATE_PERSISTENCE;
  else process.env.APP_STATE_PERSISTENCE = originalPersistenceMode;
});

describe("app state persistence boundary", () => {
  it("does not read or write files by default", () => {
    expect(isAppStatePersistenceEnabled()).toBe(false);
    expect(loadPersistedState()).toBeUndefined();
    savePersistedState(emptyState);

    expect(fsMock.readFileSync).not.toHaveBeenCalled();
    expect(fsMock.mkdirSync).not.toHaveBeenCalled();
    expect(fsMock.writeFileSync).not.toHaveBeenCalled();
    expect(fsMock.renameSync).not.toHaveBeenCalled();
  });

  it("forces file persistence off by default in production", () => {
    vi.stubEnv("NODE_ENV", "production");
    delete process.env.DEPLOYMENT_MODE;
    process.env.APP_STATE_PERSISTENCE = "on";

    expect(isAppStatePersistenceEnabled()).toBe(false);
    expect(loadPersistedState()).toBeUndefined();
    savePersistedState(emptyState);

    expect(fsMock.readFileSync).not.toHaveBeenCalled();
    expect(fsMock.mkdirSync).not.toHaveBeenCalled();
    expect(fsMock.writeFileSync).not.toHaveBeenCalled();
    expect(fsMock.renameSync).not.toHaveBeenCalled();
  });

  it("allows explicit file persistence outside stateless deployment", () => {
    process.env.DEPLOYMENT_MODE = "development";
    process.env.APP_STATE_PERSISTENCE = "on";

    expect(isAppStatePersistenceEnabled()).toBe(true);
  });

  it("forces file persistence off in stateless deployment", () => {
    process.env.DEPLOYMENT_MODE = "stateless";
    process.env.APP_STATE_PERSISTENCE = "on";

    expect(isAppStatePersistenceEnabled()).toBe(false);
    expect(loadPersistedState()).toBeUndefined();
    savePersistedState(emptyState);

    expect(fsMock.readFileSync).not.toHaveBeenCalled();
    expect(fsMock.mkdirSync).not.toHaveBeenCalled();
    expect(fsMock.writeFileSync).not.toHaveBeenCalled();
    expect(fsMock.renameSync).not.toHaveBeenCalled();
  });

  it("keeps unrecognized persistence values disabled", () => {
    process.env.APP_STATE_PERSISTENCE = "enabled";

    expect(isAppStatePersistenceEnabled()).toBe(false);
  });
});
