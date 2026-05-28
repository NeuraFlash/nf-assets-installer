---
name: project-setup
description: "Use this skill whenever a new NeuraFlash project needs to be initialised in Claude. Triggers include: \"set up a new project\", \"create a project for [client]\", \"new project setup\", \"initialise project\", \"onboard new client\", \"create Claude project for [client]\", \"project kickoff setup\", \"spin up project\", or any request to prepare a new Claude project for a client engagement. This skill collects project details, enriches them from the SOW and Salesforce, fills all placeholders in the NeuraFlash project system prompt template, creates the Google Drive folder structure, saves the completed prompt to Drive, and outputs a copy-paste ready system prompt the PM can paste directly into the Claude project instructions. Always trigger when: new project + Claude setup or system prompt are mentioned together."
compatibility: "mcp_google_drive: Google Drive (required — searches for SOW; creates project folder; saves completed prompt) | mcp_salesforce: Salesforce MCP (optional — auto-fills client, contract value, dates, contacts) | mcp_smartsheet: Smartsheet MCP (optional — creates Smartsheet workspace during folder setup)"
---

## Step 0 — start telemetry (REQUIRED, FIRST STEP)

Before doing anything else, call:

```
telemetry.skill_start({
  skill_name: "project-setup",
  input_summary: "<short, non-sensitive summary of the user's request>"
})
```

**Save the returned `invocation_id`** — you will need it in Step N.

Do NOT proceed to the user's task if `skill_start` returns an error. Surface
the error and stop.

---

# Project Setup — New Project Initialisation

Produces a **fully filled NeuraFlash project system prompt** ready to paste into a
Claude project, plus a **Google Drive folder structure** with the completed prompt saved
as a Google Doc.

| # | Step | Output |
|---|---|---|
| 1 | Collect project details | `project_data` object |
| 2 | Enrich from SOW | Auto-fill dates, scope, team |
| 3 | Enrich from Salesforce | Auto-fill client, contract value, contacts |
| 4 | Fill system prompt template | Completed prompt (no placeholders remaining) |
| 5 | Create Google Drive folder structure | Project folder + subfolders |
| 6 | Save completed prompt to Drive | Google Doc in project folder |
| 7 | Output copy-paste ready prompt | Displayed in chat for immediate use |

---

## Step 1 — Collect Project Details

Ask the user for the minimum required details in a **single conversational message**.
Do not fire questions one at a time.

