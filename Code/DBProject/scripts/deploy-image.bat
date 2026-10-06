@echo off
setlocal enabledelayedexpansion

:: =============================================================================
:: deploy-image.bat - Deploy ClinicManagementSystem to AWS EKS (Windows)
:: Usage: scripts\deploy-image.bat
:: Requirements: aws-cli, kubectl
:: =============================================================================

set NAMESPACE=clinicmanagementsystem
set APP_NAME=clinicmanagementsystem
set K8S_DIR=kubernetes
set TEMP_DIR=%TEMP%\k8s-deploy-%RANDOM%

echo ==============================================
echo   ClinicManagementSystem - Deploy to AWS EKS
echo ==============================================
echo.

:: ---- Collect deployment inputs ----
set /p AWS_REGION="Enter AWS Region (e.g. us-east-1): "
if "!AWS_REGION!"=="" (
    echo ERROR: AWS Region is required.
    exit /b 1
)

set /p CLUSTER_NAME="Enter EKS Cluster Name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: EKS Cluster Name is required.
    exit /b 1
)

set /p IMAGE_URI="Enter full Docker image URI (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/clinicmanagementsystem:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Docker image URI is required.
    exit /b 1
)

echo.
echo ---- Application Environment Variables ----
echo Press Enter to skip any variable.
echo.

set /p DB_CONNECTION_STRING="Enter DB_CONNECTION_STRING (full SQL Server connection string, or Enter to skip): "
set /p DB_HOST="Enter DB_HOST (SQL Server host, or Enter to skip): "
set /p DB_NAME="Enter DB_NAME (database name, default: DBProject): "
set /p DB_USER="Enter DB_USER (database user, or Enter to skip): "
set /p DB_PASSWORD="Enter DB_PASSWORD (database password, or Enter to skip): "
set /p REDIS_HOST="Enter REDIS_HOST (ElastiCache/Redis host, or Enter to skip): "
set /p REDIS_PORT="Enter REDIS_PORT (Redis port, default: 6379): "
set /p REDIS_ACCESS_KEY="Enter REDIS_ACCESS_KEY (Redis access key, or Enter to skip): "
set /p APPINSIGHTS_INSTRUMENTATIONKEY="Enter APPINSIGHTS_INSTRUMENTATIONKEY (Application Insights key, or Enter to skip): "

echo.
echo ---- Configuring kubectl for EKS ----
aws eks update-kubeconfig --region !AWS_REGION! --name !CLUSTER_NAME!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to configure kubectl for EKS cluster '!CLUSTER_NAME!'.
    exit /b 1
)

echo Verifying cluster connectivity...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to EKS cluster.
    exit /b 1
)

echo.
echo ---- Preparing Kubernetes manifests ----
mkdir "!TEMP_DIR!" 2>nul
copy "!K8S_DIR!\namespace.yaml"  "!TEMP_DIR!\namespace.yaml"  >nul
copy "!K8S_DIR!\deployment.yaml" "!TEMP_DIR!\deployment.yaml" >nul
copy "!K8S_DIR!\service.yaml"    "!TEMP_DIR!\service.yaml"    >nul
copy "!K8S_DIR!\ingress.yaml"    "!TEMP_DIR!\ingress.yaml"    >nul

:: Replace placeholders using PowerShell
powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{IMAGE_URI}}','!IMAGE_URI!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to update IMAGE_URI placeholder. & exit /b 1 )

if not "!DB_CONNECTION_STRING!"=="" powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_CONNECTION_STRING}}','!DB_CONNECTION_STRING!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if not "!DB_HOST!"==""              powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_HOST}}','!DB_HOST!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if not "!DB_NAME!"==""              powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_NAME}}','!DB_NAME!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if not "!DB_USER!"==""              powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_USER}}','!DB_USER!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if not "!DB_PASSWORD!"==""          powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_PASSWORD}}','!DB_PASSWORD!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if not "!REDIS_HOST!"==""           powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{REDIS_HOST}}','!REDIS_HOST!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if not "!REDIS_PORT!"==""           powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{REDIS_PORT}}','!REDIS_PORT!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if not "!REDIS_ACCESS_KEY!"==""     powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{REDIS_ACCESS_KEY}}','!REDIS_ACCESS_KEY!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if not "!APPINSIGHTS_INSTRUMENTATIONKEY!"=="" powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{APPINSIGHTS_INSTRUMENTATIONKEY}}','!APPINSIGHTS_INSTRUMENTATIONKEY!' | Set-Content '!TEMP_DIR!\deployment.yaml'"

echo.
echo ---- Applying Kubernetes manifests ----

echo [1/4] Applying namespace...
kubectl apply -f "!TEMP_DIR!\namespace.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply namespace. & goto CLEANUP_FAIL )

echo [2/4] Applying deployment...
kubectl apply -f "!TEMP_DIR!\deployment.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply deployment. & goto CLEANUP_FAIL )

echo [3/4] Applying service...
kubectl apply -f "!TEMP_DIR!\service.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply service. & goto CLEANUP_FAIL )

echo [4/4] Applying ingress...
kubectl apply -f "!TEMP_DIR!\ingress.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply ingress. & goto CLEANUP_FAIL )

echo.
echo ---- Waiting for deployment rollout ----
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo ERROR: Deployment rollout failed or timed out.
    echo To rollback: kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
    goto CLEANUP_FAIL
)

echo.
echo ---- Verifying deployed resources ----
kubectl get pods,svc,ingress -n !NAMESPACE!

echo.
echo ---- Application Access ----
echo Application URL: http://clinicmanagementsystem.example.com
echo Health Check:    http://clinicmanagementsystem.example.com/Health.aspx
echo.
echo Note: If using AWS ALB Ingress, the external hostname may take a few minutes.
echo       Run: kubectl get ingress -n !NAMESPACE! to check the ADDRESS field.

rmdir /s /q "!TEMP_DIR!" 2>nul

echo.
echo ==============================================
echo   SUCCESS: Deployment complete!
echo ==============================================
echo.
echo Useful commands:
echo   kubectl get pods -n !NAMESPACE!
echo   kubectl logs -l app=!APP_NAME! -n !NAMESPACE!
echo   kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
endlocal
exit /b 0

:CLEANUP_FAIL
rmdir /s /q "!TEMP_DIR!" 2>nul
endlocal
exit /b 1
