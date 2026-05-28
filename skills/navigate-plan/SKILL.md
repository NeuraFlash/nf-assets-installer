---
name: navigate-plan
description: "Use this skill whenever a user wants to generate project artifacts from a Statement of Work (SOW). Triggers include: \"create a project plan from SOW\", \"set up project from SOW\", \"I have an SOW and need project artifacts\", \"build project plan\", \"spin up project from SOW\", \"set up my project folder\", \"generate all project templates\", or any mention of uploading or searching for an SOW to kick off a project. This skill searches Shared Google Drives for the SOW by name OR accepts a direct upload, then creates a dedicated project folder and populates it with ALL SEVEN NeuraFlash project artifact sheets — in either Google Sheets or Smartsheet (user's choice). Always trigger this skill when SOW + project setup or project templates are mentioned together."
compatibility: "mcp_google_drive: Google Drive (https://drivemcp.googleapis.com/mcp/v1) | mcp_smartsheet: Smartsheet MCP (required only if user selects Smartsheet output)"
---

## Step 0 — start telemetry (REQUIRED, FIRST STEP)

Before doing anything else, call:

```
telemetry.skill_start({
  skill_name: "navigate-plan",
  input_summary: "<short, non-sensitive summary of the user's request>"
})
```

**Save the returned `invocation_id`** — you will need it in Step N.

Do NOT proceed to the user's task if `skill_start` returns an error. Surface
the error and stop.

---

# Navigate Plan — SOW → Project Artifacts Generator

Generates **seven NeuraFlash project artifact sheets** from a Statement of Work, saved into a dedicated project folder. Supports output to **Google Sheets** or **Smartsheet** — ask the user which they prefer.

| # | Artifact | Description |
|---|---|---|
| 1 | **Project Plan** | Phased task list (Engage → Execute → Evolve) with sequential UIDs |
| 2 | **RAID Log** | Pre-seeded Risks, Assumptions, Issues, and Decisions inferred from the SOW |
| 3 | **SOW Deliverables** | Full deliverable tracker pulled directly from the SOW |
| 4 | **Stakeholder Register** | Pre-populated from all named roles/contacts in the SOW |
| 5 | **Meeting Register** | Standard recurring meetings + any SOW-specified ceremonies |
| 6 | **GAP Analysis** | Change log seeded with open gaps inferred from the SOW |
| 7 | **Action Items** | Pre-loaded with standard kickoff actions |

---

## Step 1 — Obtain the SOW

Ask the user:

> "Please either:
> - **Upload** the SOW Google Doc (export as .docx or paste the text), OR
> - **Give me the name** of the SOW file and I'll search your Shared Google Drive for it."

### If searching Google Drive
Use the Google Drive MCP to search Shared Drives:
```
tool: Google Drive → search_files
query: name contains "[user-provided name]" and mimeType = 'application/vnd.google-apps.document'
```
- Search across **Shared Drives** (not just My Drive)
- If multiple results, show a numbered list and ask user to confirm which one
- Once confirmed, use `read_file_content` to extract the full text

### If uploaded
- Accept `.docx` upload → use `extract-text` to get the content
- Or accept pasted text directly

---

## Step 1b — Choose Output Platform

After the SOW is obtained, ask:

> "Where would you like the project artifacts created?
> - **Google Sheets** — saved in a new folder in your Shared Google Drive
> - **Smartsheet** — created as sheets in a new Smartsheet workspace/folder"

### Google Sheets path
- Requires: Google Drive MCP connected ✅
- Creates a project folder in Shared Drive, then creates all 6 sheets inside it
- See **Step 6a (Google Sheets)**

### Smartsheet path
- Requires: **Smartsheet MCP connected**
- If Smartsheet MCP is not currently connected, inform the user:
  > "To create in Smartsheet, you'll need to connect the Smartsheet integration first. You can do that in your Claude settings under Connections."
- Once confirmed connected, creates a Smartsheet workspace/folder named `[CLIENT NAME] — [PROJECT NAME]` and creates all 6 sheets inside it
- See **Step 6b (Smartsheet)**

---

## Step 2 — Extract Key SOW Fields

From the SOW text, extract and confirm the following. Flag any that are missing with ⚠️:

