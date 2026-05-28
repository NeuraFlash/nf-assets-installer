---
name: navigate-discovery
description: "Use this skill when a Solution Architect needs to generate delivery documents from a Statement of Work. Triggers include: \"create discovery questionnaire\", \"generate solution design\", \"draft SDD\", \"create discovery plan\", \"build technical design document\", \"generate SA documents\", \"create discovery and design docs from SOW\", \"set up SA artifacts\", or any request to produce Solution Design, Discovery Session Plan, or Technical Design documents for a project. This skill orchestrates the navigate-agent MCP two-step workflow: first generating a Solution Design Document (SDD), then using its output to generate a Discovery Session Plan. It also produces a Technical Design Document (TDD) natively when the navigate-agent TDD tool is unavailable. Always trigger when SA + SOW + document generation are mentioned together."
compatibility: "mcp_navigate_agent: navigate-agent MCP (required — provides generate_solution_design and generate_discovery_plan) | mcp_google_drive: Google Drive (required — reads SOW and pre-sales notes; saves output DOCXs) | mcp_salesforce: Salesforce MCP (optional — enriches TDD with org and integration context)"
---

## Step 0 — start telemetry (REQUIRED, FIRST STEP)

Before doing anything else, call:

```
telemetry.skill_start({
  skill_name: "navigate-discovery",
  input_summary: "<short, non-sensitive summary of the user's request>"
})
```

**Save the returned `invocation_id`** — you will need it in Step N.

Do NOT proceed to the user's task if `skill_start` returns an error. Surface
the error and stop.

---

# SA Discovery — SOW → Solution Design + Discovery Plan + TDD

Produces three core SA delivery documents from a Statement of Work:

| #   | Document                            | Tool                                       | Output                |
| --- | ----------------------------------- | ------------------------------------------ | --------------------- |
| 1   | **Solution Design Document (SDD)**  | navigate-agent: `generate_solution_design` | DOCX + JSON outline   |
| 2   | **Discovery Session Plan**          | navigate-agent: `generate_discovery_plan`  | DOCX                  |
| 3   | **Technical Design Document (TDD)** | Claude-native (navigate-agent fallback)    | DOCX via `docx` skill |

> **Execution order is mandatory.** Step 2 (Discovery Plan) requires the JSON outline produced by Step 1 (SDD). Do not skip or reorder.

---

## Step 1 — Obtain the SOW

### Check shared project context first

