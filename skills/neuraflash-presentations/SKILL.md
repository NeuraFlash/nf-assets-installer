---
name: neuraflash-presentations
description: "Generate Google Slides presentations that match NeuraFlash's brand template — correct styling, slide layouts, content patterns, and messaging for sales, QBR, kickoff, and internal decks"
license: "proprietary"
metadata:
  version: "2.0.0"
  last_updated: "2026-04-24"
---

## Step 0 — start telemetry (REQUIRED, FIRST STEP)

Before doing anything else, call:

```
telemetry.skill_start({
  skill_name: "neuraflash-presentations",
  input_summary: "<short, non-sensitive summary of the user's request>"
})
```

**Save the returned `invocation_id`** — you will need it in Step N.

Do NOT proceed to the user's task if `skill_start` returns an error. Surface
the error and stop.

---

# NeuraFlash Presentations Skill

Generate presentations that match NeuraFlash's visual identity, messaging hierarchy, and Google Slides template patterns. This skill covers brand standards, every slide template type, and standard deck structures for different audiences.

> Brand values below are duplicated from `global/BRAND.md` for convenience.
> If you need to change a color, stat, or claim, update `BRAND.md` first,
> then mirror the change here.

---

## Brand Identity

### Colors
| Role | Hex |
|------|-----|
| Primary Dark Navy (backgrounds, section dividers) | `#1A1A2E` |
| Primary Orange/Coral (accents, CTAs, highlights) | `#FF6B35` |
| White (text on dark backgrounds) | `#FFFFFF` |
| Light Gray (content slide backgrounds) | `#F5F5F5` |
| Dark Gray (body text on light backgrounds) | `#333333` |
| Teal/Cyan (secondary accent) | `#00B4D8` |

### Typography
- **Headings**: Google Sans Bold (fallback: Montserrat Bold)
- **Body**: Google Sans Regular (fallback: Open Sans Regular)
- **Stats/Numbers**: Bold, oversized numerals for emphasis

### Standard Brand Stats — use verbatim every time
| Metric | Value |
|--------|-------|
| CSAT | 4.9 (FY26) |
| Employees | 500+ |
| Certifications & Accreditations | 2,525 |
| Partner Since | 2016 |

### Canonical Brand Claims — use as written
- "NeuraFlash is the #1 Agentforce partner"
- "NeuraFlash-built Agents on average are 350% more effective than agents built by anyone else"
- "Purpose-built tools accelerate projects and result in ~40% faster time to value"
- "#1 Amazon Connect Partner"
- "#1 Salesforce SCV Partner"
- "30–50% reduction in implementation timelines"
- "Acquired by Accenture"
- "100+ Agentforce Customers"
- "70+ GenAI Projects"
- "2,525 Certifications & Accreditations"

---

## Slide Format — Markdown Representation

Slides are separated by `-----`. Every slide (including blank/visual-only slides) has a `-----` before and after it. Never omit separators.

---

## Slide Templates

### 1. Cover / Title Slide
Used as the first slide of every deck.

```
-----

# NeuraFlash | [Topic Title]

[Short subtitle or tagline — 1 to 2 lines max]

-----
```

Variant for partner/client joint decks:
```
-----

# NeuraFlash & [Partner/Client Name]

[Date or event — e.g., "March 2026" or "Q1 QBR 2026"]

-----
```

---

### 2. Company Overview / Stats Slide
Standard slide that follows the cover in external decks. Use the exact wording below.

```
-----

CSAT
4.9 (FY26)
Employee
500+
Certifications & Accreditations
2,525
Partner Since
2016

How we enable transformation
Building the Strategy | Designing and Implementing | Connecting Ecosystems | Ensuring Success
Client Services Strategy | Revenue Cloud | Contact Center | Exp Cloud | Field Service | Integrations (MuleSoft) | Change Mgmt. | Outcomes & Insights | Managed Services

We are your GenAI Innovation Partner

Our Partnerships
NeuraFlash is the #1 Agentforce partner
NeuraFlash-built Agents on average are 350% more effective than agents built by anyone else
Purpose-built tools accelerate projects and result in ~40% faster time to value

-----
```

---

### 3. Timeline / "Why We're #1" Slide
Use in external sales and overview decks.

```
-----

Why are we #1? Our DNA is AI

2001 — First AI Voice system went live
2013 — Launched first AI chatbots in the world
2016 — Built first AI chatbot product for Salesforce
2016 — Accepted into Salesforce AI Incubator (the only consulting partner)
2016 — NeuraFlash founded
2017 — Einstein announced; became partner for all Einstein platform
2018 — Field Service Specialist
2020–2023 — #1 Amazon Connect Partner | #1 Salesforce SCV Partner | 70+ GenAI Projects
2024 — #1 Agentforce Partner | 100+ Agentforce Customers | Agentforce Launched!
2025 — Acquired by Accenture

-----
```

