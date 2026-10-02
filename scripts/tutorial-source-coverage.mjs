import fs from 'node:fs';
import { validateTutorialCatalog } from './audit-exercise-tutorial-catalog.mjs';

const exercises = JSON.parse(fs.readFileSync('FitGenius/Resources/ExerciseLibrary/exercises_seed.json', 'utf8'));
const inventory = JSON.parse(fs.readFileSync('docs/tutorial-sources/douyin-tan.json', 'utf8'));
const published = JSON.parse(fs.readFileSync('cloud-content/exercise-tutorials/catalog-v1.json', 'utf8'));
const ids = new Set(exercises.map(x => x.id));
const catalogErrors = validateTutorialCatalog(published, ids);
if (catalogErrors.length) throw Error(catalogErrors.join('\n'));
const sources = new Set();
for (const source of inventory.sources) {
  if (!/^\d{19}$/.test(source.id) || sources.has(source.id)) throw Error(`Invalid/duplicate source ${source.id}`);
  sources.add(source.id);
  for (const id of source.candidateTemplateIDs) if (!ids.has(id)) throw Error(`Unknown template ${id}`);
}
for (const clip of published.clips) {
  if (!sources.has(clip.sourceVideoID)) throw Error(`Untracked source ${clip.sourceVideoID}`);
  for (const id of clip.exerciseTemplateIDs) if (!ids.has(id)) throw Error(`Unknown published template ${id}`);
}
const coverage = exercises.map(exercise => ({
  templateID: exercise.id,
  name: exercise.name,
  candidateSourceIDs: inventory.sources.filter(s => s.candidateTemplateIDs.includes(exercise.id)).map(s => s.id),
  publishedClipIDs: published.clips.filter(c => c.exerciseTemplateIDs.includes(exercise.id)).map(c => c.id)
}));
if (process.argv.includes('--json')) console.log(JSON.stringify(coverage, null, 2));
else console.log(JSON.stringify({ totalExercises: exercises.length, verifiedProfileSources: sources.size,
  downloadedSources: inventory.sources.filter(s => s.downloaded).length,
  exercisesWithCandidates: coverage.filter(x => x.candidateSourceIDs.length).length,
  exercisesWithPublishedLinks: coverage.filter(x => x.publishedClipIDs.length).length,
  hostedDevelopmentClips: published.clips.filter(c => c.playbackURL && c.rightsStatus === 'developmentOnly').length,
  hostedLicensedClips: published.clips.filter(c => c.playbackURL && c.rightsStatus === 'licensed').length,
  unreviewedExercises: coverage.filter(x => !x.candidateSourceIDs.length).length,
  researchComplete: inventory.researchComplete }, null, 2));
