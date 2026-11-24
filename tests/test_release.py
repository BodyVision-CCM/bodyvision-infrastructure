import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from release import IMAGE, REPO, validate_image, validate_manifest, validate_run


class ReleaseTrustTests(unittest.TestCase):
    def setUp(self):
        self.run = {"id": 123, "head_sha": "a" * 40, "conclusion": "success",
                    "head_branch": "main", "event": "workflow_dispatch",
                    "head_repository": {"full_name": REPO}, "path": ".github/workflows/build-images.yml"}
        self.manifest = {"run_id": 123, "infrastructure_sha": "a" * 40,
                         "source_sha": "b" * 40, "image": IMAGE + "@sha256:" + "c" * 64}

    def test_accepts_scanned_main_release(self):
        self.assertEqual(validate_manifest(self.manifest, self.run), self.manifest)

    def test_rejects_pr_fork_failure_and_other_workflow(self):
        for field, value in [("event", "pull_request"), ("head_branch", "untrusted"),
                             ("conclusion", "failure"), ("path", ".github/workflows/other.yml"),
                             ("head_repository", {"full_name": "attacker/fork"})]:
            run = {**self.run, field: value}
            with self.subTest(field=field), self.assertRaises(ValueError):
                validate_run(run)

    def test_rejects_mismatched_artifact(self):
        for field, value in [("run_id", 456), ("infrastructure_sha", "d" * 40), ("source_sha", "main")]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                validate_manifest({**self.manifest, field: value}, self.run)

    def test_requires_exact_registry_package_and_digest(self):
        for image in [IMAGE + ":latest", "attacker/image@sha256:" + "c" * 64,
                      self.manifest["image"] + "\nattack", IMAGE.replace("user-service", "other") + "@sha256:" + "c" * 64]:
            with self.subTest(image=image), self.assertRaises(ValueError):
                validate_image(image)


class KubernetesContractTests(unittest.TestCase):
    def test_native_sidecar_secrets_probes_and_no_public_service(self):
        resources = json.loads(Path("infra/kubernetes/users/users.json").read_text())["items"]
        pod = resources[0]["spec"]["template"]["spec"]
        self.assertEqual(pod["initContainers"][0]["restartPolicy"], "Always")
        self.assertIn("--private-ip", pod["initContainers"][0]["args"])
        self.assertEqual(pod["volumes"][0]["csi"]["driver"], "secrets-store-gke.csi.k8s.io")
        env = {e["name"]: e["value"] for e in pod["containers"][0]["env"]}
        self.assertEqual(env["RUN_MIGRATIONS"], "false")
        self.assertEqual(env["JWT_AUTOGENERATE_KEYS"], "false")
        self.assertEqual(pod["containers"][0]["readinessProbe"]["httpGet"]["path"], "/readyz")
        self.assertEqual(resources[1]["spec"]["type"], "ClusterIP")

    def test_ci_cannot_read_secrets_or_change_authorization(self):
        resources = json.loads(Path("infra/kubernetes/bootstrap-dev/users-access.json").read_text())["items"]
        role = next(r for r in resources if r["kind"] == "Role")
        permitted = {name for rule in role["rules"] for name in rule["resources"]}
        self.assertFalse(permitted & {"*", "secrets", "roles", "rolebindings", "serviceaccounts", "namespaces", "pods/exec"})
        self.assertTrue(all("*" not in rule["verbs"] for rule in role["rules"]))


if __name__ == "__main__":
    unittest.main()