Before asking the user, check if the SOW text is already available in the current Claude project context (the PM's navigate-plan skill should have retrieved it earlier in the session).

- If SOW text is in context → confirm with user: "I can see the SOW for [project name] is already in our project context — shall I use that?"
- If not in context → ask the user:

> "Please either:
>
> - **Give me the SOW file name** and I'll find it in Google Drive, OR
> - **Upload or paste** the SOW text directly."

### If searching Google Drive

```
tool: Google Drive → search_files
  query: name contains "[user-provided name]" and mimeType = 'application/vnd.google-apps.document'
```

- Search Shared Drives (not just My Drive)
- If multiple results, list by name + last modified date and ask user to confirm
- Once confirmed: `read_file_content` → extract full text as `sow_text`

### If uploaded or pasted

- Accept `.docx` or plain text
- Store as `sow_text`

---

## Step 1b — Pull Supplemental Context

Before generating documents, check if additional context is available. Ask:

> "Should I also pull in the pre-sales notes and Salesforce opportunity data from our project context? These enrich the SDD and Discovery Plan with real customer context."

### Pre-sales / discovery notes (Google Drive)

- If available in project context → use directly
- If not → search Google Drive using the same Shared Drive as the SOW:

```
tool: Google Drive → search_files
  query: name contains "[discovery OR pre-sales OR notes]" and mimeType = 'application/vnd.google-apps.document'
```

- Append extracted text to `supplemental_context` — keep separate from `sow_text`

### Salesforce opportunity context

- If Salesforce data is in project context from the PM's navigate-plan run → extract:
  - Account name, opportunity name, contract value
  - Named contacts and roles
  - Product/line items (for scope cross-reference)
- If not available and Salesforce MCP is connected → query:

```
tool: Salesforce MCP → soqlQuery
  query: SELECT Id, Name, Account.Name, Amount, Description, CloseDate
         FROM Opportunity
         WHERE Name LIKE '%[project name]%'
         LIMIT 5
```

- Store as `sfdc_context`

---

## Step 2 — Generate Solution Design Document (SDD)

Call the navigate-agent MCP:

```
tool: navigate-agent → generate_solution_design
  sow_text: [full SOW text from Step 1]
```

### On success

- The tool returns a JSON string containing:
  - `outline_json` — structured outline of the solution design (required for Step 3)
  - `docx_path` or `file_path` — path to the generated DOCX file
- **Save `outline_json` immediately** — it is required as input for Step 3
- Display a brief summary to the user:
  > "✅ Solution Design Document generated. Here's what it covers: [top-level sections from outline_json]"

### On failure

- If navigate-agent returns an error, do NOT proceed to Step 3 with incomplete data
- Show the error to the user and ask: "The SDD generation hit an issue — would you like me to draft the SDD natively using the SOW text instead?"
- If yes → see **Appendix A: Native SDD Generation**
- Manually construct an `outline_json` from the native SDD and proceed to Step 3

### SDD review (optional)

Ask the user:

> "Do you want to review or adjust the SDD outline before I generate the Discovery Plan? The Discovery Plan is built from this structure."

- If yes → present the top-level outline sections and allow additions or removals
- If no → proceed directly to Step 3

---

## Step 3 — Generate Discovery Session Plan

Call the navigate-agent MCP with both inputs:

```
tool: navigate-agent → generate_discovery_plan
  sow_text: [same SOW text from Step 1]
  outline_json: [JSON string returned from Step 2]
```

### On success

- The tool returns a JSON string with:
  - `docx_path` or `file_path` — path to the Discovery Plan DOCX
  - Optionally a structured summary of sessions / questions
- Display a brief summary:
  > "✅ Discovery Session Plan generated. Sessions: [list session names if available in response]"

### On failure

- Show the error to the user
- Ask: "Shall I draft the Discovery Questionnaire natively from the SDD outline instead?"
- If yes → see **Appendix B: Native Discovery Plan Generation**

---

## Step 4 — Generate Technical Design Document (TDD)

> ⚠️ The navigate-agent MCP does not currently have a `generate_technical_design` tool. The TDD is generated natively by Claude using the SDD outline and SOW as source material.

Inform the user:

> "The navigate-agent doesn't have a TDD generator yet — I'll draft the Technical Design Document natively from the SDD and SOW. This is flagged as a gap for a future navigate-agent tool."

### TDD structure (generate section by section)

Using the `sow_text`, `outline_json` from the SDD, and any `sfdc_context`, generate the following sections:

#### 1. Document Header

```
Project:          [Project Name]
Client:           [Client Name]
Prepared by:      [Solution Architect — TBD]
Version:          0.1 DRAFT
Date:             [Today's date]
Status:           Draft — Pending SA Review
```

#### 2. Architecture Overview

- High-level system architecture diagram description (components, layers, integrations)
- Salesforce org structure (if SFDC project): sandbox strategy, environments (Dev / QA / UAT / Prod)
- Key technical decisions and rationale — trace each to a SOW requirement or SDD section

#### 3. Component Design

For each workstream or feature area identified in the SDD outline:
| Component | Type | Salesforce Object/API | Custom vs Standard | SDD Reference |
|---|---|---|---|---|

- Types: Custom Object, Flow, Apex Class, LWC, Integration, Apex Trigger, Permission Set, etc.
- Flag anything not in the SOW scope as ⚠️ OUT OF SCOPE or ⚠️ POTENTIAL CR

#### 4. Data Model

- New or modified Salesforce objects and fields
- Schema: `Object Name | Field Label | API Name | Type | Length | Required | Description`
- Relationships: lookup / master-detail / external ID
- Data migration approach (if applicable): source system, volume estimate, migration strategy

#### 5. Integration Design

For each integration identified in the SOW or SDD:
| Integration | Direction | Protocol | Auth Method | Frequency | Error Handling | SDD Reference |
|---|---|---|---|---|---|---|

- Flag integrations with no spec in SOW: ⚠️ Needs discovery session

#### 6. Security & Permission Model

- Profile / Permission Set strategy
- Field-level security requirements
- Sharing rules and OWD recommendations
- Trace to SOW compliance or regulatory requirements if mentioned

#### 7. Apex & Automation Design

- List all Apex classes, triggers, and batch jobs
- For each: purpose, governor limit considerations, test class requirement (≥85% coverage)
- List all Flows / Process Builders (prefer Flows over legacy automation)
- Trigger framework: note if Trigger Actions Framework (TAF) applies per sf-apex skill standards

#### 8. LWC / UI Design

- List all Lightning Web Components
- For each: component name, parent page/app, data source, events emitted/received
- Accessibility requirements

#### 9. Test Strategy

| Test Type | Scope | Owner | Tool | Entry Criteria | Exit Criteria |
| --------- | ----- | ----- | ---- | -------------- | ------------- |

- Unit tests (Apex): ≥85% coverage, boundary conditions
- Integration tests: end-to-end data flow per integration spec
- UAT: mapped to user stories from Consultant lane
- Performance: governor limits, bulk data scenarios

#### 10. Open Items & Gaps

- List all ⚠️ flags raised during TDD generation
- Format: `TDD-OI001 | Section | Description | Owner | Due Date | Status`
- Any item without a SOW reference is a candidate for a Change Request (CR)

### TDD output format

- Use the `docx` skill to render the TDD as a formatted Word document
- File name: `[CLIENT NAME] _ Technical Design Document v0.1 DRAFT.docx`

---

## Step 5 — Save All Documents to Google Drive

Ask the user:

> "Where should I save the generated documents? I'll add them to the same project folder created during the PM setup, or you can specify a different location."

### Save each document

```
tool: Google Drive → create_file (or upload_file)
  title: "[CLIENT NAME] _ Solution Design Document v0.1 DRAFT"
  parent: [project folder ID from navigate-plan session, or user-specified]
  file: [DOCX from Step 2]

tool: Google Drive → create_file
  title: "[CLIENT NAME] _ Discovery Session Plan v0.1 DRAFT"
  parent: [same folder]
  file: [DOCX from Step 3]

tool: Google Drive → create_file
  title: "[CLIENT NAME] _ Technical Design Document v0.1 DRAFT"
  parent: [same folder]
  file: [DOCX from Step 4]
```

- If any upload fails, note it in the summary and provide the local file path as fallback
- All three documents should land in the same folder as the PM's 7 artifacts

---

## Step 6 — Summary Report

```
✅ SA Discovery documents generated for [CLIENT NAME]

📁 Saved to: [Project Folder] → [link]

Documents:
  📐 Solution Design Document   → [link]  (generated by navigate-agent)
  🔍 Discovery Session Plan     → [link]  (generated by navigate-agent)
  🛠️ Technical Design Document  → [link]  (generated natively — Claude)

⚠️  Open items to address before Discovery sessions:
   [List all ⚠️ flags from TDD open items]

🔧 Navigate-agent gap flagged:
   generate_technical_design tool is not yet available in the navigate-agent MCP.
   TDD was produced natively. Recommend adding this tool to navigate-agent for
   future automation parity with SDD and Discovery Plan generation.

Next step → Consultant: use the SDD to generate User Stories (sa-discovery complete ✅)
```

---

## Appendix A — Native SDD Generation (fallback)

Use this if `generate_solution_design` fails or navigate-agent is unavailable.

Generate the SDD with the following section structure, using `sow_text` and `supplemental_context`:

1. **Executive Summary** — project purpose, client, scope statement (1 paragraph)
2. **Scope & Objectives** — in-scope features, out-of-scope items, success criteria
3. **Functional Requirements** — numbered list, each traced to a SOW section: `FR-001 | Description | SOW Ref | Priority`
4. **Architecture Overview** — platform, org type, key components
5. **Integration Design** — each integration: system, direction, protocol, auth, frequency
6. **Data Model Summary** — key objects, new vs modified, migration notes
7. **Assumptions & Constraints** — from SOW + pre-sales notes; each flagged as ⚠️ if unconfirmed
8. **Open Items** — gaps requiring discovery: `OI-001 | Description | Owner | Due`

After generating, construct `outline_json` as:

```json
{
  "project": "[project name]",
  "client": "[client name]",
  "sections": [
    {
      "id": "FR",
      "title": "Functional Requirements",
      "items": ["FR-001...", "FR-002..."]
    },
    { "id": "ARCH", "title": "Architecture Overview", "components": ["..."] },
    { "id": "INT", "title": "Integrations", "integrations": ["..."] },
    { "id": "DATA", "title": "Data Model", "objects": ["..."] },
    { "id": "OI", "title": "Open Items", "items": ["OI-001..."] }
  ]
}
```

---

## Appendix B — Native Discovery Plan Generation (fallback)

Use this if `generate_discovery_plan` fails or navigate-agent is unavailable.

Using the `outline_json` from the SDD, generate a Discovery Session Plan structured as:

### Session structure (one session per workstream or major functional area)

```
Session [N]: [Workstream / Topic]
Duration: [1.5h recommended]
Facilitator: Solution Architect
Attendees: [Customer SMEs for this workstream], PM, Consultant

Agenda:
  1. Current state walkthrough (15 min)
  2. Requirements deep-dive (45 min)
  3. Gap identification (20 min)
  4. Next steps & actions (10 min)

Questions:
  Current State:
    - [Question derived from SDD open items or assumptions for this area]
  Future State:
    - [Question from functional requirements needing confirmation]
  Data & Integration:
    - [Question from integration or data model gaps]
  Acceptance Criteria:
    - [How will we know this requirement is done?]
```

Generate one session block per major section in `outline_json.sections`.
Always include a final session: "Discovery Wrap-up & Gap Review" — 1h, all stakeholders.

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

- Never merge `sow_text` and `supplemental_context` into a single string — keep them separate for accurate citations
- Always pass the exact JSON string from `generate_solution_design` into `generate_discovery_plan` — do not summarise or reformat it
- All ⚠️ flags raised during TDD generation must appear in the Step 6 summary report
- Do not skip `skill_end` — even if the skill errors partway through

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
