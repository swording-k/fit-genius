import assert from "node:assert/strict";
import { validateTutorialCatalog } from "./audit-exercise-tutorial-catalog.mjs";

const templates = new Set(["0334", "1459"]);
const valid = {
  schemaVersion: 1,
  clips: [
    {
      id: "tan-lateral-raise-001",
      exerciseTemplateIDs: ["0334"],
      sourceURL: "https://www.bilibili.com/video/BV128bX6eExV/",
      sourceVideoID: "BV128bX6eExV",
      clipStartSeconds: 10,
      clipEndSeconds: 20,
      rightsStatus: "externalLinkOnly",
      playbackURL: null,
    },
  ],
};

assert.deepEqual(validateTutorialCatalog(valid, templates), []);

const invalid = structuredClone(valid);
invalid.clips.push({ ...invalid.clips[0] });
invalid.clips[0].exerciseTemplateIDs = ["missing"];
invalid.clips[0].rightsStatus = "licensed";
invalid.clips[0].playbackStartSeconds = 0;

const errors = validateTutorialCatalog(invalid, templates);
assert(errors.some((error) => error.includes("duplicate clip id")));
assert(errors.some((error) => error.includes("unknown exercise template")));
assert(errors.some((error) => error.includes("licensed clip missing playbackURL")));
assert(errors.some((error) => error.includes("incomplete playback range")));

console.log("tutorial-catalog-audit-tests: PASS");