---

### 4. Practice / Value Proposition Slide
Use to introduce a specific practice (MuleSoft, Agentforce, Data Cloud, etc.).

```
-----

The NeuraFlash [Practice Name] Practice

**Award-Winning Talent**
[1–2 sentences on certifications, team size, partner recognition]

**AI & Automation Leader**
[1–2 sentences on AI-specific expertise]

**Enterprise-Ready with Mid-Market Agility**
[1–2 sentences on governance + speed]

**Full Lifecycle Ownership**
[1–2 sentences on end-to-end delivery]

**Faster Time-to-Value**
[1–2 sentences on pre-built assets, frameworks, timelines]

**Customer Enablement**
[1–2 sentences on self-sufficiency, reducing vendor dependency]

-----
```

---

### 5. Section Divider Slide
Used between major sections. Dark background, large title only.

```
-----

# [Section Name]

-----
```

Examples: `# Approach`, `# Quick Starts`, `# Demo`, `# Roadmap`, `# Investment Overview`

---

### 6. Crawl / Walk / Run Approach Slide
Standard NeuraFlash maturity framework slide.

```
-----

CRAWL — Foundation & [Short Label]
[1–2 sentences describing the crawl phase scope and deliverables]

WALK — Expanded [Capability] & [Label]
[1–2 sentences describing the walk phase scope and deliverables]

RUN — The Governed, Agentic Enterprise
[1–2 sentences describing the run phase scope and outcomes]

Contact NeuraFlash to get started today

-----
```

---

### 7. Package / Offering Slide
One slide per offering/quickstart. Always include pricing and timeline.

```
-----

# [Package or Offering Title]

[Optional: Industry or use case subtitle — e.g., "Customer Business Services" or "Health & Life Sciences"]

What's included:
- [Deliverable 1]
- [Deliverable 2]
- [Deliverable 3]
- [Deliverable 4]

Starting at $[PRICE] | [X]+ Week Timeline

[Optional footer: "Includes Architectural Guidance for Scaled Agentic Deployments"]

Contact NeuraFlash to get started today

-----
```

---

### 8. Two-Column Content / Why-Why Slide
Used for "Why [Technology]?" + "What NeuraFlash brings" paired content.

```
-----

## [Slide Title]

**Why [Product/Technology]?**
- [Reason 1]
- [Reason 2]
- [Reason 3]
- [Reason 4]

**What NeuraFlash brings you:**
- [Differentiator 1]
- [Differentiator 2]
- [Differentiator 3]
- [Differentiator 4]

Contact NeuraFlash to get started today

-----
```

---

### 9. Stats / Metrics Dashboard Slide
Used in internal decks, QBRs, and data presentations.

```
-----

[Slide Title or Leave Blank for Visual]

[Metric Label]
[VALUE]
[Descriptor — e.g., "of respondents" or "FY26"]

[Metric Label]
[VALUE]
[Descriptor]

[Metric Label]
[VALUE]
[Descriptor]

[Metric Label]
[VALUE]
[Descriptor]

-----
```

Example:
```
-----

114 Total Responses  |  April 2026

89%
Use AI Daily

~10 hrs
Avg/Week on AI

8.5/10
Avg Comfort Score

-----
```

---

### 10. Numbered Key Takeaways Slide
Used in analytics, executive summary, and report-style decks.

```
-----

Key Takeaways

01
[Bold Header — Short Title]
[1–2 sentence explanation]

02
[Bold Header — Short Title]
[1–2 sentence explanation]

03
[Bold Header — Short Title]
[1–2 sentence explanation]

04
[Bold Header — Short Title]
[1–2 sentence explanation]

05
[Bold Header — Short Title]
[1–2 sentence explanation]

-----
```

---

### 11. Roadmap / Timeline Slide
Used for project roadmaps, phased rollout plans.

```
-----

# Roadmap [Optional: Approach Name]

[Phase 1 Label — e.g., "Mar – Jun '26"]
[Phase 2 Label — e.g., "Jul – Sep '26"]
[Phase 3 Label — e.g., "Oct '26 & beyond"]

**[Phase 1 Theme — e.g., Stabilize]**
[Item] — [Description]
[Item] — [Description]

**[Phase 2 Theme — e.g., Structure]**
[Item] — [Description]
[Item] — [Description]

**[Phase 3 Theme — e.g., Scale]**
[Item] — [Description]
[Item] — [Description]

TARGET OUTCOMES: [↓ or ↑ metric] · [✓ milestone] · [✓ milestone]

-----
```

