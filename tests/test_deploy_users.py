import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import deploy_users
from release import IMAGE


class DeploymentFailureTests(unittest.TestCase):
    def setUp(self):
        self.documents = Path("infra/kubernetes/users/users.json").read_text()
        self.release = json.dumps({"image": IMAGE + "@sha256:" + "c" * 64, "source_sha": "b" * 40})
        self.calls = []

    def invoke(self, migration_fails=False, smoke_fails=False, previous=False, apply_fails=False):
        def fake(*args, document=None, check=True):
            self.calls.append((args, document))
            if args[0] == "apply" and apply_fails:
                raise subprocess.CalledProcessError(1, args, stderr="partial apply failed")
            stdout = ""
            if args[0] == "get" and previous:
                stdout = json.dumps({"metadata": {"annotations": {"deployment.kubernetes.io/revision": "3"}}})
            return subprocess.CompletedProcess(args, 1 if args[0] == "wait" and migration_fails else 0, stdout, "")
        with patch.object(Path, "read_text", side_effect=[self.release, self.documents]), \
                patch.object(deploy_users, "kubectl", side_effect=fake), \
                patch.object(deploy_users, "smoke", side_effect=RuntimeError("smoke failed") if smoke_fails else None), \
                patch.dict("os.environ", {"GITHUB_STEP_SUMMARY": ""}):
            deploy_users.main()

    def test_failed_migration_never_changes_deployment(self):
        with self.assertRaisesRegex(RuntimeError, "Migration failed"):
            self.invoke(migration_fails=True)
        self.assertFalse(any(args[0] == "apply" for args, _ in self.calls))
        self.assertEqual(self.calls[-1][0][0], "delete")

    def test_failed_smoke_restores_the_exact_previous_revision(self):
        with self.assertRaisesRegex(RuntimeError, "smoke failed"):
            self.invoke(smoke_fails=True, previous=True)
        self.assertIn(("rollout", "undo", "deployment/users", "--to-revision=3"), [args for args, _ in self.calls])

    def test_migration_uses_same_image_and_stops_with_native_sidecar(self):
        self.invoke()
        job = next(document for args, document in self.calls if args[0] == "create")
        pod = job["spec"]["template"]["spec"]
        self.assertEqual(pod["containers"][0]["args"][3:], ["sh", "-ec", "alembic upgrade head && alembic current"])
        self.assertEqual(pod["restartPolicy"], "Never")
        self.assertEqual(pod["initContainers"][0]["restartPolicy"], "Always")
        self.assertEqual(pod["containers"][0]["image"], IMAGE + "@sha256:" + "c" * 64)

    def test_partial_apply_failure_restores_previous_deployment(self):
        with self.assertRaises(subprocess.CalledProcessError):
            self.invoke(apply_fails=True, previous=True)
        self.assertIn(("rollout", "undo", "deployment/users", "--to-revision=3"), [args for args, _ in self.calls])


if __name__ == "__main__":
    unittest.main()
