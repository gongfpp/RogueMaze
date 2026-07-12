import assert from "node:assert/strict";
import test from "node:test";

import {
  createBuildInfo,
  normalizeCommit,
  parseProjectVersion,
} from "../generate_build_info.mjs";

test("project version is read from the Godot application section", () => {
  assert.equal(parseProjectVersion('[application]\nconfig/version="0.4.0"\n'), "0.4.0");
});

test("commit normalization rejects values that cannot identify a revision", () => {
  assert.equal(normalizeCommit("ABCDEF123456\n"), "abcdef123456");
  assert.equal(normalizeCommit("not-a-commit"), "unknown");
});

test("build info is deterministic when its inputs are fixed", () => {
  assert.deepEqual(createBuildInfo({
    version: "0.4.0",
    commit: "383e92f23b237722abfaae70e10199fb404abb49",
    platform: "linux",
    configuration: "release",
    builtAtUtc: "2026-07-12T10:00:00Z",
    dirty: false,
  }), {
    schema_version: 1,
    version: "0.4.0",
    commit: "383e92f23b237722abfaae70e10199fb404abb49",
    commit_short: "383e92f",
    platform: "linux",
    configuration: "release",
    built_at_utc: "2026-07-12T10:00:00.000Z",
    dirty: false,
  });
});

test("unsupported platform and configuration values fail loudly", () => {
  const base = {
    version: "0.4.0",
    commit: "383e92f",
    builtAtUtc: "2026-07-12T10:00:00Z",
  };
  assert.throws(() => createBuildInfo({ ...base, platform: "web" }), /Unsupported build platform/);
  assert.throws(
    () => createBuildInfo({ ...base, platform: "windows", configuration: "profile" }),
    /Unsupported build configuration/,
  );
});
