# Guide: Engineering High-Quality Slash Commands

A great slash command is like a well-designed CLI tool: it should be discoverable, predictable, and quiet. Because slash commands often live in shared channels (Slack, Discord, Teams), a poorly designed one can quickly become "chat pollution" or a source of friction for your team.

Here is the blueprint for engineering a high-quality slash command.

## 1. The Naming Convention

The command name is your first (and sometimes only) documentation. It needs to be a verb-noun pair or a very clear action.

*   **Avoid ambiguity**: Don't use `/run` (Run what?). Use `/deploy-service`.
*   **Keep it short**: `/check-system-health-status-now` is a workout for the thumbs. Use `/health-check`.
*   **Use subcommands**: For complex tools, use a primary command with sub-actions to keep the namespace clean.
    *   **Bad**: `/k8s-get-pods`, `/k8s-describe-node`
    *   **Good**: `/k8s pods`, `/k8s node`

## 2. Parameter Design

Parameters should be intuitive. If a user has to look up a manual to use your slash command, the UX has failed.

*   **Required vs. Optional**: Put the most critical data first.
    *   `/ticket create "Title" [Priority] [Assignee]`
*   **Autocomplete is Non-Negotiable**: In 2026, if your command doesn't provide a dropdown for "Service Name" or "Environment," you’re forcing users to guess strings.
*   **Default Values**: If the environment isn't specified, default to staging or development (never prod!).

## 3. The "Three-Second Rule" (Response UX)

Chat platforms usually have a strict timeout (often 3000ms). If your backend logic takes longer (e.g., querying a heavy database), your command will error out.

*   **Immediate Acknowledgment**: Send an ephemeral (only visible to the user) message immediately: "Got it! I'm fetching the logs for auth-service now..."
*   **The "Thinking" State**: Use loading indicators or progress bars if the platform supports them.
*   **Deferred Response**: Post the final result as a follow-up once the heavy lifting is done.

## 4. Response Formatting

Don't just dump a JSON blob into the channel. Format the output for human eyes.

| Element | Best Practice |
| :--- | :--- |
| **Status** | Use emojis for "At-a-glance" updates (✅, ⚠️, 🚨). |
| **Data** | Use Markdown tables or Code Blocks for logs/traces. |
| **Context** | Always repeat the input parameters in the output so others know what was requested. |
| **Actions** | Include "Buttons" for the next logical step (e.g., a "Retry" or "Link to Jira" button). |

## 5. Error Handling with Empathy

When a command fails, "Internal Server Error" is useless. A good command helps the user fix the mistake.

*   **Bad**: `Error: Invalid input.`
*   **Good**: `⚠️ I couldn't find a service named "auth-servie". Did you mean "auth-service"? Try running /services list to see all options.`

## 6. Real-World Examples

### On-Call: `/incident`
*   **Action**: `/incident declare --severity p0 --summary "API Latency spike"`
*   **Good UX**: The command automatically creates a Zoom room, a Jira ticket, and a dedicated Slack channel, then posts the links back to the user.

### Debugging: `/logs`
*   **Action**: `/logs tail --service search-api --lines 20`
*   **Good UX**: Instead of flooding the channel, it sends an ephemeral message with a "View in Datadog" button for deeper diving.

### Software Dev: `/pr`
*   **Action**: `/pr status --mine`
*   **Good UX**: Returns a clean list of your open Pull Requests with their current CI/CD status (Green/Red) and a "Nudge Reviewers" button.

## Summary Checklist

- `[ ]` Is the name a clear Action?
- `[ ]` Does it use Autocomplete for dynamic inputs?
- `[ ]` Does it respond within 3 seconds (or send an "Acknowledged" state)?
- `[ ]` Is the final output Scannable (using bolding and emojis)?
- `[ ]` Does the error message provide a Path to Success?
