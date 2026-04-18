# Guide: Building Good Agents

Building an Agent is a major step up from writing a script or a command. While a skill is a "tool," an agent is the craftsman who knows when and how to use those tools to solve a problem.

Think of an agent as a digital teammate. If you give it a vague goal like "Find out why the API is slow," it doesn't just run a command; it reasons, investigates, and reports back.

## 1. The Reasoning Loop (The "Brain")

A good agent doesn't just fire off actions in a vacuum. It follows a loop—often called ReAct (Reasoning + Acting). Without this, your agent is just a glorified, unpredictable script.

*   **Thought**: The agent analyzes the current state ("I see high latency in the us-east-1 region").
*   **Action**: It selects a Skill to execute ("I will call `get_k8s_metrics`").
*   **Observation**: It reads the output of that skill ("CPU usage is at 98% on three pods").
*   **Repeat**: It updates its thought process based on the observation until the goal is met.

## 2. The "Box of Tools" (Skill Integration)

An agent is only as good as the skills you give it.

*   **Don't over-provision**: If an agent has 100 tools, it might get "confused" or pick the wrong one. Curate a specific "Toolbox" for specific agents (e.g., a "Database Agent" shouldn't have "GitHub PR" skills).
*   **Error feedback**: When a skill fails, the agent needs to see the reason for the failure so it can try a different approach.

## 3. Context & Memory Management

An agent needs to remember what it did two minutes ago.

*   **Short-term Memory**: It tracks the current "conversation" or investigation steps.
*   **Long-term Memory**: It knows about past incidents or your specific architectural patterns (usually handled via a RAG/Vector database).
*   **The "Context Window"**: Be careful not to flood the agent with irrelevant logs, or it will lose the "thread" of its original goal.

## 4. Guardrails and "Human-in-the-Loop"

The more autonomous an agent is, the more dangerous it can be.

*   **Confirmation Gates**: For "Side-Effect" skills (like `delete_namespace` or `restart_server`), the agent must ask a human for a "thumbs up" before proceeding.
*   **Negative Constraints**: Explicitly tell the agent what it cannot do. For example: "Do not attempt to modify production database schemas without a human reviewer present."

## 5. Agent Personas in Dev/Ops

| Agent Type | Mission Statement | Key Skills |
| :--- | :--- | :--- |
| **The Triage Agent** | "Identify the root cause of incoming alerts before a human wakes up." | `fetch_logs`, `check_deployment_history`, `query_metrics`. |
| **The Review Agent** | "Review every PR for security flaws and style guide compliance." | `read_repo_file`, `lint_code`, `search_security_db`. |
| **The Refactor Agent** | "Update all instances of a deprecated library across 10 microservices." | `find_and_replace`, `create_github_branch`, `run_tests`. |

## 6. Anatomy of a Good Agent Prompt

When "programming" an agent via a system prompt, follow this structure:

*   **Role**: You are a Senior Site Reliability Engineer.
*   **Objective**: Your goal is to minimize Mean Time to Resolution (MTTR) for API-related incidents.
*   **Standard Operating Procedure**:
    1.  Always check the deployment log first to see if a change triggered the event.
    2.  If CPU is high, check for a memory leak before suggesting a horizontal scale.
*   **Constraints**: Do not execute any write actions on the database. Always summarize your findings in a table format.

## The "Agent Readiness" Checklist

- `[ ]` **Clear Goal**: Does the agent have a defined "definition of done"?
- `[ ]` **Curated Toolbox**: Are the available skills relevant and well-documented?
- `[ ]` **Safety First**: Are there "Ask for Permission" steps for destructive actions?
- `[ ]` **Personality/Tone**: Does it communicate in a way that fits your team's culture? (e.g., "Insightful and direct" vs. "Detailed and verbose").
- `[ ]` **Observability**: Can you see the agent's "Thoughts"? (Crucial for debugging why an agent went off the rails).
