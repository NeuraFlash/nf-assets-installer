---
name: navigate-stories
description: "Use this skill when a Consultant needs to generate User Stories from a Solution Design Document (SDD). Triggers include: \"generate user stories\", \"create user stories from SDD\", \"build backlog\", \"create stories for JIRA\", \"generate stories from solution design\", \"build sprint backlog\", \"turn SDD into stories\", \"create epics and stories\", \"write acceptance criteria\", or any request to produce a user story backlog from design documents. This skill reads the SDD from the shared project context, generates a structured user story backlog grouped by Epic, outputs to Google Sheets or Excel for customer review and approval, then pushes approved stories to JIRA via the JIRA MCP when connected. Always trigger when Consultant + user stories + SDD or backlog are mentioned together."
compatibility: "mcp_google_drive: Google Drive (required — reads SDD; saves story spreadsheet) | mcp_jira: JIRA MCP (optional — pushes approved stories to JIRA board) | mcp_smartsheet: Smartsheet MCP (optional — alternative output to Smartsheet)"
---

## Step 0 — start telemetry (REQUIRED, FIRST STEP)

Before doing anything else, call:

```
telemetry.skill_start({
  skill_name: "navigate-stories",
  input_summary: "<short, non-sensitive summary of the user's request>"
})
```

**Save the returned `invocation_id`** — you will need it in Step N.

Do NOT proceed to the user's task if `skill_start` returns an error. Surface
the error and stop.

---

# Consultant Stories — SDD → User Story Backlog → JIRA

Produces a customer-ready User Story backlog from the approved Solution Design Document, structured for review and approval, then pushes to JIRA once sign-off is received.

| #   | Step                          | Output                                             |
| --- | ----------------------------- | -------------------------------------------------- |
| 1   | Read SDD from project context | `sdd_content` + `outline_json`                     |
| 2   | Generate User Story backlog   | Epics + Stories + Acceptance Criteria              |
| 3   | Output to spreadsheet         | Google Sheets or Excel (.xlsx)                     |
| 4   | Customer review & approval    | Approved / Needs Revision / Out of Scope per story |
| 5   | Push approved stories to JIRA | Epics → Stories → Sub-tasks in JIRA board          |

---

## Step 1 — Obtain the SDD

### Check shared project context first

Before asking the user, check if the SDD content or `outline_json` from the SA's `sa-discovery` run is already available in the current Claude project context.

- If SDD is in context → confirm: "I can see the SDD for [project name] is in our project context — shall I use that to generate stories?"
- If not in context → ask the user:

> "Please either:
>
> - **Give me the SDD file name** and I'll find it in Google Drive, OR
> - **Upload or paste** the SDD text directly."

### If searching Google Drive

```
tool: Google Drive → search_files
  query: name contains "[project name] Solution Design" and mimeType = 'application/vnd.google-apps.document'
```

- Search Shared Drives first, then My Drive
- If multiple results, list by name + last modified and ask user to confirm
- Once confirmed: `read_file_content` → store as `sdd_content`

### Also check for TDD

Ask: "Should I also pull in the Technical Design Document? It helps size stories more accurately."

- If yes → search and retrieve the same way; store as `tdd_content`
- If not available, proceed with SDD only

---

## Step 1b — Confirm Story Format

Ask the user:

> "How would you like the user stories formatted?
>
> - **Standard** — As a [role], I want [goal], so that [benefit]
> - **Gherkin** — Given [context], When [action], Then [outcome]
> - **Both** — Standard story + Gherkin acceptance criteria"

Default to **Both** if the user doesn't specify — standard story text with Gherkin acceptance criteria is the most JIRA-friendly format.

Also ask:

> "Where should I save the story backlog?
>
> - **Google Sheets** — saved to the project folder in Shared Drive
> - **Excel (.xlsx)** — downloaded as a file
> - **Smartsheet** — added to the project workspace"

---

## Step 2 — Parse SDD and Define Epics

Before generating individual stories, derive the Epic structure from the SDD.

### Epic definition rules

- One Epic per major functional area or workstream in the SDD
- Epic names should be short (3–5 words), action-oriented: "Case Management Setup", "CTI Integration", "Agent Workspace Configuration"
- Pull Epic names from SDD sections: Functional Requirements groups, Architecture components, or named workstreams
- Each Epic gets a sequential ID: `[PREFIX]-EP001`, `[PREFIX]-EP002`, etc.
- Use the same UID prefix as the project's PM artifacts (from project context or ask user)

### Present Epic list for confirmation

Before generating all stories, show the user the proposed Epic list:

> "Here are the Epics I've identified from the SDD. Confirm, add, or remove before I generate stories:
>
> EP001 — [Epic Name] ([N] estimated stories)
> EP002 — [Epic Name] ([N] estimated stories)
> ..."

Wait for confirmation before proceeding to Step 3.

---

## Step 3 — Generate User Stories

For each confirmed Epic, generate all associated User Stories.

### Story schema (one row per story in the spreadsheet)