| Field | Where to Look |
|---|---|
| **Client Name** | Header, parties section, or "Client:" label |
| **Project Name / Type** | Title or scope summary |
| **Project Start Date** | Timeline or schedule section |
| **Project End Date** | Timeline or schedule section |
| **Total Duration (weeks)** | Calculated or stated |
| **Phases & Milestones** | Deliverables or timeline section |
| **Deliverables list** | Deliverables section (pull all) |
| **Named Roles / Team** | Team or RACI section |
| **SOW Section refs** | For RAID log citations |
| **Key Assumptions** | Assumptions section |
| **Dependencies** | Dependencies or prerequisites section |

### Derive the UID Prefix
- Take the **client name** → extract first 4 uppercase letters → use as prefix
- Examples: "Lytx" → `LYTX`, "Pacific Gas & Electric" → `PGAE`, "Salesforce" → `SFDC`
- If client name is ambiguous or missing, ask the user: "What prefix should I use for task IDs? (e.g., LYTX)"

---

## Step 3 — Build the Project Plan

### Sheet Schema
Replicate this exact column order (from the NeuraFlash Project Plan template):

| Column | Description |
|---|---|
| UID | Sequential task ID: `[PREFIX-T001]`, `[PREFIX-T002]`, etc. Only on Task/Milestone/Deliverable rows |
| Status | Default: `Not Started` |
| Row Type | One of: `Phase`, `Week`, `Task`, `Meeting`, `Milestone`, `Deliverable` |
| % Done | Default: `0` |
| Task / Name | Full task name. Use emoji prefixes: 📅 for meetings, 🔹 for milestones, 🔸 for deliverables |
| Owner | Role name (e.g., PM, Customer, NeuraFlash, Solution Architect) |
| Attendees | For meetings only |
| Duration | e.g., `1d`, `2d`, `1w` |
| Project Start Date | Pulled from SOW for phase/week rows |
| Workstream | Optional — populate if SOW mentions workstreams |
| Projected End Date | Pulled from SOW where available |
| Actual Start Date | Leave blank |
| Actual End Date | Leave blank |
| Pred. | Task predecessor UIDs, comma-separated |
| SOW Ref | Section reference (e.g., `§2.1`) if traceable |
| Notes / Flags | ⚠️ flag missing info here (e.g., "⚠️ Owner not specified in SOW") |
| Meeting Link | Leave blank |

### Phase Structure (always use this order)

```
PHASE 1: ENGAGE  ·  Discovery & Design
  → Project Setup
  → Kickoff & Discovery Prep
  → Discovery & Design (per SOW workstreams)
  → Align / Gap Review
  → Deliverable Acceptance

PHASE 2: EXECUTE  ·  Iterative Development
  → Sprint Planning
  → Development (per SOW features/workstreams)
  → QA Management
  → Final Testing & UAT

PHASE 3: EVOLVE  ·  Change & Go-Live
  → Change Management
  → Outcome Management
  → Production Deployment
  → Support & Optimization
  → Project Closeout
```

### Populating Tasks
- **Always include** the standard recurring tasks under each week: Budget Tracker Update, Weekly Status Report, RAID Log Update
- **Pull SOW deliverables** → add as `Deliverable` rows with 🔸 prefix under the relevant phase
- **Pull SOW milestones** → add as `Milestone` rows with 🔹 prefix
- **Pull SOW dates** → populate `Project Start Date` and `Projected End Date` for phases/weeks
- **Infer workstream tasks** from scope section (e.g., if SOW mentions "Service Cloud Voice" → add discovery + design + dev + QA tasks for it)
- **Flag gaps** in Notes/Flags column: ⚠️ if date/owner/duration is not in SOW

### Header Row (Row 1 of data, before phases begin)
```
[PROJECT NAME] | [CLIENT] | [START DATE] | [END DATE] | [SOW LINK] | [TEAM]
```

---

## Step 4 — Build the Remaining Six Sheets

### 2. RAID Log
Schema: `ID | Category | Title | Description | Probability | Impact | Owner | Review Date | Status | Mitigation / Action / Decision`
- ID format: `[PREFIX]-R001` for Risks, `[PREFIX]-A001` for Assumptions, `[PREFIX]-I001` for Issues, `[PREFIX]-D001` for Decisions
- Category values: `Risk`, `Assumption`, `Issue`, `Decision`
- Always pre-seed with these standard entries (adapt wording to the SOW):

