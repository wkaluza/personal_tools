import datetime
import json
import subprocess
import time
from argparse import ArgumentParser


def upload_totp(issuer, timestamp, secret, pin=None):
    print(f"Uploading {issuer}_{timestamp}:wk")
    args = [
        "ykman",
        "oath",
        "accounts",
        "add",
        "--oath-type",
        "TOTP",
        "--period",
        "30",
        "--digits",
        "6",
        "--algorithm",
        "SHA1",
        "--force",
        "--touch",
        "--issuer",
        f"{issuer}_{timestamp}",
    ]
    password_arg = [] if pin is None else ["--password", f"{pin}"]
    name_secret_args = ["wk", secret]

    subprocess.run(args + password_arg + name_secret_args)
    time.sleep(2)


def list_totp(pin=None):
    args = ["ykman", "oath", "accounts", "list"]
    password_arg = [] if pin is None else ["--password", f"{pin}"]

    lines = subprocess.run(
        args + password_arg, stdout=subprocess.PIPE
    ).stdout.splitlines()
    time.sleep(2)

    return [line.decode() for line in lines]


def get_json(path):
    with open(path, "r") as f:
        return json.load(f)


def main(config):
    if "file" in config:
        j = get_json(config.file)

        pin = j["yubikey_secrets"]["pin"]
        totp = j["yubikey_secrets"]["oath_totp"]

        credentials_on_yubikey = list_totp(pin)

        for issuer in totp:
            secret = totp[issuer]["secret"]
            timestamp = totp[issuer]["date"]
            if f"{issuer}_{timestamp}:wk" in credentials_on_yubikey:
                print(f"Skipping: {issuer}_{timestamp}:wk already present")
                continue

            upload_totp(issuer, timestamp, secret, pin)
    else:
        upload_totp(config.issuer, config.timestamp, config.secret)


def parse_arguments():
    parser = ArgumentParser()
    subparsers = parser.add_subparsers()

    json = subparsers.add_parser("json")
    json.add_argument("--file", required=True)
    code = subparsers.add_parser("code")
    code.add_argument("--issuer", required=True)
    code.add_argument("--secret", required=True)

    utc_now = datetime.datetime.utcnow().strftime("%Y%m%d%H%M%S")
    code.add_argument(
        "--timestamp",
        default=utc_now,
        help="Defaults to current UTC as YYYYmmddHHMMSS",
    )

    parsed = parser.parse_args()

    return parsed


if __name__ == "__main__":
    config = parse_arguments()
    main(config)
