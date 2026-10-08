import assert from 'node:assert/strict';
import fs from 'node:fs';
const auth = fs.readFileSync('FitGenius/ViewModels/AuthViewModel.swift', 'utf8');
const cleanerPath = 'FitGenius/Services/LocalAccountDataCleaner.swift';
const cleanup = fs.existsSync(cleanerPath) ? fs.readFileSync(cleanerPath, 'utf8') : auth;
for (const model of ['HealthDailySummary', 'DailyReadinessReportRecord', 'WeeklyHealthReportRecord', 'HealthInsightPreference']) {
  assert.ok(cleanup.includes(`${model}.self`), `account deletion must delete ${model}`);
}
const deletion = auth.slice(auth.indexOf('func deleteAccount('), auth.indexOf('// 检查Apple ID'));
assert.ok(deletion.includes('LocalAccountDataCleaner.deleteAccount'), 'deletion must use tested ordered cleanup');
assert.ok(!deletion.includes('try?'), 'deletion must not swallow persistence failures');
assert.ok(deletion.includes('suspendForAccountDeletion'), 'deletion must suspend in-flight sync');
console.log('Account deletion integration regressions passed');
