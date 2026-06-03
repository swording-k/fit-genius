export function buildInsertFormAnalysisSQL({ userId, payload }) {
  return {
    text: `
      insert into form_analysis_records (
        user_id,
        schema_version,
        local_identifier,
        analyzed_at,
        exercise_name,
        exercise_type,
        video_duration,
        source_platform,
        score,
        issues,
        metrics,
        recommendation
      )
      values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, $11::jsonb, $12)
      on conflict (user_id, local_identifier)
      do update set
        analyzed_at = excluded.analyzed_at,
        exercise_name = excluded.exercise_name,
        exercise_type = excluded.exercise_type,
        video_duration = excluded.video_duration,
        source_platform = excluded.source_platform,
        score = excluded.score,
        issues = excluded.issues,
        metrics = excluded.metrics,
        recommendation = excluded.recommendation,
        updated_at = now()
      returning id, local_identifier, updated_at;
    `,
    values: [
      userId,
      payload.schemaVersion,
      payload.localIdentifier,
      payload.analyzedAt,
      payload.exerciseName,
      payload.exerciseType,
      payload.videoDuration,
      payload.sourcePlatform,
      payload.score,
      JSON.stringify(payload.issues),
      JSON.stringify(payload.metrics),
      payload.recommendation
    ]
  };
}
