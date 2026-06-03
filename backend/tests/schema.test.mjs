import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const schema = readFileSync(new URL("../schema.sql", import.meta.url), "utf8");

assert.match(schema, /create extension if not exists pgcrypto/i);
assert.match(schema, /create table if not exists users/i);
assert.match(schema, /email text/i);
assert.match(schema, /id uuid primary key default gen_random_uuid\(\)/i);
assert.match(schema, /unique \(user_id, local_identifier\)/i);

console.log("schema tests passed");
