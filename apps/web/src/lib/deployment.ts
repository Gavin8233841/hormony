const DEVELOPMENT_DEPLOYMENT_MODE = "development";
const STATELESS_DEPLOYMENT_MODE = "stateless";

export type DeploymentMode =
  | typeof DEVELOPMENT_DEPLOYMENT_MODE
  | typeof STATELESS_DEPLOYMENT_MODE;

export function getDeploymentMode(): DeploymentMode {
  if (process.env.NODE_ENV === "production") {
    return STATELESS_DEPLOYMENT_MODE;
  }

  return process.env.DEPLOYMENT_MODE?.trim() === STATELESS_DEPLOYMENT_MODE
    ? STATELESS_DEPLOYMENT_MODE
    : DEVELOPMENT_DEPLOYMENT_MODE;
}

export function isStatelessDeployment(): boolean {
  return getDeploymentMode() === STATELESS_DEPLOYMENT_MODE;
}
