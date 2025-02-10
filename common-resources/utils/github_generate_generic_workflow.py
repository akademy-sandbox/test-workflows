import argparse
import yaml
import subprocess
import datetime
import os

# File paths (current directory)
#CONFIG_FILE = "automation_config.yml"
#TEMPLATE_FILE = "automation-workflow-template.yml"
#OUTPUT_FILE = "generic_workflow.yml"

def load_yaml(file_path):
    """Loads a YAML file"""
    with open(file_path, "r") as file:
        return yaml.safe_load(file)

def load_template(file_path):
    """Loads the workflow template"""
    with open(file_path, "r") as file:
        return file.read()

def generate_schedule_section(environments):
    """Generates schedule section dynamically (preserves order, removes empty entries)"""
    schedule_entries = [
        f"    - cron: \"{env['cron_schedule']}\""  # 4-space indentation for proper YAML formatting
        for env in environments if env.get("cron_schedule")
    ]
    return "  schedule:\n" + "\n".join(schedule_entries) if schedule_entries else ""

def get_default_value(options):
    """Returns the first option as the default (preserves order)"""
    return options[0] if options else ""

def generate_workflow(config, template):
    """Generates the generic workflow for all applications"""
    
    applications = [app["name"] for app in config["applications"]]
    default_application = get_default_value(applications)

    automation_tasks = [task["name"] for app in config["applications"] for task in app["automation_tasks"]]
    default_automation_task = get_default_value(automation_tasks)

    actions = [action for app in config["applications"] for task in app["automation_tasks"] for action in task["actions"]]
    default_action = get_default_value(actions)

    environments = [env["name"] for app in config["applications"] for env in app["environments"]]
    default_environment = get_default_value(environments)

    environment_types = [env["type"] for app in config["applications"] for env in app["environments"]]
    default_environment_type = get_default_value(environment_types)

    target_servers = [server for app in config["applications"] for env in app["environments"] for server in env.get("target_servers", [])]
    default_target_server = get_default_value(target_servers)

    target_dbs = [f"{db['host']}:{db['port']}:{db['dbname']}" for app in config["applications"] for env in app["environments"] for db in env.get("target_db", [])]
    default_target_db = get_default_value(target_dbs)

    workflow_name = f"Generic Automation Workflow"

    schedule_section = generate_schedule_section([env for app in config["applications"] for env in app["environments"]])

    workflow_content = template.replace("{WORKFLOW_NAME}", workflow_name)
    workflow_content = workflow_content.replace("{APPLICATIONS}", str(applications))
    workflow_content = workflow_content.replace("{DEFAULT_APPLICATION}", default_application)
    
    workflow_content = workflow_content.replace("{AUTOMATION_TASKS}", str(automation_tasks))
    workflow_content = workflow_content.replace("{DEFAULT_AUTOMATION_TASK}", default_automation_task)
    
    workflow_content = workflow_content.replace("{ACTIONS}", str(actions))
    workflow_content = workflow_content.replace("{DEFAULT_ACTION}", default_action)
    
    workflow_content = workflow_content.replace("{ENVIRONMENTS}", str(environments))
    workflow_content = workflow_content.replace("{DEFAULT_ENVIRONMENT}", default_environment)
    
    workflow_content = workflow_content.replace("{ENVIRONMENT_TYPES}", str(environment_types))
    workflow_content = workflow_content.replace("{DEFAULT_ENVIRONMENT_TYPE}", default_environment_type)
    
    workflow_content = workflow_content.replace("{TARGET_SERVERS}", str(target_servers))
    workflow_content = workflow_content.replace("{DEFAULT_TARGET_SERVER}", default_target_server)

    workflow_content = workflow_content.replace("{TARGET_DB}", str(target_dbs))
    workflow_content = workflow_content.replace("{DEFAULT_TARGET_DB}", default_target_db)

    if schedule_section:
        workflow_content = workflow_content.replace("{SCHEDULE_EVENT}", schedule_section)
    else:
        workflow_content = "\n".join(line for line in workflow_content.splitlines() if "{SCHEDULE_EVENT}" not in line)

    return workflow_content.strip()

