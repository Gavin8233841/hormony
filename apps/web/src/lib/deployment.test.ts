import { readFileSync } from "node:fs";
import { afterEach, describe, expect, it, vi } from "vitest";

import { getDeploymentMode, isStatelessDeployment } from "./deployment";

const originalDeploymentMode = process.env.DEPLOYMENT_MODE;

afterEach(() => {
  vi.unstubAllEnvs();
  if (originalDeploymentMode === undefined) delete process.env.DEPLOYMENT_MODE;
  else process.env.DEPLOYMENT_MODE = originalDeploymentMode;
});

describe("deployment mode", () => {
  it("defaults to development when DEPLOYMENT_MODE is absent", () => {
    vi.stubEnv("NODE_ENV", "development");
    delete process.env.DEPLOYMENT_MODE;

    expect(getDeploymentMode()).toBe("development");
    expect(isStatelessDeployment()).toBe(false);
  });

  it("recognizes the documented stateless mode after trimming whitespace", () => {
    vi.stubEnv("NODE_ENV", "development");
    process.env.DEPLOYMENT_MODE = " stateless ";

    expect(getDeploymentMode()).toBe("stateless");
    expect(isStatelessDeployment()).toBe(true);
  });

  it("keeps explicit development mode available outside production", () => {
    vi.stubEnv("NODE_ENV", "development");
    process.env.DEPLOYMENT_MODE = "development";

    expect(getDeploymentMode()).toBe("development");
    expect(isStatelessDeployment()).toBe(false);
  });

  it.each([undefined, "development", "stateles"])(
    "forces production into stateless mode when DEPLOYMENT_MODE is %s",
    (deploymentMode) => {
      vi.stubEnv("NODE_ENV", "production");
      if (deploymentMode === undefined) delete process.env.DEPLOYMENT_MODE;
      else process.env.DEPLOYMENT_MODE = deploymentMode;

      expect(getDeploymentMode()).toBe("stateless");
      expect(isStatelessDeployment()).toBe(true);
    }
  );

  it("keeps the Docker runtime aligned with the stateless contract", () => {
    const dockerfile = readFileSync(new URL("../../Dockerfile", import.meta.url), "utf8");

    expect(dockerfile).toContain("DEPLOYMENT_MODE=stateless");
    expect(dockerfile).toContain("APP_STATE_PERSISTENCE=off");
    expect(dockerfile).not.toContain("APP_STATE_FILE=");
    expect(dockerfile).not.toContain("VOLUME [\"/data\"]");
  });
});
