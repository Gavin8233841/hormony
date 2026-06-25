// 测试对话接口（正确 UTF-8 编码）
const res = await fetch("http://localhost:3001/api/chat", {
  method: "POST",
  headers: { "Content-Type": "application/json; charset=utf-8" },
  body: JSON.stringify({ userId: "demo", message: "二叉搜索树" }),
});
const reader = res.body.getReader();
const decoder = new TextDecoder();
let all = "";
while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  all += decoder.decode(value, { stream: true });
}
const lines = all.split("\n\n");
for (const line of lines) {
  const data = line.replace(/^data: /, "").trim();
  if (!data) continue;
  const evt = JSON.parse(data);
  if (evt.type === "trace" && evt.agent === "Retrieval") console.log("Retrieval:", evt.content.slice(0, 120));
  if (evt.type === "citation") console.log("Citation:", JSON.stringify(evt.source));
  if (evt.type === "delta") console.log("Delta:", evt.content.slice(0, 100));
}
