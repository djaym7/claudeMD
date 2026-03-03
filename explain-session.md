# Explain Session — Interactive Code Walkthrough

You are being asked to walk the user through everything that was built or changed in this session. Not a summary — a **teaching walkthrough** that starts from the entry point and traces through every component, one step at a time.

## Step 1: Analyze the Session

Review the full conversation history silently. Identify:
- Every file created, modified, or significantly discussed
- The entry point / caller function (the thing the user would actually invoke)
- The dependency chain: what calls what, what imports what
- The architectural layers (e.g., API → orchestration → processing → utilities)
- Key decisions made and why

Build a mental map of the system before you start explaining anything.

## Step 2: Generate the Architecture Diagram

Create an ASCII architecture diagram showing ALL components and their relationships. Use box-drawing characters for a clean look:

```
┌─────────────────────────────────────────────────┐
│                  SYSTEM NAME                     │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌──────────┐      ┌──────────┐                 │
│  │ module_a  │─────►│ module_b  │                │
│  └──────────┘      └─────┬─────┘                │
│                          │                       │
│                    ┌─────▼─────┐                 │
│                    │ module_c  │                 │
│                    └───────────┘                 │
│                                                  │
└─────────────────────────────────────────────────┘
```

If `mermaid_preview` MCP tool is available and works (test it — if it errors with ENOENT or similar, it means we're in a headless terminal), use mermaid to generate a proper diagram AND show the ASCII version inline. If mermaid fails, ASCII only.

Display this diagram first and say:

> "Here's the full picture of what we built. I'll walk you through each piece starting from [entry point]. At each step I'll mark where we are."

Then use AskUserQuestion: "Ready to start the walkthrough?" with options "Yes, let's go" and "I have questions first".

## Step 3: Walk Through Each Component

For each component in the dependency chain, starting from the entry point:

### 3a. Show Position

Re-display the architecture diagram with the current component marked. Use `◀◀◀ YOU ARE HERE` or visually distinguish it:

```
  ┌──────────────────┐
  │ ★ entry_point()  │ ◀◀◀ YOU ARE HERE
  │   file: main.py  │
  └────────┬─────────┘
           │
  ┌────────▼─────────┐
  │   processor()    │
  │  file: proc.py   │
  └────────┬─────────┘
           │
  ┌────────▼─────────┐
  │    helpers()     │
  │  file: util.py   │
  └──────────────────┘
```

### 3b. Explain the Component

For each component, explain:
1. **What it is**: File path, function/class name, its role in the system
2. **Signature**: What it takes as input, what it returns
3. **How it works**: Step through the logic in plain language. Reference specific lines/code where helpful — use short inline code snippets, not full file dumps
4. **Why it's designed this way**: Key decisions, trade-offs, alternatives considered (if discussed in session)
5. **What it calls next**: Transition to the next component in the chain

Keep explanations conversational and concrete. Use the user's own terminology from the session where possible. No filler, no fluff.

### 3c. Check Understanding

After each component, use AskUserQuestion:

**Question**: "Got it? [component_name]"

**Options**:
- "Got it, next" — proceed to the next component
- "Explain more" — go deeper into this component, show more code, clarify
- "Show me the code" — display the actual code for this component with inline annotations

If "Explain more": drill down further, then re-ask.
If "Show me the code": read the file and display the relevant section with line numbers and brief inline comments, then re-ask.

## Step 4: Backtrack

After all components have been explained individually, backtrack to the big picture:

1. Re-display the full architecture diagram (no highlight this time — all components are now explained)
2. Trace through a **complete request flow** end-to-end: "When you call X with Y, here's exactly what happens: first A does ..., then B takes that and ..., then C ..., and you get back Z."
3. Call out any non-obvious interactions: error handling paths, edge cases, fallback behavior, configuration that changes behavior

## Step 5: Wrap Up

End with:
- **Quick reference**: A compact cheat-sheet — entry function signature, key config values, important file paths
- **Edge cases to remember**: Anything tricky or easy to forget

Then ask: "Anything else you want me to dig into?"

## Style Rules

- Talk like you're explaining to a smart colleague, not writing docs
- Use the user's own words and terminology from the conversation
- Short paragraphs, heavy use of code snippets and bullet points
- Every diagram should be copy-pasteable (clean ASCII, no broken characters)
- When showing code, show ONLY the relevant 5-15 lines, not entire files
- Reference file paths as `file.py:42` format for easy navigation
- If a component is trivial (e.g., a config dict, a re-export), say so and move fast — don't over-explain simple things
- Spend more time on the complex/interesting parts where the real logic lives
