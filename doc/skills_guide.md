# Guide: Engineering High-Quality Skills

If a Slash Command is a user interface, a Skill is an API designed for both humans and machines. Think of a skill as a "Lego brick" in your automation architecture. If the brick is misshapen, your agents will fail to build anything useful, and your manual workflows will be brittle.

Here is how to engineer a high-quality, reusable skill.

## 1. The "Single Responsibility" Principle

A good skill does one thing and does it perfectly. If your skill is named `manage_jira`, it’s too broad. It should be `create_jira_issue` or `add_comment_to_ticket`.

*   **Atomic Logic**: Don’t combine "Fetch Logs" and "Analyze Logs" into one skill. Make them two separate skills. This allows an Agent to decide if it only needs the fetch part.
*   **Statelessness**: A skill shouldn't rely on "what happened before." It should take all the context it needs from its input parameters.

## 2. Metadata: The "Instruction Manual"

In the era of AI Agents, the description of your skill is just as important as the code. Agents use this metadata to decide which tool to "pick" from their toolbox.

*   **Be Verbose in Descriptions**: Instead of "Gets logs," use "Fetches the last 100 lines of application logs from a specific Kubernetes namespace and service."
*   **Specify Constraints**: If a skill only works for prod environments or has a rate limit, put that in the docstring/metadata.

## 3. Strict Input Schema (The Contract)

A skill must have a rigid, typed interface. Use JSON Schema or Pydantic models to define exactly what the skill expects.

| Requirement | Why it matters |
| :--- | :--- |
| **Strict Typing** | Prevents "TypeErrors" when an Agent passes a string instead of an integer. |
| **Enum Constraints** | If a parameter only accepts `hotfix`, `feature`, or `bug`, define it as an Enum so the caller doesn't guess. |
| **Clear Parameter Names** | Use `deployment_id` instead of `id`. Context is everything in a shared environment. |

## 4. Output for Two Audiences

A skill has two "customers": the next machine in the chain and the human reading the logs.

*   **Machine-Readable (JSON)**: Always return a structured object. This allows an Agent or a script to parse specific fields (like an `incident_id`) to use in the next step.
*   **Human-Readable (Summary)**: Include a summary or message field in your response. If a developer calls this skill, they should see "Successfully restarted 3 pods" rather than a raw array of Kubernetes objects.

## 5. Idempotency & Safety

Since skills are often triggered by automated systems (which might retry on failure), they must be idempotent whenever possible.

*   **The "Check-Before-Do" Pattern**: If a skill is meant to `create_github_repo`, it should first check if a repo with that name exists.
*   **Read-Only by Default**: Clearly tag skills as Read-Only (e.g., `get_metrics`) vs. Side-Effect (e.g., `terminate_instance`). This allows you to apply stricter permissions to dangerous skills.

## 6. Skill Examples

### Debugging: `fetch_sentry_trace`
*   **Input**: `event_id`: string, `include_stack_trace`: boolean
*   **Metadata**: "Retrieves full error details from Sentry. Use this when an Agent detects a recurring exception in the logs."
*   **Pro Tip**: Return the URL to the Sentry UI alongside the raw JSON so a human can jump in.

### On-Call: `get_oncall_engineer`
*   **Input**: `service_name`: string, `schedule_type`: "primary" | "secondary"
*   **Metadata**: "Identifies who is currently carrying the pager for a specific service."
*   **Pro Tip**: Return the user's Slack ID so the calling Agent can automatically @mention them.

## The "Pro Skill" Checklist

> [!IMPORTANT]
> **The Golden Rule**: A skill should be "boring." It should be so predictable and well-documented that an AI can use it without making a mistake 100 times in a row.

- `[ ]` **Validation**: Does it reject bad input before trying to execute?
- `[ ]` **Logging**: Does it log exactly what it’s doing (for auditing)?
- `[ ]` **Timeout**: Does it have a hard execution limit (e.g., 30 seconds) so it doesn't hang the Agent?
- `[ ]` **Authentication**: Does it handle secrets securely (using environment variables/vaults) rather than asking for them in the parameters?
- `[ ]` **Self-Correction**: If the input is slightly off (e.g., "Production" instead of "prod"), does the skill normalize it?
