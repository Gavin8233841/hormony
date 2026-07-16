import { readFileSync } from "node:fs";
import { afterEach, describe, expect, it } from "vitest";

import { getDeploymentMode, isStatelessDeployment } from "./deployment";

const originalDeploymentMode = process.env.DEPLOYMENT_MODE;

afterEach(() => {
  if (originalDeploymentMode === undefined) delete process.env.DEPLOYMENT_MODE;
  else process.env.DEPLOYMENT_MODE = originalDeploymentMode;
});

describe("deployment mode", () => {
  it("defaults to development when DEPLOYMENT_MODE is absent", () => {
    delete process.env.DEPLOYMENT_MODE;

    expect(getDeploymentMode()).toBe("development");
    expect(isStatelessDeployment()).toBe(false);
  });

  it("recognizes the documented stateless mode after trimming whitespace", () => {
    process.env.DEPLOYMENT_MODE = " stateless ";

    expect(getDeploymentMode()).toBe("stateless");
    expect(isStatelessDeployment()).toBe(true);
  });

  it("keeps other deployment modes out of the stateless branch", () => {
    process.env.DEPLOYMENT_MODE = "development";

    expect(getDeploymentMode()).toBe("development");
    expect(isStatelessDeployment()).toBe(false);
  });

  it("keeps the Docker runtime aligned with the stateless contract", () => {
    const dockerfile = readFileSync(new URL("../../Dockerfile", import.meta.url), "utf8");

    expect(dockerfile).toContain("DEPLOYMENT_MODE=stateless");
    expect(dockerfile).toContain("APP_STATE_PERSISTENCE=off");
    expect(dockerfile).not.toContain("APP_STATE_FILE=");
    expect(dockerfile).not.toContain("VOLUME [\"/data\"]");
  });
});
