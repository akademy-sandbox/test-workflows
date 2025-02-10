import argparse
import yaml

def parse_args():
    parser = argparse.ArgumentParser(description="Generate .env file from YAML configuration")
    parser.add_argument("--automation_task_name", required=True, help="Name of the automation task")
    parser.add_argument("--environment", required=True, help="Target environment (dev, test, qa, etc.)")
    parser.add_argument("--data_center", required=True, help="Target data center (ultimo, homebush, etc.)")
    parser.add_argument("--environment_type", required=True, help="Environment type (onpremise, cloud, etc.)")
    parser.add_argument("--inventory_file_path", required=True, help="Inventory file path (inventory.yml)")
    return parser.parse_args()

def load_yaml(file_path="config.yaml"):
    with open(file_path, "r") as file:
        return yaml.safe_load(file)

def extract_details(yaml_data, task_name, environment, data_center, env_type):
    result = {
        "APP_NAME": "N/A",
        "AUTOMATION_TASK_NAME": task_name,
        "WORKFLOW_NAME": "N/A",
        "ENVIRONMENT": environment,
        "DATA_CENTER": data_center,
        "ENVIRONMENT_TYPE": env_type,
        "ACTIONS": "N/A",
        "TARGET_HOSTS": "N/A",
        "DB_HOST": "N/A",
        "DB_PORT": "N/A",
        "DB_NAME": "N/A"
    }

    # Find application and task details
    for app in yaml_data.get("applications", []):
        for task in app.get("automation_tasks", []):
            if task.get("name") == task_name:
                result["APP_NAME"] = app.get("name", "N/A")
                result["WORKFLOW_NAME"] = "NA" #task.get("workflow_name", "N/A")
                result["ACTIONS"] = ",".join(map(str.upper, task.get("actions", []))) if task.get("actions") else "N/A"

                # Find the correct environment
                for env in app.get("environments", []):
                    if env.get("name") == environment:
                        result["ENVIRONMENT_TYPE"] = env.get("type", env_type)

                        # Fetch target servers from the specified data center
                        if "data_centers" in env and data_center in env["data_centers"]:
                            dc_info = env["data_centers"][data_center]

                            # Extract the `target_server` if available
                            if "target_server" in dc_info:
                                result["TARGET_HOSTS"] = dc_info["target_server"]

                            # Extract database details if available
                            if "database" in dc_info:
                                db_info = dc_info["database"]
                                result["DB_HOST"] = db_info.get("host", "N/A")
                                result["DB_PORT"] = str(db_info.get("port", "N/A"))
                                result["DB_NAME"] = db_info.get("dbname", "N/A")

    return result

def write_env_file(env_name, details):
    env_filename = f".env"
    with open(env_filename, "a") as env_file:
        for key, value in details.items():
            env_file.write(f"{key}='{value}'\n")
    print(f"Environment file '{env_filename}' generated successfully.")

if __name__ == "__main__":
    args = parse_args()
    yaml_data = load_yaml(args.inventory_file_path)
    details = extract_details(yaml_data, args.automation_task_name, args.environment, args.data_center, args.environment_type)
    write_env_file(args.environment, details)
