// 独立路径使旧部署对小艺端侧请求返回 404；新部署仍复用 /api/chat
// 的输入校验、Safety、超时和 SSE 边界。
export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const maxDuration = 120;
export { POST } from "../../chat/route";
