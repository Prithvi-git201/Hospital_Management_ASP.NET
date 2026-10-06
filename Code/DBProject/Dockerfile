# =============================================================================
# Stage 1: Build Stage
# Uses the full .NET Framework SDK image to restore packages and build the app
# =============================================================================
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8 AS builder

WORKDIR /src

# Copy project file first for NuGet package restore layer caching
COPY ["Code/DBProject/ClinicManagementSystem.csproj", "Code/DBProject/"]
COPY ["Code/DBProject/packages.config", "Code/DBProject/"]

# Restore NuGet packages
RUN nuget restore Code/DBProject/ClinicManagementSystem.csproj -PackagesDirectory Code/packages

# Copy the rest of the source code
COPY . .

# Build and publish the application in Release mode
RUN msbuild Code/DBProject/ClinicManagementSystem.csproj \
    /p:Configuration=Release \
    /p:DeployOnBuild=true \
    /p:WebPublishMethod=FileSystem \
    /p:PublishUrl=C:\publish \
    /p:DeleteExistingFiles=True

# =============================================================================
# Stage 2: Runtime Stage
# Uses the explicit base image provided: mcr.microsoft.com/dotnet/framework/runtime:4.8
# =============================================================================
FROM mcr.microsoft.com/dotnet/framework/runtime:4.8 AS runtime

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Set working directory for the application
WORKDIR /inetpub/wwwroot

# Copy published artifacts from build stage
COPY --from=builder C:\publish .

# Set environment variables for the application
ENV ASPNET_ENV=Production
ENV DB_HOST=""
ENV DB_NAME="DBProject"
ENV DB_USER="sa"
ENV DB_PASSWORD=""
ENV DB_CONNECTION_STRING=""
ENV REDIS_HOST=""
ENV REDIS_PORT="6379"
ENV REDIS_ACCESS_KEY=""
ENV APPINSIGHTS_INSTRUMENTATIONKEY=""

# Expose port 80 for IIS/HTTP traffic
EXPOSE 80

# The base image already configures IIS; the app is served from wwwroot
ENTRYPOINT ["C:\\ServiceMonitor.exe", "w3svc"]
