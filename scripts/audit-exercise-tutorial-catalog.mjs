import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

export function validateTutorialCatalog(document, templateIDs) {
  const errors = [];
  if (document?.schemaVersion !== 1) {
    errors.push(`unsupported schemaVersion: ${document?.schemaVersion}`);
  }

  const clips = Array.isArray(document?.clips) ? document.clips : [];
  const seenIDs = new Set();

  for (const clip of clips) {
    const label = clip?.id || "<missing-id>";
    if (!clip?.id) {
      errors.push("clip missing id");
    } else if (seenIDs.has(clip.id)) {
      errors.push(`duplicate clip id: ${clip.id}`);
    } else {
      seenIDs.add(clip.id);
    }

    if (!Array.isArray(clip?.exerciseTemplateIDs) || clip.exerciseTemplateIDs.length === 0) {
      errors.push(`${label}: missing exerciseTemplateIDs`);
    } else {
      for (const templateID of clip.exerciseTemplateIDs) {
        if (!templateIDs.has(templateID)) {
          errors.push(`${label}: unknown exercise template ${templateID}`);
        }
      }
    }

    if (!clip?.sourceURL || !clip?.sourceVideoID) {
      errors.push(`${label}: missing source traceability`);
    }
    if (!(clip?.clipStartSeconds >= 0) || !(clip?.clipEndSeconds > clip?.clipStartSeconds)) {
      errors.push(`${label}: invalid clip time range`);
    }
    const hasPlaybackStart = clip?.playbackStartSeconds != null;
    const hasPlaybackEnd = clip?.playbackEndSeconds != null;
    if (hasPlaybackStart !== hasPlaybackEnd) {
      errors.push(`${label}: incomplete playback range`);
    } else if (
      hasPlaybackStart &&
      (!(clip.playbackStartSeconds >= 0) || !(clip.playbackEndSeconds > clip.playbackStartSeconds))
    ) {
      errors.push(`${label}: invalid playback range`);
    }
    if (clip?.rightsStatus === "licensed" && !clip?.playbackURL) {
      errors.push(`${label}: licensed clip missing playbackURL`);
    }
    if (!["developmentOnly", "licensed", "externalLinkOnly"].includes(clip?.rightsStatus)) {
      errors.push(`${label}: invalid rightsStatus ${clip?.rightsStatus}`);
    }
  }

  return errors;
}

function runAudit() {
  const seedPath = path.join(projectRoot, "FitGenius/Resources/ExerciseLibrary/exercises_seed.json");
  const catalogPath = path.join(projectRoot, "FitGenius/Resources/ExerciseTutorials/tutorial_clips.json");
  const templates = JSON.parse(fs.readFileSync(seedPath, "utf8"));
  const document = JSON.parse(fs.readFileSync(catalogPath, "utf8"));
  const templateIDs = new Set(templates.map((template) => template.id));
  const errors = validateTutorialCatalog(document, templateIDs);

  if (errors.length > 0) {
    for (const error of errors) console.error(`ERROR: ${error}`);
    process.exitCode = 1;
    return;
  }

  const mappedTemplates = new Set(document.clips.flatMap((clip) => clip.exerciseTemplateIDs));
  const missingPlayback = document.clips.filter((clip) => !clip.playbackURL).length;
  console.log(
    `tutorial catalog audit: PASS (${document.clips.length} clips, ${mappedTemplates.size} templates, ${missingPlayback} without playback assets)`,
  );
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  runAudit();
}
