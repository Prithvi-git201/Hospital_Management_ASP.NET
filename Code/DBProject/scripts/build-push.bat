@echo off
setlocal enabledelayedexpansion

:: =============================================================================
:: build-push.bat - Build and push Docker image for ClinicManagementSystem
:: Target: AWS EKS (Windows node pool)
:: Usage: scripts\build-push.bat
:: =============================================================================

set PROJECT_NAME=clinicmanagementsystem
set DOCKERFILE_PATH=Code\DBProject\Dockerfile

echo ==============================================
echo   ClinicManagementSystem - Build ^& Push
echo ==============================================
echo.

:: Sanitize image name using PowerShell
for /f "delims=" %%i in ('powershell -Command "$n = 'clinicmanagementsystem'.ToLower() -replace '[^a-z0-9]','-'; $n = $n.Trim('-'); Write-Output $n"') do set IMAGE_NAME=%%i

:: Prompt for image tag
set /p IMAGE_TAG_INPUT="Enter image tag (press Enter for 'latest'): "
if "!IMAGE_TAG_INPUT!"=="" (
    set IMAGE_TAG=latest
) else (
    for /f "delims=" %%t in ('powershell -Command "$t = '!IMAGE_TAG_INPUT!'.ToLower() -replace '[^a-z0-9._-]','-'; $t = $t.Trim('-'); if ($t -eq '') { 'latest' } else { $t }"') do set IMAGE_TAG=%%t
)

echo.
echo Select container registry:
echo   1. AWS ECR
echo   2. Docker Hub
set /p REGISTRY_CHOICE="Enter choice (1 or 2): "
echo.

if "!REGISTRY_CHOICE!"=="1" goto ECR_SETUP
if "!REGISTRY_CHOICE!"=="2" goto DOCKERHUB_SETUP
echo ERROR: Invalid choice. Please enter 1 or 2.
exit /b 1

:ECR_SETUP
set /p AWS_REGION="Enter AWS Region (e.g. us-east-1): "
set /p AWS_ACCOUNT_ID="Enter AWS Account ID: "
set /p ECR_REPO_INPUT="Enter ECR repository name (default: !IMAGE_NAME!): "
if "!ECR_REPO_INPUT!"=="" (
    set ECR_REPO=!IMAGE_NAME!
) else (
    for /f "delims=" %%r in ('powershell -Command "$r = '!ECR_REPO_INPUT!'.ToLower() -replace '[^a-z0-9/_-]','-'; $r = $r.Trim('-'); Write-Output $r"') do set ECR_REPO=%%r
)

set REGISTRY_URL=!AWS_ACCOUNT_ID!.dkr.ecr.!AWS_REGION!.amazonaws.com
set FULL_IMAGE_NAME=!REGISTRY_URL!/!ECR_REPO!:!IMAGE_TAG!

echo.
echo Authenticating with AWS ECR...
aws ecr get-login-password --region !AWS_REGION! | docker login --username AWS --password-stdin !REGISTRY_URL!
if !ERRORLEVEL! neq 0 (
    echo ERROR: ECR login failed.
    exit /b 1
)

echo Checking/creating ECR repository: !ECR_REPO! ...
aws ecr describe-repositories --repository-names !ECR_REPO! --region !AWS_REGION! >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo Creating ECR repository...
    aws ecr create-repository --repository-name !ECR_REPO! --region !AWS_REGION!
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Failed to create ECR repository.
        exit /b 1
    )
)
goto BUILD

:DOCKERHUB_SETUP
set /p DOCKER_USERNAME="Enter Docker Hub username: "
set /p DOCKER_PASSWORD="Enter Docker Hub password/token: "
set /p DOCKERHUB_REPO_INPUT="Enter Docker Hub repository (default: !DOCKER_USERNAME!/!IMAGE_NAME!): "
if "!DOCKERHUB_REPO_INPUT!"=="" (
    set DOCKERHUB_REPO=!DOCKER_USERNAME!/!IMAGE_NAME!
) else (
    set DOCKERHUB_REPO=!DOCKERHUB_REPO_INPUT!
)

set FULL_IMAGE_NAME=!DOCKERHUB_REPO!:!IMAGE_TAG!

echo.
echo Authenticating with Docker Hub...
echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker Hub login failed.
    exit /b 1
)
goto BUILD

:BUILD
echo.
echo Building Docker image...
echo   Image      : !FULL_IMAGE_NAME!
echo   Dockerfile : !DOCKERFILE_PATH!
echo   Context    : . (repository root)
echo.

docker build -f !DOCKERFILE_PATH! -t !FULL_IMAGE_NAME! .
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker build failed.
    exit /b 1
)

echo.
echo Pushing image to registry...
docker push !FULL_IMAGE_NAME!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker push failed.
    exit /b 1
)

echo.
echo ==============================================
echo   SUCCESS: Image pushed successfully!
echo   !FULL_IMAGE_NAME!
echo ==============================================
endlocal