> "Let's set up your new Claude project. Give me as much of the following as you have —
> I'll fill in the rest from the SOW and Salesforce:
>
> - **Client name**
> - **Project name** (short description, e.g., "Service Cloud + AgentForce Implementation")
> - **Salesforce product(s) in scope** (e.g., Service Cloud, Sales Cloud, AgentForce)
> - **Your role** on this project (PM / SA / Consultant / Dev)
> - **Project start date**
> - **Go-live / end date**
> - **SOW file name** (if it's in Google Drive, or upload it now)
> - **Salesforce opportunity name** (if you want me to pull contract details)
> - **UID prefix** — 2–4 letters for document IDs (e.g., NFACM). I'll suggest one if you skip this.
> - **JIRA project key** (e.g., NFACM — leave blank if not set up yet)
> - **NeuraFlash PM name + email**"

### Required fields (skill cannot proceed without these)
- Client name
- Project name
- Start date

### Optional fields (fill from SOW/Salesforce if not provided)
- Org type, go-live date, contract value, UID prefix, JIRA key, PM name/email

### UID prefix auto-generation (if not provided)
Generate from client name initials + project keyword:
- "Acme Corporation — Service Cloud" → `NFACS`
- "Global Retail Inc — AgentForce" → `NFGRA`
- Rules: NF prefix + first letter of first two client words + first letter of product
- Always confirm with user: "I'll use `[PREFIX]` as your UID prefix — OK?"

### Phase auto-detection
If start date is in the future or within 2 weeks → default to `Engage`.
If start date is >2 weeks ago but go-live is in the future → default to `Execute`.
If go-live date has passed → default to `Evolve`.
Always confirm with user before proceeding.

---

## Step 2 — Enrich from SOW

### Search or accept SOW
If the user provided a SOW name, search Google Drive:
```
tool: Google Drive → search_files
  query: name contains "[sow name]"
```
- Search Shared Drives first
- If multiple results, list by name + last modified and ask user to confirm
- Once confirmed: `read_file_content` → store as `sow_text`

### Extract from SOW to fill project_data
| Field | Where to find it in SOW |
|---|---|
| `project_name` | Title / cover page |
| `client_name` | "Prepared for" / "Client" header |
| `org_type` | Scope section — Salesforce products mentioned |
| `start_date` | Timeline / milestones section |
| `go_live_date` | Timeline / go-live milestone |
| `contract_value` | Commercial / pricing section |
| `team_members` | Team / resource section — NF names and roles |
| `jira_project_key` | Tools / environment section (if mentioned) |
| `google_drive_folder` | Infer from SOW file location in Drive |

Flag any field still missing after SOW extraction with `[NEEDS INPUT]` —
ask the user for those specific fields only, not the full list again.

---

## Step 3 — Enrich from Salesforce (if MCP connected)

If Salesforce MCP is connected and user provided an opportunity name, query:

```
tool: Salesforce MCP → soqlQuery
  query: SELECT Id, Name, Account.Name, Amount, CloseDate, StageName,
                Owner.Name, Owner.Email, Description
         FROM Opportunity
         WHERE Name LIKE '%[opportunity name]%'
         LIMIT 5
```

If multiple results, list and ask user to confirm.

Once confirmed, pull related contacts:
```
tool: Salesforce MCP → getRelatedRecords
  sobject-name: Opportunity
  id: [opportunity id]
  relationship-path: OpportunityContactRoles
```

### Map Salesforce fields to project_data
| Salesforce Field | project_data field |
|---|---|
| `Account.Name` | Confirm / correct `client_name` |
| `Amount` | `contract_value` |
| `CloseDate` | Cross-check `go_live_date` — flag if different |
| `Owner.Name` + `Owner.Email` | `pm_name` + `pm_email` (if PM is opp owner) |
| `OpportunityContactRole` where role = "Decision Maker" | Add to Stakeholder Register later |
| `Description` | Supplement `project_name` and scope |

If Salesforce MCP is not connected:
> "Salesforce MCP isn't connected — skipping SFDC enrichment.
> You can connect it via Settings → Connections → Salesforce."
Continue to Step 4 with available data.

---

## Step 4 — Build the Completed System Prompt

Using the fully populated `project_data`, generate the system prompt by substituting
every `[BRACKETED]` placeholder in the NeuraFlash project system prompt template.

### project_data object (confirm all values before filling)
```
project_data = {
  client_name:         "[CLIENT NAME]",
  project_name:        "[PROJECT NAME]",
  org_type:            "[ORG TYPE]",
  phase:               "Engage | Execute | Evolve",
  contract_value:      "[CONTRACT VALUE or OMIT IF SENSITIVE]",
  start_date:          "[START DATE]",
  go_live_date:        "[GO-LIVE DATE]",
  uid_prefix:          "[UID PREFIX]",
  jira_project_key:    "[JIRA PROJECT KEY or TBD]",
  google_drive_folder: "[FOLDER NAME or URL]",
  smartsheet_workspace:"[WORKSPACE NAME or TBD]",
  salesforce_opp:      "[OPPORTUNITY NAME or ID]",
  pm_name:             "[PM FULL NAME]",
  pm_email:            "[PM EMAIL]",
  year:                "[CURRENT YEAR]"
}
```

### Confirmation step (REQUIRED)
Before generating the full prompt, display a summary table to the user:

> "Here's what I'll use to set up the project. Confirm or correct anything before I generate:
>
> | Field | Value | Source |
> |---|---|---|
> | Client | [value] | [SOW / Salesforce / User] |
> | Project | [value] | [SOW / User] |
> | Phase | [value] | [Auto-detected / User] |
> | Start Date | [value] | [SOW / User] |
> | Go-Live | [value] | [SOW / Salesforce] |
> | UID Prefix | [value] | [Auto-generated / User] |
> ... (all fields)"

Wait for user to confirm ("looks good", "correct", "yes") before proceeding.

### Generate the filled prompt
Substitute every placeholder using `project_data`. The output must contain:
- Zero `[BRACKETED]` placeholders remaining
- Correct phase highlighted in the Engage/Execute/Evolve section
- Project Context table fully populated
- Standard sign-off with PM name and email
- Copyright year filled
- Confidentiality disclaimer with current year

---

## Step 5 — Create Google Drive Folder Structure

### Check for existing project folder
```
tool: Google Drive → search_files
  query: name = "[CLIENT NAME] — [PROJECT NAME]" and mimeType = 'application/vnd.google-apps.folder'
```

If found → ask user: "A folder named '[name]' already exists in Shared Drive. Use it or create a new one?"

If not found → create it:
```
tool: Google Drive → create_file
  name: "[CLIENT NAME] — [PROJECT NAME]"
  mimeType: application/vnd.google-apps.folder
  parents: [Shared Drive root or user-specified parent]
```

### Create standard subfolder structure
Inside the project folder, create these subfolders in order:

```
📁 [CLIENT NAME] — [PROJECT NAME]/
  ├── 📁 01 — Project Management      (PM artifacts: Project Plan, RAID Log, etc.)
  ├── 📁 02 — Discovery & Design      (Discovery Q, SDD, TDD)
  ├── 📁 03 — User Stories & Backlog  (Story spreadsheets, approved backlog)
  ├── 📁 04 — Development             (Code reviews, technical notes)
  ├── 📁 05 — Customer Deliverables   (Customer-facing docs, sign-off versions)
  ├── 📁 06 — Presentations & Decks   (Kickoff, status reports, success criteria)
  ├── 📁 07 — SOW & Contracts         (SOW copy, amendments, CRs)
  └── 📁 00 — Project Admin           (System prompt, team roster, access log)
```

Create each subfolder:
```
tool: Google Drive → create_file (repeat for each subfolder)
  name: "[subfolder name]"
  mimeType: application/vnd.google-apps.folder
  parents: [project folder id]
```

If the SOW was found in Google Drive in Step 2, create a shortcut to it in `07 — SOW & Contracts`.

Save all folder IDs to `folder_map` for use in Step 6.

---

## Step 6 — Save Completed Prompt to Google Drive

Create a Google Doc with the completed system prompt in the `00 — Project Admin` folder:

```
tool: Google Drive → create_file
  name: "[CLIENT NAME] _ Claude Project System Prompt v1.0"
  mimeType: application/vnd.google-apps.document
  parents: [folder_map["00 — Project Admin"]]
  content: [completed system prompt text from Step 4]
```

Also create a **Project README** doc in the root project folder:

```
tool: Google Drive → create_file
  name: "[CLIENT NAME] — [PROJECT NAME] _ README"
  mimeType: application/vnd.google-apps.document
  parents: [project folder id]
  content: [README content — see Appendix A]
```

Display links to both docs after creation.

---

## Step 7 — Output Copy-Paste Ready Prompt

Display the completed system prompt in chat, formatted for immediate copy-paste into
Claude project instructions:

> "✅ Your project system prompt is ready. Copy everything between the lines below
> and paste it into your Claude project's **Project Instructions** field:
>
> ---
> [COMPLETED SYSTEM PROMPT — all placeholders filled]
> ---
>
> 📁 Also saved to Google Drive: [link to system prompt doc]"

### How to paste into Claude project (step-by-step)
Include these instructions below the prompt:

> **To add to your Claude project:**
> 1. Go to [claude.ai/projects](https://claude.ai/projects)
> 2. Open the project (or create a new one named **[CLIENT NAME] — [PROJECT NAME]**)
> 3. Click **"Edit project instructions"** (pencil icon, top right)
> 4. Paste the prompt above → click **Save**
> 5. Connect MCPs: Google Drive, Salesforce, Smartsheet, Atlassian Rovo
> 6. Add team members as collaborators in project settings

---

## Step 8 — Offer Next Steps

After the prompt is delivered, ask:

> "Project is set up ✅. What would you like to do next?
> - **Run navigate-plan** — generate the 7 PM artifacts from the SOW now
> - **Run sa-discovery** — generate SDD, Discovery Plan, and TDD
> - **Done for now** — come back when your team is ready"

If user selects navigate-plan or sa-discovery, trigger that skill immediately using
the SOW text already retrieved in Step 2 — do not ask for it again.

---

## Authoring notes

- Never leave a `[BRACKETED]` placeholder in the completed system prompt — every field
  must be filled or explicitly marked `TBD` with a note explaining what's needed
- Always confirm `project_data` with the user before generating the prompt (Step 4) —
  regenerating after a correction is expensive
- If contract value is not provided and cannot be found in SOW or Salesforce, omit the
  field from the prompt entirely rather than showing `[CONTRACT VALUE]`
- If JIRA key is not yet set up, populate as `TBD — update when JIRA project is created`
- Do not trigger the next skill (navigate-plan / sa-discovery) without explicit user
  confirmation in Step 8 — they may not be ready
- Always create the `00 — Project Admin` folder first so the system prompt has a home
  even if later subfolder creation fails

---

## Appendix A — Project README Template

Use this content when creating the README doc in Step 6.

```markdown
# [CLIENT NAME] — [PROJECT NAME]

**NeuraFlash | Part of Accenture**
Phase: [Engage / Execute / Evolve]
Start: [START DATE] | Go-Live: [GO-LIVE DATE]

---

## Project Overview
[Pull 2–3 sentence summary from SOW scope section]

## Team
| Role | Name | Email |
|---|---|---|
| Project Manager | [PM NAME] | [PM EMAIL] |
| Solution Architect | TBD | — |
| Consultant | TBD | — |
| Developer | TBD | — |
| Client Sponsor | TBD | — |

## Folder Structure
| Folder | Contents |
|---|---|
| 01 — Project Management | Project Plan, RAID Log, SOW Deliverables, Stakeholder Register, Meeting Register, GAP Analysis, Action Items |
| 02 — Discovery & Design | Discovery Questionnaire, Solution Design Document, Technical Design Document |
| 03 — User Stories & Backlog | User Story spreadsheet, approved backlog |
| 04 — Development | Code reviews, architecture notes, deployment logs |
| 05 — Customer Deliverables | Customer-facing sign-off documents |
| 06 — Presentations & Decks | Kickoff deck, status reports, success criteria |
| 07 — SOW & Contracts | SOW, amendments, Change Requests |
| 00 — Project Admin | Claude project system prompt, access log, team roster |

## Key Links
- **Claude Project:** [Add link after creating]
- **JIRA Board:** [Add link when JIRA is set up]
- **Smartsheet Workspace:** [Add link after navigate-plan runs]
- **Salesforce Opportunity:** [SFDC link]

## AI Tooling Setup
This project uses Claude AI with the following skills and MCPs:

**Skills:** navigate-plan · sa-discovery · consultant-stories · sf-apex · neuraflash-presentations
**MCPs:** Google Drive · Salesforce · Smartsheet · Atlassian Rovo · navigate-agent · Skill Telemetry

See `00 — Project Admin / Claude Project System Prompt` for full configuration.

---
*Initialised by project-setup skill on [DATE]*
*© NeuraFlash [YEAR]. Confidential.*
```

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
