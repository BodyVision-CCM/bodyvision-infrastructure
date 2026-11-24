"""Resolve only trusted build runs or an explicitly selected immutable image."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.request

REPO = "BodyVision-CCM/bodyvision-infrastructure"
IMAGE = "europe-west9-docker.pkg.dev/bodyvision-509616/bodyvision-dev-docker/user-service"
SOURCE = "https://github.com/BodyVision-CCM/bodyvision-user-service"


def validate_image(image):
    if not re.fullmatch(re.escape(IMAGE) + r"@sha256:[0-9a-f]{64}", image):
        raise ValueError("Expected an immutable user-service image from the BodyVision registry")
    return image


def validate_run(run):
    if not (run["conclusion"] == "success" and run["head_branch"] == "main"
            and run["event"] in ("push", "workflow_dispatch")
            and run["head_repository"]["full_name"] == REPO
            and run["path"] == ".github/workflows/build-images.yml"):
        raise ValueError("Only successful main builds from the Infrastructure repository may deploy")


def validate_manifest(manifest, run):
    validate_run(run)
    validate_image(manifest["image"])
    if not (manifest["run_id"] == run["id"]
            and manifest["infrastructure_sha"] == run["head_sha"]
            and re.fullmatch(r"[0-9a-f]{40}", manifest["source_sha"])):
        raise ValueError("Release artifact does not match its build run")
    return manifest


def output(**values):
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as stream:
        for key, value in values.items():
            stream.write(f"{key}={value}\n")


def prepare():
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
    if os.environ["GITHUB_EVENT_NAME"] == "workflow_run":
        run_id = int(event["workflow_run"]["id"])
        request = urllib.request.Request(
            f"https://api.github.com/repos/{REPO}/actions/runs/{run_id}",
            headers={"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}",
                     "Accept": "application/vnd.github+json"})
        with urllib.request.urlopen(request, timeout=30) as response:
            run = json.load(response)
        validate_run(run)
        Path(".release-run.json").write_text(json.dumps(run))
        output(mode="build", run_id=run_id)
    else:
        if os.environ["GITHUB_EVENT_NAME"] not in ("workflow_dispatch", "push"):
            raise ValueError("Unsupported deployment event")
        Path(".release-run.json").unlink(missing_ok=True)
        digest = event.get("inputs", {}).get("image_digest") or os.environ.get("PROOF_IMAGE_DIGEST", "")
        image = validate_image(f"{IMAGE}@{digest}")
        Path(".release.json").write_text(json.dumps({"image": image}))
        output(mode="manual", run_id="")


def verify():
    if Path(".release-run.json").exists():
        run = json.loads(Path(".release-run.json").read_text())
        release = validate_manifest(json.loads(Path("release/users-release.json").read_text()), run)
    else:
        release = json.loads(Path(".release.json").read_text())
    image = validate_image(release["image"])
    subprocess.run(["docker", "pull", image], check=True)
    labels = json.loads(subprocess.check_output([
        "docker", "image", "inspect", image, "--format", "{{json .Config.Labels}}"], text=True))
    sha = labels.get("org.opencontainers.image.revision", "")
    if labels.get("org.opencontainers.image.source") != SOURCE or not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError("Image source labels are invalid")
    if release.get("source_sha", sha) != sha:
        raise ValueError("Image revision differs from the release artifact")
    release["source_sha"] = sha
    Path(".release.json").write_text(json.dumps(release))
    print(f"VERIFIED_IMAGE={image}\nSOURCE_SHA={sha}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["prepare", "verify"])
    {"prepare": prepare, "verify": verify}[parser.parse_args().action]()
