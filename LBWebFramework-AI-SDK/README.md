# LBWebFramework — AI SDK

A small self-contained kit letting an AI coding assistant — with zero
prior exposure to LBWebFramework — become productive quickly and safely:
without inventing plausible-sounding APIs, or plausible-sounding language
constructs, that don't actually exist.

## Why this exists

LBWebFramework has no Stack Overflow presence, no large tutorial corpus.
Any AI approaching it cold has no statistical shortcut — only read the
real source, or guess. This SDK makes the first the default and the
second something the assistant refuses without flagging.

**In practice**: open a coding assistant, point it at this repo, and ask
*"Give me an example of using LBLogger." "How do I make two components
talk?" "Why doesn't this framework use a virtual DOM?" "Why is the View
plain HTML/CSS instead of a converted Lazarus form?"* — answerable on the
spot, whether you want code or an explanation.

One architectural choice worth knowing upfront: unlike some Pascal web
frameworks that convert a Lazarus/Delphi form into HTML, LBWebFramework
keeps the View as hand-written HTML/CSS — see `GOLDEN_RULES.md` for why.

## What's in this folder

| File | Purpose |
|---|---|
| `SYSTEM_PROMPT.md` | Load first, verbatim. Non-negotiable behavioral rules. |
| `INDEX.md` | Routing table: task → document. |
| `GOLDEN_RULES.md` | Condensed conventions and known gotchas, incl. memory/lifecycle. |
| `EXAMPLES.md` | Verified working snippets. |
| `RESPONSIVE_FORMS.md` | How to serve a different form/HTML per screen size. |
| `TEACHING_GUIDE.md` | How to explain the framework responsibly. |
| `../docs/GETTING_STARTED.md` (companion) | 15-minute hello-world guide. |
| `../docs/FRAMEWORK_REFERENCE.md` (companion) | Full reference, every `Common/` unit, written from the source. Replaces the Technical Manual (`.docx`/`.pdf`). |
| `../docs/CHANGELOG.md` (companion) | Behavioural changes to `Common/`. |

**Source of truth.** Real source beats every document here. If this SDK, the
reference and the code disagree, trust the code and report the discrepancy
(`SYSTEM_PROMPT.md`, rule 9).

## How to use it

Paste `SYSTEM_PROMPT.md` into your assistant's system prompt, and make
sure `INDEX.md`, `GOLDEN_RULES.md`, `EXAMPLES.md`, `RESPONSIVE_FORMS.md`,
`TEACHING_GUIDE.md` and `../docs/FRAMEWORK_REFERENCE.md` are reachable in its context.

## What "AI-ready" does not mean

Not "no human review needed." An assistant following these rules will
occasionally need to deduce something undocumented — and should say so
plainly, show its reasoning, and treat it as needing human confirmation.
