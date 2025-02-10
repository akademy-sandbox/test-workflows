import os
import yaml
import sys

# File paths
CONFIG_FILE = sys.argv[1]
INPUT_PARAMETERS_FILE = sys.argv[2]

def load_yaml(file_path):
    """Loads a YAML file"""
    with open(file_path, "r") as file:
        return yaml.safe_load(file)

def get_required_inputs(task_name):
    """Fetches the required input parameters for the given task from input_parameters.yml"""
    input_parameters = load_yaml(INPUT_PARAMETERS_FILE)
    return input_parameters.get(task_name, {}).get("required_inputs", [])

def get_default_inputs(config, automation_task, environment):
    """Fetches the default values for the required inputs from automation_config.yml"""
    
    for application in config["applications"]:
        for task in application["automation_tasks"]:
            if task["name"] == automation_task:
                for env in application["environments"]:
                    if env["name"] == environment:
                        # Extract required inputs dynamically
                        required_inputs = get_required_inputs(automation_task)
                        default_inputs = {}

                        for param in required_inputs:
                            if param == "automation_task":
                                default_inputs[param] = automation_task
                            elif param == "environment":
                                default_inputs[param] = env["name"]
                            elif param == "environment_type":
                                default_inputs[param] = env["type"]
                            elif param == "target_host":
                                default_inputs[param] = env["target_servers"][0] if "target_servers" in env else "N/A"
                            elif param == "db_host":
                                default_inputs[param] = env["target_db"][0]["host"] if "target_db" in env else "N/A"
                            elif param == "db_port":
                                default_inputs[param] = env["target_db"][0]["port"] if "target_db" in env else "N/A"
                            elif param == "db_name":
                                default_inputs[param] = env["target_db"][0]["dbname"] if "target_db" in env else "N/A"
                            elif param == "cron_schedule":
                                default_inputs[param] = env["cron_schedule"] if "cron_schedule" in env else "N/A"    

                        return default_inputs
    return None  # Return None if no matching task or environment is found

def print_inputs(inputs):
    """Prints the input parameters to the console"""
    print("\nDefault Input Parameters:")
    for key, value in inputs.items():
        print(f"{key}: {value}")

def export_to_os_env(inputs):
    """Exports input parameters as OS environment variables"""
    for key, value in inputs.items():
        print(f'export {key.upper()}="{value}"')


def export_to_github_env(inputs):
    """Exports input parameters to GitHub Actions environment using GITHUB_ENV"""
    github_env = os.getenv("GITHUB_ENV")
    if github_env:
        with open(github_env, "a") as env_file:
            for key, value in inputs.items():
                env_file.write(f"{key.upper()}={value}\n")

def create_env_file(inputs, env_file_path=".env"):
    """Creates a .env file with all variables and values"""
    with open(env_file_path, "w") as env_file:
        for key, value in inputs.items():
            env_file.write(f'{key.upper()}="{value}"\n')
    print(f".env file created at {env_file_path}")

def main():
    if len(sys.argv) < 3:
        print("Usage: python fetch_default_inputs.py <automation_task> <environment>")
        sys.exit(1)

    automation_task = sys.argv[3]
    environment = sys.argv[4]

    print(f"Fetching default inputs for {automation_task} in {environment} environment... from {CONFIG_FILE} based on {INPUT_PARAMETERS_FILE}")
    config = load_yaml(CONFIG_FILE)
    
    default_inputs = get_default_inputs(config, automation_task, environment)

    if default_inputs:
        print_inputs(default_inputs)
        create_env_file(default_inputs)
        #export_to_os_env(default_inputs)
        #export_to_github_env(default_inputs)
        print("Inputs exported to OS and GitHub ENV successfully.")
    else:
        print("No matching task or environment found in the config.")

if __name__ == "__main__":
    main()
