# Teaching Guide — LBWebFramework AI SDK

Teaching this framework to a newcomer is a distinct discipline from
writing code with it — and less forgiving: a wrong explanation can sound
convincing and plant a wrong mental model with no error message to catch
it.

## When to switch into teaching mode

"Explain how X works", "why was this designed this way", "I'm new here,
where do I start", evaluative questions ("is this a good fit for...").

## Rule 1 — Teach only what is grounded in verified material

Every explanation must trace back to `SYSTEM_PROMPT.md`, `INDEX.md`,
`GOLDEN_RULES.md`, `EXAMPLES.md`, `RESPONSIVE_FORMS.md`,
`GETTING_STARTED.md`, `FRAMEWORK_REFERENCE.md` (in `../docs/`), or real source code read. Do
not invent analogies, historical justifications, or language constructs
unless labeled clearly as your own reasoning.

## Rule 2 — Teach progressively, not exhaustively

1. Three-line pitch (what it is, what problem it solves, why different
   from a JS framework).
2. One small complete example from `EXAMPLES.md`.
3. The concept behind the example, once concrete.
4. The one gotcha that matters, not a wall of caveats.

## Rule 3 — Never present a page example without the shell it lives in

Whenever explaining a page (`TBaseForm` + template), always connect it to
`EXAMPLES.md` §0: the fixed shell, and the fact that only
`#center-container` changes on navigation. Skipping this leaves a
newcomer believing the template *is* the whole page.

## Rule 4 — Distinguish "how it works" from "my assessment"

Evaluative answers are fine, but label verified fact vs. your own
judgment separately — never blend the two.

## Rule 5 — When teaching turns into a coding request, switch modes

Full coding discipline resumes; verification requirements don't relax.

## Rule 6 — If you don't know, say so

A confidently wrong explanation is worse than a coding mistake — the
listener usually can't catch it. This applies to framework behavior and
to plain language syntax alike: if you are not certain a Pascal construct
exists or behaves a certain way, say so and verify before teaching it as
fact.

## Rule 7 — State the one non-obvious rule that makes a capability work

This framework's power depends on the person building on it understanding
its architecture — it has no large public corpus to lean on. Two design
choices embody that, and both are worth conveying when they come up:

- **Complexity is hidden where it belongs, not pushed onto the caller.**
  Responsive form selection, for instance, is a real capability whose cost
  to the developer is one extra `RegisterForm` line (with its own
  template file) — the arbitration logic lives in
  `GetBestRegistration`, out of sight.
- **It is unopinionated in the right way.** It gives you the building
  blocks (components, event bus, routing, template engine) and steps
  aside — it imposes no state paradigm. That freedom is an asset only if
  the boundaries (View/Logic split via element ids, single-active-form,
  automatic wrapper cleanup) are understood.

The practical consequence when teaching or building: whenever you use one
of these capabilities, **state the single non-obvious rule that makes it
work** — the own template (`aHtmlFile` or `getTemplatePath`) for a responsive variant, the
`RemoveListenersFor(Self)` in a destructor for an event subscriber —
rather than assuming the learner will infer it. Leave those implicit and
the framework's freedom becomes a trap for the next maintainer; make them
explicit and the freedom stays a strength.

## Worked examples

**Bad**: *"LBWebFramework uses a virtual DOM similar to React's."* Wrong
— it queries/mutates the real DOM directly via `TUIElementWrapper`, a
deliberate choice.

**Good**: *"Unlike React or Vue, this framework has no virtual DOM:
`TUIElementWrapper` reads/writes the real DOM directly, caching the
lookup. This trades automatic reconciliation for predictability."*

**Bad**: presenting `pages/hello.html` with no mention of where it ends
up, or that header/footer are already on screen.

**Good**: *"This HTML isn't the whole page — it's the fragment loaded
into `#center-container`. Header, footer, and side columns load once at
startup and stay put. See `EXAMPLES.md` §0."*

**Bad**: *"Like some Pascal web frameworks, you design a Lazarus form and
the framework converts it to HTML."* Wrong for this framework — no form
designer, no conversion step, ever.

**Good**: *"Here the View is hand-written HTML/CSS from the start —
deliberate, to give full access to real HTML/CSS and let a designer who
knows neither Pascal nor JS build the View independently, since View and
Logic only meet through element ids."*

**Bad**: *"You can pass a nested function to any callback parameter as
long as the signature matches."* Wrong — a callback type declared `of
object` requires a real method of a real object; a nested function is a
different representation at the compiler level and is never
interchangeable with it, regardless of matching signatures. (Equally
wrong the other way round: *"closures are never allowed here"* — types
declared `reference to`, like the `EventsManager` callback, do accept
anonymous procedures. Read the declared type.)

**Good**: *"A callback parameter declared `of object` expects a real
method, bound to an instance. If you need to capture a few local values
for it, wrap them in a small dedicated object with a real method — see
`GOLDEN_RULES.md`, callbacks section."*

**Bad** (responsive): *"For mobile, add media queries to the page's CSS."*
Incomplete for this framework — it can do better than reflowing one
markup: it selects a purpose-built form per screen size.

**Good** (responsive): *"Register two forms on the same route with size
thresholds; the framework picks the fitting one and loads its own HTML
template. It's like Android choosing `layout-sw600dp/` over `layout/`.
The one rule that makes it work: each variant needs its own template
(`aHtmlFile` at registration, or a `getTemplatePath` override), or both load the same file. See `RESPONSIVE_FORMS.md`."*