---

### 12. Options / Decision Slide
Used when presenting alternatives to a client.

```
-----

[Slide Title — e.g., "Path Forward Options"]

**Option A — [Short Label]**
- [Benefit 1]
- [Benefit 2]
- [Benefit 3]

**Option B — [Short Label]**
- [Benefit 1]
- [Benefit 2]
- [Benefit 3]

[Client Name] Decision Required: [Call to action]

-----
```

---

### 13. Team Structure Slide
Used in managed services proposals and project kickoffs.

```
-----

# Current Team / Proposed Team Structure

[Team/Workstream Name] — Lead: [Name]
[Headcount]

[Team/Workstream Name] — Lead: [Name]
[Headcount]

[Summary line — e.g., "Total current headcount: ~24 resources | Managed across 6 delivery workstreams"]

-----
```

---

### 14. RACI Matrix Slide
```
-----

# RACI Matrix

R = Responsible | A = Accountable | C = Consulted | I = Informed
Note: 'A' = single accountable owner per row · Multiple 'R' allowed

| Activity | NeuraFlash | [Client] |
|----------|-----------|---------|
| [Activity 1] | R/A | C |
| [Activity 2] | R | A |

-----
```

---

### 15. Contact / Close Slide
Always the last slide of external or client-facing decks.

```
-----

# [Contact Name 1]

# [contact1@neuraflash.com]

[Title / Role]

# [Contact Name 2]

# [contact2@neuraflash.com]

[Title / Role]

Ping us on Slack or Email Us !!

-----
```

---

## Standard Deck Structures

### External Sales / Overview Deck (10–15 slides)
1. Cover Slide
2. Company Overview (Stats)
3. Timeline / Why We're #1
4. Practice Overview (Value Props)
5. Section Divider: `# Approach`
6. Crawl / Walk / Run
7. Section Divider: `# Quick Starts` or `# Packages`
8. Package Slide(s) (one per offering)
9. Section Divider: `# Demo` (if applicable)
10. Contact / Close Slide

### QBR / Client Business Review (15–25 slides)
1. Cover Slide (`# NeuraFlash & [Client]` + date)
2. Section Divider: `# What We're Working On`
3. Scoped Roadmap by Workstream (Salesforce / MuleSoft / Agentforce / etc.)
4. Effort Overview (hours breakdown)
5. Agentforce Enhancements (if applicable)
6. Section Divider: `# Future Roadmap Work Items`
7. Future (unscoped) items
8. Section Divider: `# NeuraFlash Proposal`
9. Current Team Structure
10. Path Forward Options (Option A / Option B)
11. Proposed Team Structure
12. Roadmap (phased by quarter)
13. RACI Matrix
14. Section Divider: `# Investment Overview`
15. Investment / Pricing Slide

### Proof of Technology / Project Kickoff (10–15 slides)
1. Cover Slide
2. Company Overview
3. Project Overview / Scope
4. Solution Architecture
5. Phase Timeline (Engage → Execute → Evolve)
6. Key Assumptions
7. Team & Contacts

### Internal / Analytics Report (6–10 slides)
1. Cover Slide (stats summary on cover, no H1 title needed)
2. Usage / Frequency Slide (charts described textually)
3. Top Tools / Rankings Slide
4. Activity Breakdown Slide (numbered counts + %)
5. Barriers / Gaps Slide
6. Key Takeaways (numbered 01–06 style)

---

## Generation Instructions

When this skill is invoked:

1. **Gather requirements** by asking:
   - Deck type (sales/QBR/kickoff/internal/analytics)?
   - Topic and audience (internal vs. external)?
   - Specific sections or content to include?
   - Contacts to feature on the close slide?
   - Client name (for QBR/joint decks)?

2. **Generate slide content** using the templates above, following the exact formatting patterns (separators, heading levels, stat formats, numbered takeaways, etc.).

3. **Brand compliance checklist** before outputting:
   - [ ] Cover slide uses correct `# NeuraFlash | [Topic]` format
   - [ ] Company overview stats are verbatim (CSAT 4.9, 500+, 2,525, 2016)
   - [ ] All brand claims use the canonical wording
   - [ ] Package slides include pricing + timeline + CTA
   - [ ] External decks end with a Contact slide
   - [ ] Section dividers use single `# Title` with no body text
   - [ ] Every slide has `-----` before and after

4. **Output format**: Write all slides in the markdown separator format, then offer to create the actual Google Slides file using the Google Drive MCP (`create_file` tool).

5. **Tone guidance**:
   - External sales decks: bold, confident, outcome-focused
   - QBR / client decks: structured, data-backed, action-oriented
   - Internal decks: concise, data-forward, no filler

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
