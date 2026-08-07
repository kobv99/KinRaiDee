# ADR-0001 — CTO Takeover: Preserve Foundation, Reset Roadmap

- Status: Accepted
- Date: 2026-08-07
- Baseline branch: `main`
- Baseline commit: `9edeac3f408c4ebfaffdb6327abef2fd0b85131c`

## Context

KinRaiDee already contains substantial engineering assets: a canonical ingredient domain, transaction-backed Pantry/History/Shopping persistence, recipe compatibility and recommendation services, and a local-first Flutter application. The takeover audit found that these foundations are directionally aligned with the current KinRaiDee constitution, while product completeness, launch coverage, runtime semantic migration, mobile readiness, instrumentation, and repository governance remain incomplete.

The principal failure mode is therefore not a bad foundation. It is sequencing: engineering breadth and taxonomy coverage have advanced faster than the end-to-end user outcome.

## Decision

KinRaiDee will **not** restart from zero.

We will preserve the valid foundations and supersede the previous feature-first roadmap with a constitution-aligned execution order:

1. Governance and trustworthy baseline.
2. Data-truth integrity.
3. Recipe schema readiness before mass content scaling.
4. Close the full Pantry → Recommend → Cook → Reconcile → Shopping loop.
5. Build useful launch coverage around a deliberately limited ingredient set.
6. Add product instrumentation and observe real behaviour.
7. Run a closed beta before major AI, cloud, community, or broad taxonomy expansion.

## Architectural invariants

The following are retained as non-negotiable design constraints unless a later ADR explicitly replaces them:

- Canonical Ingredient identity is the cross-feature ingredient truth.
- Ambiguous or unknown ingredient identity must fail closed rather than be guessed silently.
- Durable inventory mutations go through the transaction/write boundary; presentation code does not bypass it.
- Pantry, Cooking History, and Shopping remain transactionally consistent.
- Recommendation ranking and inventory truth must remain deterministic and inspectable. AI may extract, explain, or propose; it must not silently redefine durable truth.
- Local-first remains the default product architecture. Cloud services are introduced only when they solve a proven product requirement.
- Product Acceptance and Engineering Acceptance are separate gates. Neither can silently override a failure in the other domain.

## Immediate priorities

### P0 — CTO-0 Governance Baseline

- Establish CI for format, analyze, tests, and web build.
- Require PR-based integration into `main`.
- Protect `main` and require the quality gate before merge.
- Treat the baseline commit above as the takeover reference point.
- Inventory stale branches/PRs and explicitly supersede or rebase them instead of allowing parallel historical roadmaps to drift.

### P0 — Truth Integrity

- Resolve Issue #22: runtime Pantry canonicalization must not bypass semantic migration rules.
- Add regression coverage for stale-schema runtime add/edit paths.
- Resolve known compatibility/taxonomy truth defects before expanding taxonomy breadth.

### P1 — Recipe Schema v2

Before mass recipe expansion, define first-class structures for the data that the product constitution requires, including structured cooking steps and explicit extensibility for equipment, allergens/safety, storage/provenance, and future nutrition data. Legacy recipe data may remain readable during migration, but newly curated launch content must follow the new contract.

### P1 — Core Loop Completion

A release candidate is not product-complete until one household action can complete the entire loop:

`Pantry → Recommendation → Cooking → Usage confirmation → Durable Pantry update → Shopping reconciliation/Undo`

### P1 — Launch Coverage

Do not target all selectable taxonomy nodes at once. Select a launch ingredient set based on common household use and make recommendation/cooking coverage materially useful for that set. Expand using observed search, Pantry, and no-result evidence.

## Frozen scope until the core gates pass

The following are deferred unless an evidence-backed exception is approved:

- large AI chat surface
- community/social features
- broad cloud backend build-out
- smart-appliance integrations
- advanced nutrition
- mass-generated recipe expansion
- major taxonomy expansion
- full application UI rewrite
- microservice decomposition

## Engineering operating model

- **Claude — Principal Engineer:** primary implementation, tests, refactors, and technical evidence.
- **Codex — Secondary Engineer / Independent Reviewer:** adversarial review, edge cases, migration/concurrency checks, regression analysis, and secondary implementation where useful.
- **CTO:** architecture, technical priorities, acceptance gates, and stop authority for integrity/security/architecture failures.
- **CEO/Product:** product direction and Product Acceptance. Product approval does not convert a technical failure into a pass; technical approval does not justify a feature without product value.

## Definition of CTO-0 complete

CTO-0 is complete only when:

- CI executes automatically on pull requests that affect the mobile application.
- `main` is protected and the quality gate is required before merge.
- the current baseline is documented and reproducible.
- open historical PRs are classified as active, superseded, or requiring rebase.
- Issue #22 has an approved remediation plan and regression criteria.
- no new feature phase starts by bypassing these gates.

## Consequences

This decision intentionally slows feature count in the short term. In exchange, it reduces migration debt, prevents unreliable canonical data from propagating, and changes the project success metric from "how many subsystems exist" to "whether a user can repeatedly complete the core household food workflow with trustworthy state."