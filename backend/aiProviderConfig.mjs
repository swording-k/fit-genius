const MINIMAX_DEFAULT_ENDPOINT = "https://api.minimaxi.com/v1/chat/completions";
const MINIMAX_DEFAULT_MODEL = "MiniMax-M3";
const ALIYUN_DEFAULT_ENDPOINT = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions";
const ALIYUN_DEFAULT_TEXT_MODEL = "qwen3-omni-flash";
const ALIYUN_DEFAULT_VISION_MODEL = "qwen-vl-max";

export function resolveAIProviderConfig(env = process.env) {
  const provider = String(env.AI_PROVIDER || "aliyun").trim().toLowerCase();

  if (provider === "minimax") {
    return {
      id: "minimax",
      apiKey: env.MINIMAX_API_KEY || "",
      endpoint: env.MINIMAX_ENDPOINT || MINIMAX_DEFAULT_ENDPOINT,
      defaultModel: env.MINIMAX_MODEL || MINIMAX_DEFAULT_MODEL,
      reasoningSplit: true
    };
  }

  if (provider === "aliyun") {
    return {
      id: "aliyun",
      apiKey: env.ALIYUN_API_KEY || "",
      endpoint: env.ALIYUN_ENDPOINT || ALIYUN_DEFAULT_ENDPOINT,
      defaultModel: env.ALIYUN_TEXT_MODEL || ALIYUN_DEFAULT_TEXT_MODEL,
      visionModel: env.ALIYUN_VISION_MODEL || ALIYUN_DEFAULT_VISION_MODEL,
      reasoningSplit: false
    };
  }

  throw new Error(`Unsupported AI provider: ${provider}`);
}

export function resolveUpstreamModel(requestedModel, config) {
  if (config.id === "minimax") {
    return config.defaultModel;
  }

  const requested = String(requestedModel || "").trim();
  const textAliases = new Set([
    "",
    "fitgenius-text",
    "qwen3-omni-flash"
  ]);
  const visionAliases = new Set([
    "fitgenius-vision",
    "fitgenius-video",
    "qwen-vl-max"
  ]);

  if (textAliases.has(requested)) return config.defaultModel;
  if (visionAliases.has(requested)) return config.visionModel;
  return config.defaultModel;
}
