export function buildUpsertCloudSnapshotSQL({ userId, payload }) {
  return {
    text: `
      insert into cloud_snapshots (user_id, schema_version, snapshot)
      values ($1, $2, $3::jsonb)
      on conflict (user_id) do update set
        schema_version = excluded.schema_version,
        snapshot = excluded.snapshot,
        updated_at = now()
      returning schema_version, snapshot, updated_at;
    `,
    values: [userId, payload.schemaVersion, JSON.stringify(payload)]
  };
}

export function buildGetCloudSnapshotSQL({ userId }) {
  return {
    text: `
      select schema_version, snapshot, updated_at
      from cloud_snapshots
      where user_id = $1;
    `,
    values: [userId]
  };
}

export function buildEnsureCloudSnapshotSchemaSQL() {
  return {
    text: `
      create table if not exists cloud_snapshots (
        user_id text primary key references users(id) on delete cascade,
        schema_version integer not null,
        snapshot jsonb not null,
        created_at timestamptz not null default now(),
        updated_at timestamptz not null default now()
      );
    `,
    values: []
  };
}
