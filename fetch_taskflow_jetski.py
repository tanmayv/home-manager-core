import json
import re
import subprocess

USER_EMAIL = "tanmayvijay@google.com"
WORKSPACE_ID = "87769"

def main():
    prompt = (
        f"Fetch TaskFlow details for tasks assigned to {USER_EMAIL} in current iteration of workspace {WORKSPACE_ID}. "
        f"Return the response as a JSON object containing a list of all planned issues in the current iteration with their 'issue_id', 'status', and 'eta_days'. "
        f"Return ONLY the raw JSON object so I can parse it directly using json.loads()."
    )
    
    print("Querying TaskFlow via jetski...")
    try:
        # Use jetski -prompt="[prompt]"
        result = subprocess.run(
            ["jetski", f"-prompt={prompt}"],
            capture_output=True,
            text=True,
            check=True
        )
        content = result.stdout.strip()
        print("\n--- Raw Response ---")
        print(content)
        
        # Try to parse as JSON
        # Sometimes LLMs wrap JSON in ```json ... ``` tags. Let's clean that if present.
        json_str = content
        if content.startswith("```json"):
            match = re.search(r"```json\s*(.*?)\s*```", content, re.DOTALL)
            if match:
                json_str = match.group(1)
        
        try:
            data = json.loads(json_str)
            print("\n--- Parsed TaskFlow Details ---")
            
            # Expecting a list of dictionaries, or a dictionary containing a list of issues
            issues = data if isinstance(data, list) else data.get("issues", [])
            
            if not issues:
                 print("No issues found in response or invalid format.")
                 return
                 
            print(f"{'Issue ID':<15} | {'Status':<15} | {'ETA (Days)':<10}")
            print("-" * 45)
            for issue in issues:
                issue_id = issue.get("issue_id", "N/A")
                status = issue.get("status", "N/A")
                eta_days = issue.get("eta_days", "N/A")
                print(f"{str(issue_id):<15} | {str(status):<15} | {str(eta_days):<10}")
                
        except json.JSONDecodeError as e:
            print(f"\nFailed to parse response as JSON: {e}")
            print("Make sure the prompt forces the model to return ONLY valid JSON.")
             
    except subprocess.CalledProcessError as e:
        print(f"Error calling jetski: {e}")
        print(f"Stderr: {e.stderr}")

if __name__ == "__main__":
    main()
