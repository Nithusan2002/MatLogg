#!/usr/bin/env python3
"""Fail closed on missing/invalid account settings without printing their values."""
import argparse
import base64
import json
import os
from pathlib import Path
import plistlib
import sys
from urllib.parse import urlsplit


def validation_errors(values):
    errors = []
    required = ("SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY", "SUPABASE_AUTH_CALLBACK_URL")
    for key in required:
        value = values.get(key)
        if not isinstance(value, str) or not value.strip() or "$(" in value or "${" in value:
            errors.append(f"{key} mangler eller er ikke utvidet.")
    if errors:
        return errors
    try:
        url = urlsplit(values["SUPABASE_URL"])
        if url.scheme != "https" or not url.hostname or url.username or url.password or url.query or url.fragment:
            errors.append("SUPABASE_URL må være en gyldig HTTPS-adresse uten innloggingsdata, query eller fragment.")
        elif url.hostname == "localhost" or url.hostname.endswith((".invalid", ".test", ".localhost", ".example")):
            errors.append("SUPABASE_URL peker på et reservert QA-/testdomene og kan ikke brukes i Release.")
    except ValueError:
        errors.append("SUPABASE_URL er ugyldig.")
    if values["SUPABASE_AUTH_CALLBACK_URL"] != "matlogg://auth/callback":
        errors.append("SUPABASE_AUTH_CALLBACK_URL må være appens registrerte callback-adresse.")
    key = values["SUPABASE_PUBLISHABLE_KEY"]
    public = key.startswith("sb_publishable_") and len(key) > len("sb_publishable_")
    if not public:
        try:
            parts = key.split(".")
            payload = json.loads(base64.urlsafe_b64decode(parts[1] + "=" * (-len(parts[1]) % 4))) if len(parts) == 3 else {}
            public = isinstance(payload, dict) and payload.get("role") == "anon"
        except (ValueError, TypeError, IndexError, UnicodeDecodeError):
            public = False
    if not public:
        errors.append("SUPABASE_PUBLISHABLE_KEY må være en offentlig publishable/anon-klientnøkkel.")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plist", type=Path, help="Kontroller ferdig app/arkiv-Info.plist i stedet for byggmiljøet.")
    args = parser.parse_args()
    if args.plist:
        try:
            values = plistlib.loads(args.plist.read_bytes())
            if not isinstance(values, dict):
                raise ValueError("not a dictionary")
        except (OSError, ValueError, plistlib.InvalidFileException):
            print("error: Kan ikke lese appens Info.plist for Release-kontroll.", file=sys.stderr)
            return 1
    elif os.environ.get("CONFIGURATION") == "Release":
        values = os.environ
    else:
        print("Release account check: skipped for non-Release configuration.")
        return 0
    errors = validation_errors(values)
    if errors:
        for error in errors:
            print("error: Release account configuration: " + error, file=sys.stderr)
        print("error: Stoppet for å hindre et bygg uten fungerende kontooppsett. Se Config/Supabase-Release.xcconfig.local.", file=sys.stderr)
        return 1
    print("Release account configuration: valid public client settings (values omitted).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
