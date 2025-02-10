import argparse
import yaml

def parse_args():
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description="Append global parameters to .env file.")
    parser.add_argument("--config_file_path", required=True, help="Path to the YAML config file")
    parser.add_argument("--environment", required=True, help="Environment (e.g., dev, qa, prod)")
    return parser.parse_args()

def load_yaml(file_path):
    """Load YAML configuration file."""
    with open(file_path, "r") as file:
        return yaml.safe_load(file)

def flatten_dict(d, parent_key='', sep='_'):
    """Flatten nested dictionary into uppercase environment variable format."""
    items = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}".upper() if parent_key else k.upper()
        if isinstance(v, dict):
            items.extend(flatten_dict(v, new_key, sep).items())
        else:
            items.append((new_key, v))
    return dict(items)

def process_global_params(yaml_data, environment):
    """Extract and format global parameters, handling prod/nonprod logic."""
    global_params = flatten_dict(yaml_data.get("global", {}))

    # Determine if it's a PROD or NON_PROD environment
    is_prod = environment.lower() == "prod"

    # Rename jump server keys based on environment type
    formatted_params = {}
    for key, value in global_params.items():
        if "JUMP_SERVER_NON_PROD_HOST" in key and is_prod:
            formatted_params["JUMP_SERVER_PROD_HOST"] = value
        elif "JUMP_SERVER_PROD_HOST" in key and not is_prod:
            formatted_params["JUMP_SERVER_NONPROD_HOST"] = value
        else:
            formatted_params[key] = value  # Keep other keys as they are

    return formatted_params

def append_to_env_file(env_filename, global_params):
    """Append global parameters to .env file."""
    with open(env_filename, "a") as env_file:  # Open in append mode
        for key, value in global_params.items():
            env_file.write(f"{key}='{value}'\n")
    print(f"Global parameters appended to '{env_filename}' successfully.")

if __name__ == "__main__":
    args = parse_args()
    yaml_data = load_yaml(args.config_file_path)
    global_params = process_global_params(yaml_data, args.environment)
    append_to_env_file(".env", global_params)
