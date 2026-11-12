# {{PROJECT_NAME}} — Product Requirements

> **Rule zero — v1 is an MVP.** Every feature in this doc that's tagged `in-MVP` must serve a pillar outcome AND be the smallest version of itself that still delivers that outcome. Default verdict on new proposals is POST-MVP. Make us argue features INTO v1, not out of it.

## Vision

{{Vision paragraph — what this product is, who it's for, why it matters. Replace this with the actual pitch when you instantiate the template.}}

## Target user

{{Who specifically. Not "everyone." A concrete persona.}}

## Pillars

Every MVP feature must serve one of these. Anything else gets cut to post-MVP. Replace these with the actual pillars for your project — typically 2–4 of them.

### Pillar 1 — {{Name}}

{{One-sentence description of the core value this pillar delivers.}}

**Features:**
- [ ] {{Feature 1}}
- [ ] {{Feature 2}}

### Pillar 2 — {{Name}}

{{Description.}}

**Features:**
- [ ] {{Feature 1}}

### Pillar 3 — {{Name}}

{{Description.}}

**Features:**
- [ ] {{Feature 1}}

## Feature specs

Detailed specs for committed MVP features. The pillar checklists above are the commitments; entries here are the implementation contracts. Add one block per feature using the format below.

### Feature: {{feature-name}}
Pillar: {{which pillar}}
Status: in-MVP | post-MVP | cut

**User story:**
As a {{user}}, I want {{capability}} so that {{outcome}}.

**Acceptance criteria:**
- [ ] {{criterion 1}}
- [ ] {{criterion 2}}
- [ ] Empty state: {{what shows}}
- [ ] Offline: {{behavior}}
- [ ] Error: {{behavior}}

**Out of scope (cut from this feature):**
- {{thing 1}}
- {{thing 2}}

---

## Out of scope for MVP (post-MVP backlog)

Things deliberately deferred. Anything that lives here cannot be argued back into MVP without an explicit re-scoping discussion.

- {{Item 1}}
- {{Item 2}}

## Constraints

- **Solo build, ~{{N}} week target** to first TestFlight / internal release.
- **Backend stays thin** — one Rust Worker (`rust/api`), one D1 database. A new endpoint needs a feature in this PRD behind it.
- **Near-zero run cost.** Workers paid plan base only at MVP scale: every D1 query is indexed (rows read are billed), lists are paginated, Riverpod caches responses.
- **{{Other project-specific constraint}}**

## Open questions

Track here. Resolve before implementation, never during.

- [ ] {{Question 1}}
- [ ] {{Question 2}}
