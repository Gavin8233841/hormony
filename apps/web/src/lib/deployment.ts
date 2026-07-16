const DEFAULT_DEPLOYMENT_MODE = "development";
const STATELESS_DEPLOYMENT_MODE = "stateless";

export function getDeploymentMode(): string {
  return process.env.DEPLOYMENT_MODE?.trim() || DEFAULT_DEPLOYMENT_MODE;
}

export function isStatelessDeployment(): boolean {
  return getDeploymentMode() === STATELESS_DEPLOYMENT_MODE;
}
