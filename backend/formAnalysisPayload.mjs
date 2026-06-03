const allowedExerciseTypes = new Set(["squat", "deadlift", "bench_press"]);
const allowedSourcePlatforms = new Set(["ios", "watchos", "android", "huawei"]);

export function validateFormAnalysisPayload(payload) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return invalid("payload must be an object");
  }
  if (payload.schemaVersion !== 1) {
    return invalid("schemaVersion must be 1");
  }
  if (!isNonEmptyString(payload.localIdentifier)) {
    return invalid("localIdentifier is required");
  }
  if (!isIsoDate(payload.analyzedAt)) {
    return invalid("analyzedAt must be an ISO date string");
  }
  if (!isNonEmptyString(payload.exerciseName)) {
    return invalid("exerciseName is required");
  }
  if (!allowedExerciseTypes.has(payload.exerciseType)) {
    return invalid("exerciseType must be one of squat, deadlift, bench_press");
  }
  if (!Number.isInteger(payload.score) || payload.score < 0 || payload.score > 100) {
    return invalid("score must be an integer from 0 to 100");
  }
  if (!Array.isArray(payload.issues) || !payload.issues.every(isIssue)) {
    return invalid("issues must contain code, title, detail, and severity");
  }
  if (!Array.isArray(payload.metrics) || !payload.metrics.every(isMetric)) {
    return invalid("metrics must contain key, label, numeric value, and unit");
  }
  if (!isNonEmptyString(payload.recommendation)) {
    return invalid("recommendation is required");
  }
  if (!Number.isFinite(payload.videoDuration) || payload.videoDuration < 0) {
    return invalid("videoDuration must be a positive number");
  }
  if (!allowedSourcePlatforms.has(payload.sourcePlatform)) {
    return invalid("sourcePlatform must be ios, watchos, android, or huawei");
  }

  return { ok: true };
}

function invalid(error) {
  return { ok: false, error };
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoDate(value) {
  return isNonEmptyString(value) && !Number.isNaN(Date.parse(value));
}

function isIssue(issue) {
  return issue
    && isNonEmptyString(issue.code)
    && isNonEmptyString(issue.title)
    && isNonEmptyString(issue.detail)
    && Number.isInteger(issue.severity)
    && issue.severity >= 0
    && issue.severity <= 5;
}

function isMetric(metric) {
  return metric
    && isNonEmptyString(metric.key)
    && isNonEmptyString(metric.label)
    && Number.isFinite(metric.value)
    && isNonEmptyString(metric.unit);
}
