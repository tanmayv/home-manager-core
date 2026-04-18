# Guide: Slash Commands, Skills, and Agents

This guide helps you decide which path to take based on the complexity, autonomy, and context of your task.

## Core Definitions

*   **Slash Command**: A direct trigger for a specific, stateless action. You provide the input; it provides the immediate output.
*   **Skill**: A modular capability (a "tool") that can be called by a larger system. It usually does one thing very well, like fetching data or updating a record.
*   **Agent**: An autonomous orchestrator. It uses "reasoning" to decide which skills to call, handles multi-step workflows, and maintains context over time.

## The Decision Tree

To find your answer, ask yourself these three questions:

1.  **Is the input and output predictable every single time?**
    *   **YES**: Use a **Slash Command**. If you just need to `/release-notes v1.2.0`, don't overcomplicate it.
    *   **NO**: Move to Question 2.

2.  **Does this task need to be part of a larger, smarter workflow?**
    *   **YES**: Build a **Skill**. You want this logic to be "pluggable" so an AI or a CI/CD pipeline can trigger it when needed.
    *   **NO**: Stick to a **Slash Command**.

3.  **Does the task require "thinking," multi-step investigation, or follow-ups?**
    *   **YES**: You need an **Agent**. If the process is "Investigate why the DB is slow and fix it," that’s an Agent's job.
    *   **NO**: It's a **Skill**.

## Scenarios in the Wild

| Feature | Slash Command | Skill | Agent |
| :--- | :--- | :--- | :--- |
| **Best For** | Routine, manual triggers. | Reusable, atomic actions. | Complex, goal-oriented tasks. |
| **On-Call Example** | `/ack-incident <id>` | `Get-Logs-From-Datadog` | "Triage this P0 incident and find the root cause." |
| **Dev Example** | `/format-code` | `Create-Jira-Ticket` | "Review this PR and check for security vulnerabilities." |
| **Debugging** | `/tail-logs --service-api` | `Query-Sentry-Errors` | "Find out why users in Europe are seeing 500 errors." |

## When to Choose What (Deep Dive)

### 1. The Slash Command (The "Do It Now" Button)

Use this when you have a human in the loop who knows exactly what they want. It’s perfect for lowering friction for common tasks.

*   **Debugging Example**: `/check-pod-status` — You just want the raw data right now in your chat thread.

> [!TIP]
> If your slash command starts requiring 5+ arguments, it’s probably time to turn it into an Agent-led interaction.

### 2. The Skill (The "Atomic Unit")

Think of a Skill as a function-as-a-service. It doesn't "decide" when to run; it just waits to be called.

*   **Software Dev Example**: A skill that fetches the documentation for a specific API. An Agent might use this skill, or you might trigger it via a command, but the logic remains isolated and reusable.

> [!NOTE]
> It's the building block of everything else. You can't have a smart Agent without a library of solid Skills.

### 3. The Agent (The "Digital Teammate")

An Agent is for when the "how" is fuzzy but the "goal" is clear. It uses a loop of Thought → Action → Observation.

*   **On-Call Example**: An incident occurs. The Agent (1) looks at the alert, (2) uses a Skill to fetch logs, (3) uses another Skill to check recent deployments, and (4) summarizes the findings for the human.
*   **Debugging Example**: "I'm getting a `NullPointerException` in the auth service." The Agent explores the codebase, looks at the stack trace, and suggests a specific fix.

> [!IMPORTANT]
> **The Golden Rule**: Start with a Skill. Once you have the skill, it’s easy to wrap it in a Slash Command for quick manual use, or hand it over to an Agent for autonomous orchestration. Don't build an Agent if a simple command will save you the same amount of time without the "hallucination" risk.
