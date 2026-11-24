"""Migrate first, roll out an immutable image, smoke-test, restore the previous revision on failure."""
import copy
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.request
import uuid

from release import validate_image


def kubectl(*args, document=None, check=True):
    return subprocess.run(["kubectl", "-n", "bodyvision", *args],
                          input=json.dumps(document) if document else None,
                          text=True, capture_output=True, check=check)


def smoke():
    process = subprocess.Popen(["kubectl", "-n", "bodyvision", "port-forward", "service/users",
                                "18080:80", "--address=127.0.0.1"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for attempt in range(30):
            try:
                with urllib.request.urlopen("http://127.0.0.1:18080/healthz", timeout=2) as response:
                    assert json.load(response)["status"] == "ok"
                break
            except (OSError, urllib.error.URLError):
                if process.poll() is not None or attempt == 29:
                    raise RuntimeError("Unable to reach users through port-forward")
                time.sleep(1)
        with urllib.request.urlopen("http://127.0.0.1:18080/readyz", timeout=10) as response:
            assert json.load(response)["database"] == "up"
        with urllib.request.urlopen("http://127.0.0.1:18080/.well-known/jwks.json", timeout=10) as response:
            keys = json.load(response)["keys"]
            assert keys and keys[0]["alg"] == "RS256"
        print("HEALTHZ_OK\nREADYZ_DATABASE_UP\nJWKS_RS256_OK")
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def main():
    release = json.loads(Path(".release.json").read_text())
    image = validate_image(release["image"])
    documents = json.loads(Path("infra/kubernetes/users/users.json").read_text())
    deployment = documents["items"][0]
    template = deployment["spec"]["template"]
    template["spec"]["containers"][0]["image"] = image
    template["metadata"]["annotations"] = {"bodyvision/source-sha": release["source_sha"]}
    job = {"apiVersion": "batch/v1", "kind": "Job",
           "metadata": {"name": "users-migrate-" + uuid.uuid4().hex[:12], "namespace": "bodyvision"},
           "spec": {"backoffLimit": 0, "activeDeadlineSeconds": 300, "ttlSecondsAfterFinished": 3600,
                    "template": copy.deepcopy(template)}}
    job["spec"]["template"]["spec"]["restartPolicy"] = "Never"
    migration = job["spec"]["template"]["spec"]["containers"][0]
    migration["args"][3:] = ["alembic", "upgrade", "head"]
    for field in ("startupProbe", "readinessProbe", "livenessProbe", "ports"):
        migration.pop(field, None)
    previous = kubectl("get", "deployment/users", "--ignore-not-found", "-o", "json").stdout
    previous_revision = json.loads(previous)["metadata"]["annotations"]["deployment.kubernetes.io/revision"] if previous.strip() else None
    job_name = job["metadata"]["name"]
    try:
        kubectl("create", "-f", "-", document=job)
        completed = kubectl("wait", "--for=condition=complete", f"job/{job_name}", "--timeout=300s", check=False)
        print(kubectl("logs", f"job/{job_name}", "-c", "users", check=False).stdout)
        if completed.returncode:
            raise RuntimeError("Migration failed; the Deployment has not been changed")
        print("MIGRATION_JOB_OK " + job_name)
        try:
            kubectl("apply", "-f", "-", document=documents)
            kubectl("rollout", "status", "deployment/users", "--timeout=300s")
            smoke()
        except Exception:
            if previous_revision:
                kubectl("rollout", "undo", "deployment/users", f"--to-revision={previous_revision}")
                kubectl("rollout", "status", "deployment/users", "--timeout=300s")
                print("PREVIOUS_DEPLOYMENT_RESTORED; database migrations are not downgraded")
            raise
        print(f"DEPLOYMENT_SUCCESS image={image} source={release['source_sha']}")
        if os.environ.get("GITHUB_STEP_SUMMARY"):
            with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as stream:
                stream.write(f"### Utilisateurs déployé\n\nImage : `{image}`\n\nSource : `{release['source_sha']}`\n\nMigration, rollout, healthz, readyz et JWKS : OK.\n")
    finally:
        kubectl("delete", f"job/{job_name}", "--ignore-not-found", check=False)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(error.stderr)
        raise SystemExit(error.returncode)