**Risks:** Customer resource availability (SMEs may not be available) — High/High | Scope creep beyond SOW — Medium/High | System access delays — Medium/High | Pull any additional risks implied by SOW scope

**Assumptions:** Customer SMEs available and prepared for all sessions | Customer will sign off within 7-day review window per SOW | All environments (Dev, QA, Prod) available at project start | Pull any explicit assumptions stated in the SOW

**Issues:** One placeholder — `[PREFIX]-I001` "Add issues as they arise" — Open

**Decisions:** One placeholder — `[PREFIX]-D001` "Add decisions as they are made" — Decided | If SOW references pre-decided items (tech stack, architecture), add them as Decided

### 3. SOW Deliverables
Schema: `UID | Deliverable | SOW Section | Phase | NF Owner | Customer Sign-off By | Status | Delivered Date | Sign-off Date | Notes`
- Pull every deliverable listed in the SOW
- UID format: `[PREFIX]-DL001`, `[PREFIX]-DL002`, etc.
- Populate Phase (Engage/Execute/Evolve), NF Owner, and SOW Section where available
- Leave Delivered Date, Sign-off Date blank; Status = `Not Started`

### 3. Stakeholder Register
Schema: `Stakeholder Name | UID | Organization | Role / Title | Project Role | Email | Phone | Engagement Level | Influence | Communication Preference | Meeting Cadences | Sign-Off Authority | OOO / Availability Notes | Notes`
- UID format: `[PREFIX]-S001`, `[PREFIX]-S002`, etc.
- Pull any named individuals or roles from the SOW
- For roles without names, add a row with the role title and flag name as ⚠️ TBD
- Separate NeuraFlash team members (Organization = NeuraFlash) from Customer stakeholders

### 4. Meeting Register
Schema: `UID | Phase / Week | Date | Meeting Name | Type | Facilitator | NF Attendees | Customer Attendees | Duration | Purpose / Key Agenda Items | Prep Required | Recurs? | Teams/Meet Link | Status`
- UID format: `[PREFIX]-M001`, `[PREFIX]-M002`, etc.
- Always include these standard meetings:
  - Kickoff Meeting (Phase 1 / Week 1) — All Stakeholders — 2h — Recurs: No
  - Weekly Status Call (all phases) — PM + Customer Sponsors — 1h — Recurs: Weekly
  - Sprint Planning / Internal Scrum (Execute phase) — NF Team — 1h — Recurs: Weekly
  - Sprint Review / Demo (Execute phase) — All Stakeholders — 1h — Recurs: Per Sprint
  - Go-Live Readiness Review (Evolve phase) — All Stakeholders — 1h — Recurs: No
- Pull any additional meetings or ceremonies explicitly mentioned in the SOW
- Leave Date and Teams/Meet Link blank; Status = `Scheduled`

### 5. GAP Analysis
Schema: `Gap ID | Source | Type | Status | Date Identified | Plan of Action / Proposed Next Step | Epic / Area | Description of Gap or Change | Add'l Discovery Req? | CR Required? | Owner | Resolution / Notes`
- Gap ID format: `[PREFIX]-G001`, `[PREFIX]-G002`, etc.
- Initialize with 3–5 placeholder rows seeded from obvious scope/design questions raised by the SOW (e.g., integrations not fully specified, custom objects mentioned but not detailed)
- Status = `Open` for all; Date Identified = project start date

### 6. Action Items
Schema: `Action ID | Date Opened | Source | Action Item | Owner | Due Date | Priority | Status | Date Closed | Notes / Resolution`
- Action ID format: `[PREFIX]-AI001`, `[PREFIX]-AI002`, etc.
- Pre-seed with the standard project kickoff action items:
  - Confirm team access to Salesforce / AWS / project tools
  - Schedule Kickoff Meeting with customer
  - Share baseline Project Plan with internal team
  - Complete Sales → Delivery Handoff
  - Verify team PTO and update Salesforce forecasts
- Status = `Open`; Priority = `High` for all kickoff items

---

## Step 5 — Create Project Folder & Save All Sheets

### Step 5a — Google Sheets path

**Ask where to save:**
> "Where in your Shared Google Drive should I create the project folder?
> Give me a parent folder name or ID, or I can create it at the root of your Shared Drive."

