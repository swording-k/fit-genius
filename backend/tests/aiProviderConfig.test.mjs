import assert from "node:assert/strict";
import {
  resolveAIProviderConfig,
  resolveUpstreamModel
} from "../aiProviderConfig.mjs";

const minimax = resolveAIProviderConfig({
  AI_PROVIDER: "minimax",
  MINIMAX_API_KEY: "test-minimax-key"
});

assert.equal(minimax.id, "minimax");
assert.equal(minimax.apiKey, "test-minimax-key");
assert.equal(minimax.endpoint, "https://api.minimaxi.com/v1/chat/completions");
assert.equal(minimax.defaultModel, "MiniMax-M3");
assert.equal(minimax.reasoningSplit, true);

for (const alias of [
  undefined,
  "",
  "qwen3-omni-flash",
  "qwen-vl-max",
  "fitgenius-text",
  "fitgenius-vision",
  "fitgenius-video",
  "untrusted-client-model"
]) {
  assert.equal(
    resolveUpstreamModel(alias, minimax),
    "MiniMax-M3",
    `MiniMax should map ${String(alias)} to its configured model`
  );
}

const configuredMiniMax = resolveAIProviderConfig({
  AI_PROVIDER: "minimax",
  MINIMAX_API_KEY: "test-minimax-key",
  MINIMAX_ENDPOINT: "https://example.invalid/v1/chat/completions",
  MINIMAX_MODEL: "MiniMax-M2.7-highspeed"
});
assert.equal(configuredMiniMax.endpoint, "https://example.invalid/v1/chat/completions");
assert.equal(resolveUpstreamModel("qwen-vl-max", configuredMiniMax), "MiniMax-M2.7-highspeed");

const aliyun = resolveAIProviderConfig({
  AI_PROVIDER: "aliyun",
  ALIYUN_API_KEY: "test-aliyun-key"
});
assert.equal(aliyun.id, "aliyun");
assert.match(aliyun.endpoint, /dashscope\.aliyuncs\.com/);
assert.equal(aliyun.reasoningSplit, false);
assert.equal(resolveUpstreamModel("qwen-vl-max", aliyun), "qwen-vl-max");
assert.equal(resolveUpstreamModel("fitgenius-text", aliyun), "qwen3-omni-flash");
assert.equal(resolveUpstreamModel("fitgenius-vision", aliyun), "qwen-vl-max");

assert.throws(
  () => resolveAIProviderConfig({ AI_PROVIDER: "unsupported" }),
  /Unsupported AI provider/
);

console.log("aiProviderConfig tests passed");
