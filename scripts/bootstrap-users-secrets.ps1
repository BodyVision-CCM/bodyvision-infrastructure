# Run once as an operator. Existing enabled versions are reused; no rotation.
$ErrorActionPreference = 'Stop'
$project = 'bodyvision-509616'
$env:PYTHONIOENCODING = 'utf-8'
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
foreach ($secretName in @('bv-dev-users-internal-token', 'bv-dev-users-jwt-private-key')) {
    $existing = gcloud secrets list --project=$project --filter="name:$secretName" --format='value(name)'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to list secrets' }
    if ($secretName -notin $existing) {
        gcloud secrets create $secretName --project=$project --replication-policy=automatic --quiet
        if ($LASTEXITCODE -ne 0) { throw "Unable to create $secretName" }
    }
    $versions = gcloud secrets versions list $secretName --project=$project --filter=state:ENABLED --format='value(name)'
    if ($LASTEXITCODE -ne 0) { throw "Unable to list versions for $secretName" }
    if (@($versions).Count -gt 0) { continue }
    if ($secretName -eq 'bv-dev-users-jwt-private-key') {
        $rsa = [System.Security.Cryptography.RSA]::Create(2048)
        try { $secretValue = $rsa.ExportPkcs8PrivateKeyPem() } finally { $rsa.Dispose() }
    } else {
        $secretValue = [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    }
    try {
        $secretValue | gcloud secrets versions add $secretName --project=$project --data-file=- --quiet
        if ($LASTEXITCODE -ne 0) { throw "Unable to add a version for $secretName" }
    } finally {
        Remove-Variable secretValue -ErrorAction SilentlyContinue
    }
}
