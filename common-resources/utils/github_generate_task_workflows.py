import argparse
import yaml
import subprocess
import datetime
import os


# File paths (current directory)
#CONFIG_FILE = "automation_config.yml"
#TEMPLATE_FILE = "automation-workflow-template.yml"
#WORKFLOWS_DIR = "."

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

def generate_task_workflow(application, task, config, template):
    """Generates a workflow for a specific task"""
    
    workflow_name = f"{task['name']} - Automation Workflow"
    
    actions = task["actions"]
    default_action = get_default_value(actions)

    environments = [env["name"] for env in application["environments"]]
    default_environment = get_default_value(environments)

    environment_types = [env["type"] for env in application["environments"]]
    default_environment_type = get_default_value(environment_types)

    target_servers = [server for env in application["environments"] for server in env.get("target_servers", [])]
    default_target_server = get_default_value(target_servers)

    target_dbs = [f"{db['host']}:{db['port']}:{db['dbname']}" for env in application["environments"] for db in env.get("target_db", [])]
    default_target_db = get_default_value(target_dbs)

    schedule_section = generate_schedule_section(application["environments"])

    workflow_content = template.replace("{WORKFLOW_NAME}", workflow_name)
    
    # Fix: Ensure `application` and `automation_task` are correctly set
    workflow_content = workflow_content.replace("{APPLICATIONS}", f"['{application['name']}']")
    workflow_content = workflow_content.replace("{DEFAULT_APPLICATION}", application["name"])

    workflow_content = workflow_content.replace("{AUTOMATION_TASKS}", f"['{task['name']}']")
    workflow_content = workflow_content.replace("{DEFAULT_AUTOMATION_TASK}", task["name"])

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

def append_file_to_list(file_path, test_to_append):
    """Appends a file path to a list if it exists"""
    with open(file_path, "a") as file:
        print(f"Appending: {test_to_append}\n")
        file.write(f"{test_to_append}\n")

def main():
    print("Generating Task Workflows...")
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

    for application in config["applications"]:
        app_name = application["name"]
        for task in application["automation_tasks"]:
            task_name = task["name"]
            workflow_filename = os.path.join(args.output, f"workflow_{app_name}_{task_name}.yml")

            print(f"Processing: Application: {app_name}, Task: {task_name}")

            workflow_content = generate_task_workflow(application, task, config, template)

            if workflow_content:
                save_workflow(workflow_filename, workflow_content)
                append_file_to_list("generated_workflows.txt", workflow_filename)
                print(f"Workflow saved: {workflow_filename}")
            else:
                print(f"Skipped workflow generation for {app_name} - {task_name}")

if __name__ == "__main__":
    main()