| Column              | Description                                                                        |
| ------------------- | ---------------------------------------------------------------------------------- |
| **Story ID**        | Sequential: `[PREFIX]-US001`, `[PREFIX]-US002`, etc. across all Epics              |
| **Epic ID**         | Parent Epic: `[PREFIX]-EP001` etc.                                                 |
| **Epic Name**       | Full Epic label                                                                    |
| **Feature Area**    | Sub-grouping within the Epic (e.g., "Screen Pop", "Wrap Up Codes")                 |
| **User Story**      | As a [role], I want [goal], so that [benefit]                                      |
| **Gherkin / AC**    | Given/When/Then acceptance criteria (one scenario per line, `\n`-separated)        |
| **Story Points**    | Fibonacci estimate: 1, 2, 3, 5, 8, 13. Flag with ⚠️ if complexity is unclear       |
| **Priority**        | Must Have / Should Have / Could Have / Won't Have (MoSCoW)                         |
| **Sprint**          | Suggested sprint number based on dependencies and phase (leave blank if unknown)   |
| **Owner**           | Consultant / Developer / SA — whoever will implement                               |
| **Dependencies**    | Story IDs this story depends on (comma-separated)                                  |
| **SDD Reference**   | Section in SDD this story traces to (e.g., `§3.2`)                                 |
| **Status**          | Default: `Draft`                                                                   |
| **Customer Review** | Default: blank — customer fills in: `Approved` / `Needs Revision` / `Out of Scope` |
| **Revision Notes**  | Default: blank — customer fills in feedback                                        |
| **JIRA Key**        | Default: blank — populated after JIRA push in Step 5                               |

### Story generation rules

**Coverage:** Generate at minimum one story per functional requirement (FR) in the SDD. If a FR is too large to be a single story (estimate would be >8 points), split it.

**Role identification:** Extract user roles from the SDD (e.g., Agent, Supervisor, Admin, Customer, System). Use the most specific role for each story — never "user" generically.

**Acceptance criteria quality bar:**

- Every story must have at least 2 Gherkin scenarios: a happy path and one edge/error case
- Scenarios must be testable — no vague criteria like "system works correctly"
- Reference specific field names, values, or system behaviours from the SDD where possible

**Story point guidance:**
| Points | Complexity |
|---|---|
| 1 | Config change, single field, trivial setup |
| 2 | Simple screen / flow with no custom logic |
| 3 | Standard feature with moderate complexity |
| 5 | Custom logic, integration touch point, or multi-object |
| 8 | Complex feature with multiple integrations or dependencies |
| 13 | Epic-level complexity — should be split if possible |

**Flag gaps:** If a SDD section doesn't have enough detail to write acceptance criteria, add the story with a ⚠️ in the Gherkin/AC column: "⚠️ Insufficient SDD detail — needs discovery session before stories can be finalised."

### Spreadsheet tab structure

- **Tab 1: Summary** — Epic list with story count, total points, and MoSCoW breakdown
- **Tabs 2–N: One tab per Epic** — all stories for that Epic, full schema
- **Tab N+1: All Stories** — flat list of every story across all Epics (for JIRA import)

---

## Step 4 — Save Spreadsheet and Share for Customer Review

### Google Sheets path

```
tool: Google Drive → create_file
  title: "[CLIENT NAME] _ User Story Backlog v0.1 DRAFT"
  mimeType: application/vnd.google-apps.spreadsheet
  parents: [project folder ID from project context]
```

- Populate all tabs using the Sheets API or create via the `xlsx` skill and upload
- After creation, display the link:
  > "📋 Story backlog saved: [link] — share this with the customer for review."

### Excel path

- Use the `xlsx` skill to generate a formatted `.xlsx` file
- File name: `[CLIENT NAME] _ User Story Backlog v0.1 DRAFT.xlsx`
- Save to `/mnt/user-data/outputs/` and present for download
- Also upload to Google Drive project folder for team access:

```
tool: Google Drive → create_file
  title: "[CLIENT NAME] _ User Story Backlog v0.1 DRAFT.xlsx"
  parents: [project folder ID]
```

### Smartsheet path

Use the Smartsheet MCP to create a sheet in the project workspace:

```
tool: Smartsheet → create_sheet_in_folder
  folder_id: [project folder ID from project context]
  sheet:
    name: "[CLIENT NAME] _ User Story Backlog"
    columns: [Story ID, Epic ID, Epic Name, Feature Area, User Story,
              Gherkin/AC, Story Points, Priority, Sprint, Owner,
              Dependencies, SDD Reference, Status, Customer Review,
              Revision Notes, JIRA Key]
```

Then populate rows with `add_rows`.

### Customer review instructions

Tell the user:

> "Share the backlog with your customer stakeholders and ask them to fill in the **Customer Review** column for each story:
>
> - **Approved** — story is accepted as written
> - **Needs Revision** — story needs changes (add notes in Revision Notes column)
> - **Out of Scope** — story should not be in this engagement
>
> Once review is complete, come back and say 'stories are approved' and I'll push them to JIRA."

---

## Step 5 — Revision Pass (if needed)

When the customer returns reviewed stories, check if any are marked **Needs Revision**.

For each story marked `Needs Revision`:

