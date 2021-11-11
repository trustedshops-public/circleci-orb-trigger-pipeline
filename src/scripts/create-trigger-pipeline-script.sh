echo "Create file in ${CIRCLECI_TRIGGER_PIPELINE_SCRIPT_PATH} ..."
cat <<TEXT > /tmp/trigger-pipeline.tmp
#!/usr/bin/env python3
import time
import urllib.request
import urllib.error
import json
from argparse import ArgumentParser, Action
import sys

# Ansi constants
ANSI_RED = '\u001b[31;1m'
ANSI_RESET = '\u001b[0m'
ANSI_BLUE = '\u001b[34;1m'


def print_pair(key, value):
    # Print a key value pair to console with terminal colors
    print(f"{ANSI_BLUE}{key.ljust(20)} {ANSI_RESET} {value}")


def print_err(msg):
    print(f"{ANSI_RED}ERROR: {msg}{ANSI_RESET}")


def parse_cli():
    # Parse arguments to script
    parser = ArgumentParser(description="Trigger CircleCI pipeline")
    parser.add_argument("--branch", required=False, help="Branch to execute the pipeline for")
    parser.add_argument('--build-parameters', action=type('', (Action,), dict(
        __call__=lambda a, p, n, v, o: getattr(n, a.dest).update(dict([v.split('=')])))), default={})
    parser.add_argument("--vcs", default="github")
    parser.add_argument("--circleci-url", default="https://circleci.com", help="CircleCI url to use as base path, including protocol")
    parser.add_argument("--circleci-token", help="CircleCI Token used to authenticate API requests")
    parser.add_argument("--slug", help="Slug for org/username and project separated by slash")
    return parser.parse_args()


def build_circleci_request(path):
    request = urllib.request.Request(f"{args.circleci_url}{path}")
    request.add_header("Content-Type", "application/json")
    request.add_header("Circle-Token", args.circleci_token)
    return request


if __name__ == "__main__":
    args = parse_cli()

    req = build_circleci_request(f"/api/v2/project/{args.vcs}/{args.slug}/pipeline")

    payload = {
        "parameters": args.build_parameters
    }

    if args.branch is not None:
        payload['branch'] = args.branch

    try:
        res = urllib.request.urlopen(req, json.dumps(payload).encode("utf8"))
        raw_response = res.read()
        parsed_response = json.loads(raw_response)
    except TypeError as e:
        print_err("Failed to serialize json")
        print_pair("Message", str(e))
        sys.exit(2)
    except urllib.error.HTTPError as e:
        print_err("Failed to trigger pipeline via CircleCI API")
        print_pair("URL", req.full_url)
        print_pair("Status", e.code)
        print_pair("Response", e.read().decode('utf8'))
        sys.exit(1)
    except urllib.error.URLError as e:
        print_err("Failed to call CircleCI API")
        print_pair("Reason", e.reason)
        sys.exit(2)
    except json.JSONDecodeError as e:
        print_err("Failed to parse json from triggering pipeline")
        print_pair("Message", str(e))
        print_pair("Response-Text", raw_response)
        sys.exit(1)

    print("Workflow triggered successfully!")
    print_pair("Job-Number", parsed_response['number'])
    print_pair("State", parsed_response['state'])
    print_pair("ID", parsed_response['id'])
TEXT

sudo mv /tmp/trigger-pipeline.tmp "${CIRCLECI_TRIGGER_PIPELINE_SCRIPT_PATH}"

echo "Making file ${CIRCLECI_TRIGGER_PIPELINE_SCRIPT_PATH} executable ..."
sudo chmod +x "${CIRCLECI_TRIGGER_PIPELINE_SCRIPT_PATH}"
