---
name: navigate-refine
description: "Use this skill when a Solution Architect needs to refresh the Solution Design Document (SDD) and Technical Design Document (TDD) AFTER discovery sessions have run — using the customer's filled-in discovery questionnaire and the discovery session transcript as inputs. Triggers include: \"update the SDD from discovery\", \"refine the design after discovery\", \"incorporate discovery responses into SDD/TDD\", \"post-discovery design refresh\", \"update SDD and TDD with discovery answers\", \"merge discovery transcript into the design docs\", \"version the SDD from the questionnaire responses\", \"reconcile design with discovery findings\". This skill reads the completed Discovery Questionnaire from the project Google Drive folder, locates the discovery session transcript (Google Drive first, Gmail second — asks the user if neither yields a clear match), then produces versioned updates of the SDD and TDD with a clear change log and a list of remaining open items. Always trigger when SA + post-discovery + SDD/TDD update are..."
compatibility: "mcp_google_drive: Google Drive (required — reads questionnaire/transcript, reads current SDD/TDD, writes updated DOCXs) | mcp_gmail: Gmail (optional but recommended — used to locate the discovery transcript when not in Drive) | mcp_salesforce: Salesforce MCP (optional — pulls opportunity/account context for TDD enrichment)"
---

## Step 0 — start telemetry (REQUIRED, FIRST STEP)

Before doing anything else, call:

```
telemetry.skill_start({
  skill_name: "navigate-refine",
  input_summary: "<short, non-sensitive summary of the user's request>"
})
```

**Save the returned `invocation_id`** — you will need it in Step N.

Do NOT proceed to the user's task if `skill_start` returns an error. Surface
the error and stop.

---

# SA Refine — Discovery Responses → Updated SDD + TDD

Takes the **filled-in Discovery Questionnaire** plus the **discovery session transcript** and
produces a new version of the **Solution Design Document (SDD)** and **Technical Design
Document (TDD)** that reflects the decisions, clarifications, and new gaps surfaced during
discovery.

| #   | Input                            | Source                                   |
| --- | -------------------------------- | ---------------------------------------- |
| 1   | Completed Discovery Questionnaire | Google Drive — project folder            |
| 2   | Discovery session transcript      | Google Drive **or** Gmail (ask if unsure)|
| 3   | Current SDD (v0.x)                | Google Drive — project folder            |
| 4   | Current TDD (v0.x)                | Google Drive — project folder            |

| #   | Output                           | Tool                                       |
| --- | -------------------------------- | ------------------------------------------ |
| 1   | Updated SDD (next minor version) | Claude-native edit → DOCX via `docx` skill |
| 2   | Updated TDD (next minor version) | Claude-native edit → DOCX via `docx` skill |
| 3   | Change log + open items report   | Markdown summary in chat                   |

> **Do not** overwrite the prior version. Always save the refreshed docs as a new minor
> version (e.g. `v0.1` → `v0.2`) in the same project folder. The prior version is the audit
> trail for what changed during discovery.

---

## Step 1 — Identify the project

Ask the user (or pull from current Claude project context):

> "Which project are we refining? I need the client/project name so I can locate the
> Google Drive folder, the current SDD, and the current TDD."

If the project context (folder ID, client name) is already in the Claude project from a prior
`navigate-plan` or `sa-discovery` run → confirm and use it. Do not re-ask.

Store:
- `project_name`
- `client_name`
- `project_folder_id` (Google Drive)

---

## Step 2 — Locate the completed Discovery Questionnaire

The questionnaire is expected in the project's Google Drive folder. Common file-name patterns:

- `[CLIENT] _ Discovery Questionnaire …`
- `[CLIENT] _ Discovery Session Plan …` (if responses were captured inline)
- Anything containing `discovery` AND `questionnaire` or `responses`

```
tool: Google Drive → search_files
  query: "'[project_folder_id]' in parents and (name contains 'Discovery Questionnaire' or name contains 'Discovery Responses')"
```

If multiple matches → list by name + last modified date and confirm with the user. Prefer
the most recently modified file unless the user picks otherwise.

If zero matches → ask:

> "I can't find a Discovery Questionnaire in the project folder. Can you (a) point me to
> the file, (b) paste the responses, or (c) confirm there is no completed questionnaire
> yet — in which case I'll work from the transcript only?"

Once located → `read_file_content` → store as `questionnaire_text`.

**Do NOT** assume question/answer ordering — preserve the structure exactly as written in
the document. Many questionnaires are organised by workstream; map each Q/A pair to its
workstream so it can be cross-referenced into the SDD section it belongs to.

---

## Step 3 — Locate the Discovery Session Transcript

Transcripts can live in **Google Drive** (uploaded notes, Gemini/Otter export, Granola export,
Read.ai export) **or in Gmail** (auto-generated meeting recap emails, "Notetaker AI" delivery,
internal handoff emails). Try Drive first, then Gmail, then ask.

### 3a. Try Google Drive first

```
tool: Google Drive → search_files
  query: "'[project_folder_id]' in parents and (name contains 'Transcript' or name contains 'Recap' or name contains 'Discovery Session' or name contains 'Notes')"
```

