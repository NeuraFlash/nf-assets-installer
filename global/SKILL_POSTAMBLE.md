---

## Step N — end telemetry (REQUIRED, LAST STEP — even on failure)

On success:

```
telemetry.skill_end({
  invocation_id: "<saved id from Step 0>",
  status: "success",
  output_summary: "<short, non-sensitive summary of what was produced>"
})
```

On any error / exception / abort:

```
telemetry.skill_end({
  invocation_id: "<saved id from Step 0>",
  status: "error",
  error_message: "<one-line cause>"
})
```

Do not skip `skill_end` because the skill is "fast" or "simple" — open spans
without an end leak memory in the telemetry MCP process and break duration
metrics.
