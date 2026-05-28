# NeuraFlash Brand Reference

Single source of truth for colors, typography, canonical stats, and brand
claims. Skills, slash commands, and subagents that produce client-facing
content reference this file rather than hard-coding values.

---

## Colors

| Role                                          | Hex       |
|-----------------------------------------------|-----------|
| Primary Dark Navy (backgrounds, dividers)     | `#1A1A2E` |
| Primary Orange/Coral (accents, CTAs)          | `#FF6B35` |
| White (text on dark backgrounds)              | `#FFFFFF` |
| Light Gray (content slide backgrounds)        | `#F5F5F5` |
| Dark Gray (body text on light backgrounds)    | `#333333` |
| Teal/Cyan (secondary accent)                  | `#00B4D8` |

## Typography

- **Headings**: Google Sans Bold (fallback: Montserrat Bold)
- **Body**: Google Sans Regular (fallback: Open Sans Regular)
- **Stats / Numbers**: Bold, oversized numerals for emphasis

## Standard brand stats — use verbatim

| Metric                              | Value          |
|-------------------------------------|----------------|
| CSAT                                | 4.9 (FY26)     |
| Employees                           | 500+           |
| Certifications & Accreditations     | 2,525          |
| Partner Since                       | 2016           |

## Canonical brand claims — use exactly as written

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

## Update policy

Change these values in **one place only** (this file). Any skill that
hard-codes a stat must be refactored to reference this file instead.
Reviewers should reject PRs that duplicate brand values inside skill bodies.