Also search the project folder for any recently modified `.docx`, Google Doc, or `.txt` that
post-dates the questionnaire's last-modified timestamp — those are likely transcripts.

### 3b. If not in Drive, try Gmail

If the Gmail MCP is available:

```
tool: Gmail → search
  query: "subject:('[client_name]' OR '[project_name]') (transcript OR recap OR 'meeting notes' OR 'session notes' OR 'discovery')"
  newer_than: 30d
```

Other useful queries to try in order:

- `from:(otter.ai OR fireflies.ai OR read.ai OR fathom.video OR notetaker) [client_name]`
- `subject:'Discovery' [client_name]`

For matches → extract the email body (and any attached transcript file if present).

### 3c. If still nothing, ask

> "I couldn't locate the discovery session transcript automatically. Where should I look?
>
> - **Google Drive** — give me a file name or paste a link
> - **Gmail** — give me a sender, subject, or rough date and I'll search again
> - **Paste it** — drop the transcript text directly into chat
>
> If there is no transcript at all, say so and I'll proceed using only the questionnaire."

Once located → store as `transcript_text`.

**Do NOT** mix `questionnaire_text` and `transcript_text` into a single blob. Keep them
separate so the change log can cite the source for each update.

---

## Step 4 — Locate the current SDD and TDD

```
tool: Google Drive → search_files
  query: "'[project_folder_id]' in parents and (name contains 'Solution Design Document' or name contains 'SDD')"

tool: Google Drive → search_files
  query: "'[project_folder_id]' in parents and (name contains 'Technical Design Document' or name contains 'TDD')"
```

For each:

- If multiple versions exist → pick the **latest version** (highest `vX.Y`, or most recently
  modified if version not in filename). Confirm with the user before proceeding.
- `read_file_content` → store as `sdd_text` and `tdd_text`.
- Note the current version number for each (e.g. `v0.1 DRAFT`) — you will bump the minor
  version for the new file.

If either document is missing → stop and tell the user:

> "I can't find the current [SDD/TDD] in the project folder. This skill refreshes existing
> design docs — it doesn't create them from scratch. If you need an initial SDD/TDD, run
> `sa-discovery` instead. Otherwise, point me to the right file."

---

## Step 5 — Reconcile inputs against the current design

For each section of the SDD and TDD, walk through the questionnaire responses and transcript
and classify findings into one of four buckets. **Maintain a working change log table** as
you go — it becomes the Step 7 summary.

| Bucket          | Meaning                                                              | Action                                                  |
| --------------- | -------------------------------------------------------------------- | ------------------------------------------------------- |
| **CONFIRMED**   | Discovery confirms what the SDD/TDD already says                     | Mark assumption as confirmed; remove ⚠️ if previously flagged |
| **CHANGED**     | Discovery changed a decision, requirement, integration, data shape   | Update the section in place; cite the source            |
| **NEW**         | Discovery surfaced something not in the current SDD/TDD              | Add a new sub-section; flag if it implies a scope change |
| **STILL OPEN**  | Question remained unanswered; needs follow-up                        | Move to Open Items with owner + due date placeholder    |

### Change-log entry format

For each finding, record:

```
| Doc | Section | Bucket | Description | Source | Citation |
|-----|---------|--------|-------------|--------|----------|
| SDD | 5. Integrations | CHANGED | Salesforce ↔ NetSuite frequency moved from real-time to hourly batch | Transcript | "we decided hourly is fine for AR sync — Maria, 14:32" |
| TDD | 4. Data Model  | NEW     | New custom object `External_Quote__c` to capture pricing engine output | Questionnaire | Q3.4 response |
| SDD | 7. Assumptions | CONFIRMED | Single-org strategy confirmed (no multi-org rollout) | Questionnaire | Q1.2 response |
| SDD | OI-004        | STILL OPEN | SSO provider not confirmed — vendor decision pending IT | Transcript | "we'll come back to SSO after the security review" |
```

### Scope-change detection

If any **NEW** or **CHANGED** entry looks like it expands scope beyond the SOW:

- Tag it with `⚠️ POTENTIAL CR` (Change Request)
- Do NOT silently add it to the SDD body — call it out in a dedicated **Potential CRs**
  callout box at the top of the Executive Summary so the SA can route it to the PM/AE

---

## Step 6 — Produce updated SDD and TDD

### Versioning

- New version = bump the minor (e.g. `v0.1 DRAFT` → `v0.2 DRAFT`)
- If the prior version was `v1.0 FINAL` and discovery substantially changed it, bump to
  `v1.1 DRAFT` and add a "Reopened after discovery" note in the document header
- Update the date in the header
- Update the `Status:` line: `Status: Draft — Post-Discovery Refresh`

### Section edits

Apply each `CHANGED`, `NEW`, and `STILL OPEN` entry to the corresponding section. For each
edited paragraph or table row:

- Add an inline source citation in the format `[Disc Q3.4]` (questionnaire) or
  `[Disc Transcript: Maria @ 14:32]` (transcript) — small and unobtrusive, but traceable