def save_workflow(file_path, content):
    """Saves the generated workflow file"""
    with open(file_path, "w", encoding="utf-8") as file:
        file.write(content)

def git_commit_and_push(changed_files):
    """Commits and pushes changes to a new branch if there are modified files"""
    if not changed_files:
        print("No files to commit.")
        return
    
    # Generate branch name based on timestamp
    #branch_name = f"workflow-update-{datetime.datetime.now().strftime('%Y%m%d-%H%M%S')}"
    branch_name = f"workflow-update"
    
    try:
        subprocess.run(["git", "checkout", "-b", branch_name], check=True)

        # 🔥 Set Git user identity (GitHub Actions bot)
        subprocess.run(["git", "config", "--global", "user.email", "v-akarthik@cuscal.com.au"], check=True)
        subprocess.run(["git", "config", "--global", "user.name", "Arunkarthikeyan"], check=True)

        subprocess.run(["git", "add"] + changed_files, check=True)
        #subprocess.run(["git", "commit", "-m", "Automated update: Updated workflow files"], check=True)

        github_token = os.getenv("GITHUB_TOKEN")
        repo_url = f"https://{github_token}@github.com/{os.getenv('GITHUB_REPOSITORY')}.git"
        print(f"repo_url: {repo_url}")
        print(f"repo_name: {os.getenv('GITHUB_REPOSITORY')}")
        print(f"github_token: {github_token}")
        print(f"branch_name: {branch_name}")
        subprocess.run(["git", "push", repo_url, branch_name], check=True)
        print(f"Changes pushed to new branch: {branch_name}")
    except subprocess.CalledProcessError as e:
        print(f"Git command failed: {e}")

def set_github_env_variable(var_name, file_paths):
    """Sets a GitHub Actions environment variable with a list of file paths"""
    env_file = os.getenv("GITHUB_ENV")  # Get GitHub environment file path
    print(f"env_file: {env_file}")
    if env_file:
        with open(env_file, "a") as file:
            for file_path in file_paths:
                file.write(f"{var_name}={file_path}\n")  # Add each file path as a separate entry
        print(f"Set GitHub ENV Variable: {var_name} with {len(file_paths)} files.")
    else:
        print("GITHUB_ENV file not found, skipping environment variable update.")

def append_file_to_list(file_path, test_to_append):
    """Appends a file path to a list if it exists"""
    with open(file_path, "a") as file:
        file.write(f"{test_to_append}\n")

def main():
    print("Generating Generic Workflow...")
    parser = argparse.ArgumentParser(description="Generate GitHub workflow files.")
    parser.add_argument("--config", type=str, required=True, help="Path to automation config YAML file")
    parser.add_argument("--template", type=str, required=True, help="Path to workflow template YAML file")
    parser.add_argument("--output", type=str, required=True, help="Path to save the generated workflow file")

    args = parser.parse_args()

    print(f"Using Config File: {args.config}")
    print(f"Using Template File: {args.template}")
    print(f"Output File: {args.output}")

    config = load_yaml(args.config)
    template = load_template(args.template)
    changed_files = []
    workflow_content = generate_workflow(config, template)

    if workflow_content:
        save_workflow(os.path.join(args.output,f"workflow_generic.yml"), workflow_content)
        #changed_files.append(os.path.join(args.output,f"workflow_generic.yml"))
        file_path = os.path.join(args.output,f"workflow_generic.yml")
        changed_files.append(file_path[file_path.index(".github"):])
        append_file_to_list("generated_workflows.txt", file_path)
        #git_commit_and_push(changed_files)
        
        print(f"Generic Workflow saved: {os.path.join(args.output,f"workflow_generic.yml")}")
    else:
        print("Workflow content empty. Skipping file creation.")

if __name__ == "__main__":
    main()
