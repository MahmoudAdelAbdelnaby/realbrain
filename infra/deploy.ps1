# Deploys the backend to Cloud Run with a Cloud Tasks queue (P0-05). Safe to re-run.
# Run from the repo root in your own terminal:  .\infra\deploy.ps1
# Needs: gcloud logged in (gcloud auth login), Firestore + Storage enabled in the Firebase console,
# billing attached with the $1 budget alert. You'll be asked for the Gemini key once; it goes to Secret Manager.
param(
    [string]$Project = "reelbrain-dev",
    [string]$Region = "europe-west1",
    [string]$Bucket = ""
)
$ErrorActionPreference = "Stop"
if (-not $Bucket) { $Bucket = "$Project.firebasestorage.app" }
$Sa = "reelbrain-api@$Project.iam.gserviceaccount.com"
$Queue = "projects/$Project/locations/$Region/queues/process"

function Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function Quiet { param([scriptblock]$Cmd) & $Cmd 2>$null | Out-Null; $global:LASTEXITCODE = 0 }

Step "Project and APIs"
gcloud config set project $Project | Out-Null
gcloud services enable run.googleapis.com cloudtasks.googleapis.com firestore.googleapis.com `
    storage.googleapis.com secretmanager.googleapis.com artifactregistry.googleapis.com `
    cloudbuild.googleapis.com iamcredentials.googleapis.com

Step "Service account $Sa"
Quiet { gcloud iam service-accounts create reelbrain-api --display-name "Reelbrain API" }
foreach ($role in "roles/datastore.user", "roles/storage.objectAdmin", "roles/cloudtasks.enqueuer", "roles/secretmanager.secretAccessor") {
    gcloud projects add-iam-policy-binding $Project --member "serviceAccount:$Sa" --role $role --condition None | Out-Null
}
# Sign Storage URLs through IAM, and mint OIDC tokens for its own Cloud Tasks.
foreach ($role in "roles/iam.serviceAccountTokenCreator", "roles/iam.serviceAccountUser") {
    gcloud iam service-accounts add-iam-policy-binding $Sa --member "serviceAccount:$Sa" --role $role | Out-Null
}

Step "Gemini key in Secret Manager"
gcloud secrets describe gemini-api-key 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    $secure = Read-Host "Paste your Gemini API key" -AsSecureString
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
    $tmp = New-TemporaryFile
    [IO.File]::WriteAllText($tmp, $plain)
    gcloud secrets create gemini-api-key --data-file $tmp
    Remove-Item $tmp
} else { Write-Host "exists, keeping it (add a version to rotate: gcloud secrets versions add gemini-api-key --data-file=...)" }

Step "Cloud Tasks queue (3 attempts, exponential backoff, one save every 15 s for the free Gemini limit)"
$qargs = "--location=$Region", "--max-attempts=3", "--min-backoff=10s", "--max-backoff=300s", "--max-doublings=4", "--max-concurrent-dispatches=1", "--max-dispatches-per-second=0.067"
gcloud tasks queues describe process --location $Region 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { gcloud tasks queues create process @qargs } else { gcloud tasks queues update process @qargs }

Step "Cloud Run service"
$envs = "GOOGLE_CLOUD_PROJECT=$Project,GCS_BUCKET=$Bucket,TASKS_QUEUE=$Queue,TASKS_SERVICE_ACCOUNT=$Sa"
# ponytail: min-instances 0 and max 2 keep it at $0; raise max if saves queue up.
gcloud run deploy reelbrain-api --source backend --region $Region --service-account $Sa `
    --allow-unauthenticated --memory 1Gi --timeout 600 --min-instances 0 --max-instances 2 `
    --set-secrets "GEMINI_API_KEY=gemini-api-key:latest" --set-env-vars $envs
$Url = gcloud run services describe reelbrain-api --region $Region --format "value(status.url)"
gcloud run services update reelbrain-api --region $Region --update-env-vars "PUBLIC_URL=$Url,TASKS_AUDIENCE=$Url" | Out-Null

Step "Rules (deny all client access until P1-03)"
if (Get-Command firebase -ErrorAction SilentlyContinue) { firebase deploy --only "firestore:rules,storage" --project $Project }
else { Write-Host "firebase CLI not found; run later: firebase deploy --only firestore:rules,storage --project $Project" }

Step "Done"
Write-Host "API: $Url  (health: $Url/health)"
Write-Host "Add to app\android\local.properties, then rebuild the app:"
Write-Host "  reelbrain.apiUrl=$Url"
Write-Host "  reelbrain.firebaseProjectId=$Project"
Write-Host "  reelbrain.firebaseApiKey=<Firebase console > Project settings > Your apps > Android app: Web API key>"
Write-Host "  reelbrain.firebaseAppId=<same place: App ID, 1:...:android:...>"
