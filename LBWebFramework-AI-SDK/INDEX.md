# Routing Index — LBWebFramework AI SDK

## When the user wants to learn or understand, not to build

If the request is "explain X", "why does this work this way", "I'm new
here, where do I start", or any evaluative question about the framework
("is this a good fit for..."), switch to the discipline in
`TEACHING_GUIDE.md` before answering. It is stricter than a normal
explanation would be, precisely because a confidently wrong explanation
is harder for the listener to catch than a coding mistake would be.

## When the user asks for an example directly

If the user's request is phrased as "show me an example of X" / "how do I
use X" / "give me a minimal Y", **check `EXAMPLES.md` before writing
anything from scratch.** It contains a small library of verified, working
snippets for the most commonly requested subsystems. If the requested
topic isn't covered there, say so explicitly, then build the example by
reading the relevant section of `docs/FRAMEWORK_REFERENCE.md` and — where
it doesn't fully specify a signature or behavior — verifying against the
real source before presenting the example as correct (see
`SYSTEM_PROMPT.md`, rule 1).

**Mandatory addition whenever the example includes a page (a `TBaseForm`
and its HTML template):** always explain, briefly, how that fragment fits
into the fixed application shell — see `EXAMPLES.md` §0. Presenting a page
template in isolation, without connecting it to the shell/injection
mechanism, is a common way to leave the single most important structural
fact about this framework unstated, and is exactly the kind of gap
`TEACHING_GUIDE.md` exists to prevent.

## Task routing table

| If your task is... | Read first | Then, if still needed |
|---|---|---|
| Starting a project / first page | `../docs/GETTING_STARTED.md` | `EXAMPLES.md` §0–§1 |
| Understanding the application shell (`index.html`, header/footer/columns) | `EXAMPLES.md` §0 | `FRAMEWORK_REFERENCE.md` §1, §4, §5 |
| Building a page component | `EXAMPLES.md` §1 | `FRAMEWORK_REFERENCE.md` §2 |
| Registering routes, guarding pages, history behaviour | `FRAMEWORK_REFERENCE.md` §3 | `RESPONSIVE_FORMS.md` for size variants |
| Several applications on one server (`aBasePath`, `loadNeededCSS(aBasePath)`, `BasePath`) | `EXAMPLES.md` §6 | `FRAMEWORK_REFERENCE.md` §2–§3 |
| Making two components communicate without knowing about each other | `EXAMPLES.md` §2 | `GOLDEN_RULES.md`, event-dispatch section |
| Rendering HTML from data (`{{ }}` templates, partials, loading template files) | `EXAMPLES.md` §7 | `Common/TemplateEngine/TemplateEngine.md`, `FRAMEWORK_REFERENCE.md` §8 |
| Long lists (infinite scroll) | `EXAMPLES.md` §7 | `FRAMEWORK_REFERENCE.md` §9 — row template root must be a `<div>` |
| Building a hierarchical tree with actions on nodes | `EXAMPLES.md` §3 | `GOLDEN_RULES.md`, tree component section — check the context-menu note before assuming a click-selection event exists |
| Data grids | `FRAMEWORK_REFERENCE.md` §12 (`uJSTabulator`; needs the Tabulator JS library) | — |
| Calling a backend HTTP API | `EXAMPLES.md` §4 (REST request pattern) | `FRAMEWORK_REFERENCE.md` §7; check whether the project already has its own REST client wrapper (path-based APIs are common and typically require one distinct from the framework's default RPC-style base class) |
| Reading server error messages (401/403/409…) | `EXAMPLES.md` §4 (`HttpStatus`, `Answer`) | `GOLDEN_RULES.md`, backend communication section |
| Building a login form / calling a session endpoint | `EXAMPLES.md` §5 (login form) | The matching backend session endpoint is in the backend SDK, not in this package |
| Real-time messages from the server | `FRAMEWORK_REFERENCE.md` §13 (`WSManager`) | `GOLDEN_RULES.md`, event-dispatch section |
| Local persistence (IndexedDB) / caching | `FRAMEWORK_REFERENCE.md` §14 | — |
| Writing a callback that needs to capture local state (an id, a status, etc.) | `GOLDEN_RULES.md`, callbacks section | Check the callback type first: `of object` needs a real method, `reference to` accepts an anonymous procedure |
| A page that must look different per screen size (mobile vs desktop layout) | `RESPONSIVE_FORMS.md` | Register more than one form per route; give each variant its own template (`aHtmlFile` or `getTemplatePath`) |
| Freeing / lifecycle: what the framework cleans up vs. what you must free | `GOLDEN_RULES.md`, "Memory and object lifecycle" section | — |
| Modal dialogs | `FRAMEWORK_REFERENCE.md` §10 | `ShowMessage(aTitle, aMessage, [aMsgType])`: title **and** message are required; there is no Yes/No dialog |
| Colours, themes, CSS variables | `FRAMEWORK_REFERENCE.md` §15 | — |

## The rule that overrides all the above

If a task requires assuming a language construct, a framework behavior,
or a call-site consequence that is **not explicitly documented** in the
section you were routed to: verify against the real source, or ask. Do
not proceed on a plausible guess. See `SYSTEM_PROMPT.md`, rules 1–3.