- Where the prior text was wrong, replace it cleanly — do not leave both versions in place
- For `STILL OPEN` items, ensure each appears in the **Open Items** table with:
  `OI-NNN | Section | Description | Owner (TBD if unknown) | Due | Status: Open`

### Required new sections to add to each doc

Append a **"Change Log — Post-Discovery vX.Y"** section near the end of each document
(before any appendices). Reuse the change-log table from Step 5, filtered to just that
document.

### TDD-specific updates

The TDD has component-level detail the SDD does not — apply these specifically:

- **Component Design** table: add any new Apex classes, Flows, LWCs, integrations surfaced
- **Data Model**: add new fields/objects; mark any deprecated ones
- **Integration Design**: update each row's protocol/auth/frequency if changed
- **Test Strategy**: if new components → ensure each appears in the test scope
- **Open Items**: append new `TDD-OI` entries; close any resolved by discovery

### File output

Use the `docx` skill to render each updated document:

- `[CLIENT NAME] _ Solution Design Document v0.2 DRAFT.docx`
- `[CLIENT NAME] _ Technical Design Document v0.2 DRAFT.docx`

(Use whatever minor version is next from the prior file.)

---

## Step 7 — Save and summarise

### Save to Google Drive — same project folder

```
tool: Google Drive → create_file
  title: "[CLIENT NAME] _ Solution Design Document v0.2 DRAFT"
  parent: [project_folder_id]
  file:   [updated SDD DOCX]

tool: Google Drive → create_file
  title: "[CLIENT NAME] _ Technical Design Document v0.2 DRAFT"
  parent: [project_folder_id]
  file:   [updated TDD DOCX]
```

**Do not** delete or overwrite the prior `v0.1` (or whichever version preceded this run).
Both versions must coexist so the SA and the customer can diff them.

### Summary report (in chat)

```
✅ Design docs refreshed for [CLIENT NAME] from discovery inputs

📁 Saved to: [Project Folder] → [link]

  📐 Solution Design Document v0.2 DRAFT → [link]   (was v0.1)
  🛠️ Technical Design Document v0.2 DRAFT → [link]   (was v0.1)

Inputs ingested:
  • Discovery Questionnaire — [filename, last modified date]
  • Discovery Transcript     — [filename + source: Drive / Gmail / pasted]

Change summary:
  • CONFIRMED:  N items   (e.g. single-org strategy, AR sync ownership)
  • CHANGED:    N items   (e.g. NetSuite frequency, SSO target)
  • NEW:        N items   (e.g. External_Quote__c object, audit retention rule)
  • STILL OPEN: N items   (each carried into Open Items table)

⚠️ Potential Change Requests flagged:
  [List each NEW/CHANGED entry that looks out-of-SOW]

Next step → review the v0.2 docs with the SA team, then circulate to customer for sign-off.
```

---

## Authoring notes

- Always keep `questionnaire_text` and `transcript_text` as separate inputs — do not merge.
  Citations in the updated docs must point to a specific source.
- **Never paraphrase a customer quote from the transcript without a citation.** Direct quotes
  carry weight in design decisions; attribution matters when the customer later asks "why did
  we change this?"
- If the transcript appears to be a third-party export (Otter, Fireflies, etc.), strip any
  vendor-specific watermarks/footers before quoting.
- Bump version numbers conservatively — `v0.x` stays `v0.x` until the customer formally
  approves; that's when it becomes `v1.0 FINAL`. Post-discovery refresh = still draft.
- Treat anything that expands scope as a CR candidate first, an SDD edit second. Don't
  quietly absorb new scope into the design.
- This skill is a **refresh**, not an initial author. If either input doc (SDD or TDD) is
  missing, hand off to `sa-discovery` rather than improvising.

## Data handling reminders

- Do NOT paste questionnaire responses, transcript text, or customer names into
  `input_summary` / `output_summary` / `error_message`. The telemetry gateway hashes these
  fields but treat them as if they were public.
- If the transcript or questionnaire contains PII (employee names, customer contact details,
  credentials shared in passing) — preserve it in the design docs only where necessary for
  the design decision; otherwise summarise.

---

## Step N — end telemetry (REQUIRED, LAST STEP — even on failure)

On success:

```
telemetry.skill_end({
  invocation_id: "<saved id>",
  status: "success",
  output_summary: "<short, non-sensitive summary of what was produced>"
})
```

On any error / exception / abort:

```
telemetry.skill_end({
  invocation_id: "<saved id>",
  status: "error",
  error_message: "<one-line cause>"
})
```

## Authoring rules

- **Do not** put PII, secrets, or full file contents in `input_summary` /
  `output_summary` / `error_message`. The gateway hashes these fields, but you
  should still treat them as if they were public.
- **Do not** skip `skill_end` because the skill is "fast" or "simple" — open
  spans without an end leak memory in the MCP process and break duration
  metrics.
- **Do not** call `skill_start` more than once per invocation. If your skill
  delegates to subskills, those subskills run their own start/end pair.