- Read the customer's Revision Notes
- Rewrite the User Story and/or Gherkin AC based on the feedback
- Update Status to `Revised — Pending Re-review`
- Flag significant scope changes:
  > "⚠️ Story [ID] revision appears to expand scope beyond the SDD (§[ref]). This may require a Change Request. Flag for SA review."

Ask the user: "I've updated [N] stories. Should I share the revised version with the customer for a final sign-off, or proceed to JIRA push?"

---

## Step 6 — Push Approved Stories to JIRA

### Check JIRA MCP connection

```
tool: JIRA MCP → check connection / get projects
```

**If JIRA MCP is not connected:**

> "JIRA MCP isn't connected yet — I can't push stories directly. To connect it, go to **Settings → Connections → JIRA** and add your JIRA instance URL and credentials.
>
> In the meantime, the **All Stories** tab in the spreadsheet is formatted for a JIRA CSV import. You can import it manually via JIRA's **Issues → Import CSV** feature."
>
> Provide the CSV export steps and proceed to Step N.

**If connected — ask for project details:**

> "Which JIRA project should I push to? Give me the project key (e.g., `NF-DEMO`) and I'll confirm the board before pushing."

```
tool: JIRA MCP → get_project
  project_key: "[user-provided key]"
```

Confirm with user: "Found project: [name] — [N] Approved stories ready to push. Shall I proceed?"

### Push order: Epics first, then Stories, then Sub-tasks

**1. Create Epics**
For each Epic with at least one Approved story:

```
tool: JIRA MCP → create_issue
  project: [project key]
  issuetype: Epic
  summary: [Epic Name]
  description: "Auto-generated from NeuraFlash SDD — [SDD Reference]"
  labels: ["navigate-ai", "sa-discovery"]
```

Save returned `epic_key` (e.g., `NF-1`) — needed to link stories.

**2. Create Stories**
For each story with Status = `Approved`:

```
tool: JIRA MCP → create_issue
  project: [project key]
  issuetype: Story
  summary: [User Story text — truncated to 255 chars if needed]
  description: [Full User Story + Gherkin AC]
  epic_link: [epic_key from above]
  story_points: [Story Points value]
  priority: [mapped from MoSCoW: Must Have → High, Should Have → Medium, Could Have → Low]
  labels: ["navigate-ai", "sprint-[N]"]
```

Save returned `story_key` → write back to **JIRA Key** column in the spreadsheet.

**3. Create Sub-tasks (if TDD is available)**
If `tdd_content` was retrieved in Step 1 and contains component-level tasks for this story:

```
tool: JIRA MCP → create_issue
  project: [project key]
  issuetype: Sub-task
  parent: [story_key]
  summary: [Component task from TDD — e.g., "Create Apex trigger for Case auto-assignment"]
```

### MoSCoW → JIRA priority mapping

| MoSCoW      | JIRA Priority      |
| ----------- | ------------------ |
| Must Have   | High               |
| Should Have | Medium             |
| Could Have  | Low                |
| Won't Have  | Do not push — skip |

### After all stories are pushed

- Update the **JIRA Key** column in the spreadsheet for every pushed story
- Update **Status** column to `In JIRA`
- Save the updated spreadsheet back to Google Drive

---

## Step 7 — Summary Report

```
✅ User Story Backlog complete for [CLIENT NAME]

📋 Backlog: [spreadsheet link]
   Total stories:    [N]
   Approved:         [N] → pushed to JIRA
   Needs revision:   [N] → updated and re-shared
   Out of scope:     [N] → excluded
   ⚠️ Needs detail:  [N] → requires additional discovery

🎯 JIRA Board: [project URL]
   Epics created:    [N]
   Stories pushed:   [N]
   Sub-tasks:        [N]

⚠️ Stories needing SA attention before sprint planning:
   [List story IDs with ⚠️ flags]

Next step → Developer/Consultant: assign stories in JIRA and begin implementation
            with Claude Code + AgentForce Vibes (consultant-stories complete ✅)
```

---

## Authoring rules

- **Do not** put PII, secrets, or full file contents in `input_summary` /
  `output_summary` / `error_message`. The gateway hashes these fields, but you
  should still treat them as if they were public.
- **Do not** skip `skill_end` because the skill is "fast" or "simple" — open
  spans without an end leak memory in the MCP process and break duration
  metrics.
- **Do not** call `skill_start` more than once per invocation. If your skill
  delegates to subskills, those subskills run their own start/end pair.

## Authoring notes

- Always wait for Epic confirmation (Step 2) before generating stories — regenerating all stories after an Epic structure change is expensive
- Never push stories with Status = `Needs Revision`, `Out of Scope`, or `Draft` to JIRA — only `Approved`
- Stories marked `Won't Have` in MoSCoW are never pushed to JIRA regardless of customer approval status
- Write JIRA Key back to the spreadsheet immediately after each story is created — do not batch at the end in case of partial failure
- If JIRA push fails mid-batch, record the last successful story ID and offer to resume from that point
- ⚠️ stories (insufficient SDD detail) must appear in both the Step 7 summary and the spreadsheet — never silently omit them

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