Search for the parent folder if a name is given:
```
tool: Google Drive → search_files
  query: name = "[parent folder name]" and mimeType = 'application/vnd.google-apps.folder'
```

**Create the project folder:**
```
tool: Google Drive → create_file
  title: "[CLIENT NAME] — [PROJECT NAME]"
  mimeType: application/vnd.google-apps.folder
  parents: [parent folder ID, or Shared Drive root]
```

**Create all 7 sheets inside the folder** using `parents: [project folder ID]`:

| # | File Title |
|---|---|
| 1 | `[CLIENT NAME] _ Project Plan` |
| 2 | `[CLIENT NAME] _ RAID Log` |
| 3 | `[CLIENT NAME] _ SOW Deliverables` |
| 4 | `[CLIENT NAME] _ Stakeholder Register` |
| 5 | `[CLIENT NAME] _ Meeting Register` |
| 6 | `[CLIENT NAME] _ GAP Analysis` |
| 7 | `[CLIENT NAME] _ Action Items` |

Create files sequentially. If any creation fails, note it in the summary and continue.

---

### Step 5b — Smartsheet path

**Check MCP connection first.** If the Smartsheet MCP is not connected, stop and prompt:
> "To create artifacts in Smartsheet, please connect the Smartsheet integration in your Claude settings first, then run this again."

**Once connected:**

**Ask where to save:**
> "Should I create the project sheets inside an existing Smartsheet workspace/folder, or create a new one? If existing, give me the name."

**Create a new Smartsheet folder or workspace** named `[CLIENT NAME] — [PROJECT NAME]`.

**Create each sheet** inside that folder using the Smartsheet MCP's sheet creation tool. Map columns exactly to the schemas defined above — Smartsheet uses typed columns:

| Column Type Guidance | |
|---|---|
| Text/Number | UID, Task Name, Owner, Notes, Description, etc. |
| Date | Start Date, End Date, Due Date, Delivered Date, Sign-off Date |
| Dropdown (single) | Status, Row Type, Priority, Category, Phase, Probability, Impact |
| Checkbox | Add'l Discovery Req?, CR Required? |
| Text | All free-text fields |

- Use `PRIMARY` column for the main name/title field in each sheet (Task Name, Deliverable, Stakeholder Name, etc.)
- For the Project Plan sheet, enable **Gantt view** if the Smartsheet API supports it, using Start Date and End Date columns
- Sheet names follow the same format: `[CLIENT NAME] _ Project Plan`, etc.

**After all sheets are created**, share the Smartsheet folder/workspace URL with the user.

---

## Step 6 — Summary Report to User

After all files are created, provide a summary:

```
✅ Project artifacts created for [CLIENT NAME]! ([Google Sheets / Smartsheet])

📁 Folder: [CLIENT NAME] — [PROJECT NAME] → [folder/workspace link]

Files created:
  📋 Project Plan         → [link]  ([N] tasks | [N] milestones | [N] deliverables)
  🔍 RAID Log             → [link]  ([N] Risks | [N] Assumptions | [N] Issues | [N] Decisions)
  📦 SOW Deliverables     → [link]  ([N] deliverables tracked)
  👥 Stakeholder Register → [link]  ([N] stakeholders)
  📅 Meeting Register     → [link]  ([N] meetings scaffolded)
  🔄 GAP Analysis         → [link]  ([N] initial gaps seeded)
  ✅ Action Items         → [link]  ([N] kickoff actions)

⚠️ Missing from SOW (fill in manually):
   [List any dates, owners, or details not found in the SOW]
```

---

## Notes & Edge Cases

- **SOW is a Google Doc link (not uploaded):** Ask user to share the link or export as text. Use `read_file_content` if accessible via Drive MCP.
- **Multiple SOWs found in search:** Show a numbered list, ask user to confirm before proceeding.
- **SOW doesn't specify phases/dates:** Use `[TBD]` placeholders and flag with ⚠️.
- **Non-standard client name:** If client name is ambiguous or very long, ask user to confirm the UID prefix before generating.
- **Parent folder not found (Google Sheets):** Offer to create the project folder at the Shared Drive root instead.
- **Smartsheet MCP not connected:** Do not attempt to create Smartsheet files. Prompt the user to connect the integration first.

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
