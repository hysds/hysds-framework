# Multi-Platform Container Build Configuration

## Overview
The CircleCI configuration has been updated to support building multi-platform container images for both **linux/amd64** (x86_64) and **linux/arm64** (ARM64) architectures using a **split build approach** with native parallel builds.

## Implementation Strategy: Split Native Builds

Instead of using Docker Buildx with QEMU emulation (which is 10-50x slower for ARM64), we implemented a split build strategy:

1. **Separate jobs per architecture** - Each image has dedicated amd64 and arm64 build jobs
2. **Native execution** - amd64 builds on x86_64 machines, arm64 builds on ARM64 machines (`arm.medium` resource class)
3. **Parallel execution** - Both architectures build simultaneously
4. **Manifest creation** - A third job combines the architecture-specific images into a multi-platform manifest

### Benefits
- **60% faster builds** - Native builds vs emulated (e.g., 12-13 min vs 30 min for base images)
- **Lower resource usage** - Uses default `medium` instead of `large` resource class
- **True parallelism** - Both architectures build simultaneously on separate machines
- **Cost effective** - CircleCI free plan supports `arm.medium` resource class

## Changes Made

### 1. Added Docker Buildx Support
- **New command**: `setup_buildx` - Creates and configures a Docker Buildx builder instance
- Enables Docker experimental features
- Creates a `docker-container` driver builder named `multiarch`
- Used primarily for manifest operations and some legacy jobs

### 2. Split Build Jobs

All major container images now use the split build pattern with three jobs each:

#### Core Images (Split Build - Native)
- `build-hysds_base-amd64` / `build-hysds_base-arm64` / `build-hysds_base-manifest`
- `build-hysds_dev-amd64` / `build-hysds_dev-arm64` / `build-hysds_dev-manifest`
- `build-hysds_cuda_base-amd64` / `build-hysds_cuda_base-arm64` / `build-hysds_cuda_base-manifest`
- `build-hysds_cuda_dev-amd64` / `build-hysds_cuda_dev-arm64` / `build-hysds_cuda_dev-manifest`
- `build-hysds_verdi_pge_base-amd64` / `build-hysds_verdi_pge_base-arm64` / `build-hysds_verdi_pge_base-manifest`
  - **Note:** This job builds TWO images (pge-base and verdi), both handled in manifest job
- `build-hysds_cuda_pge_base-amd64` / `build-hysds_cuda_pge_base-arm64` / `build-hysds_cuda_pge_base-manifest`

#### Component Images (Split Build - Native)
- `build-hysds_mozart-amd64` / `build-hysds_mozart-arm64` / `build-hysds_mozart-manifest`
- `build-hysds_metrics-amd64` / `build-hysds_metrics-arm64` / `build-hysds_metrics-manifest`
- `build-hysds_grq-amd64` / `build-hysds_grq-arm64` / `build-hysds_grq-manifest`
- `build-hysds_cont_int-amd64` / `build-hysds_cont_int-arm64` / `build-hysds_cont_int-manifest`

#### Simple Images (Direct Buildx or Retagging)
- `build-rabbitmq` - Uses `docker buildx build` with `--platform linux/amd64,linux/arm64`
- `build-elasticsearch` - Uses `docker buildx imagetools create` to create multi-arch manifests
- `build-redis` - Passes environment variables to external build script

### 3. Architecture-Specific Image Tags

Each architecture build creates separate tags:
- `hysds/base:develop-amd64` (built on x86_64)
- `hysds/base:develop-arm64` (built on ARM64)

The manifest job combines them into:
- `hysds/base:develop` (multi-platform manifest)

When users pull `hysds/base:develop`, Docker automatically selects the correct architecture.

### 4. Native Build Commands

Architecture-specific jobs use standard `docker build` (not buildx) to create pure single-platform images:
```bash
docker build --progress=plain --rm --force-rm \
  --build-arg TAG=develop-amd64 \
  -t hysds/base:develop-amd64 \
  -f docker/Dockerfile .
docker push hysds/base:develop-amd64
```

### 5. Manifest Creation

Manifest jobs use `docker manifest` commands to combine architecture-specific images:
```bash
docker manifest create hysds/base:develop \
  hysds/base:develop-amd64 \
  hysds/base:develop-arm64
docker manifest push hysds/base:develop
```

## External Build Scripts

The following repositories contain build scripts that are called by CircleCI jobs. These scripts now receive architecture-specific tags (e.g., `develop-amd64`) and use standard `docker build` commands:

1. **puppet-redis** (`build_docker.sh`) - Currently uses buildx environment variables (legacy approach)
2. **puppet-verdi** (`build_docker.sh`, `build_docker_cuda.sh`) - Updated to accept architecture-specific tags
3. **puppet-mozart** (`build_docker.sh`) - Updated to accept architecture-specific tags
4. **puppet-metrics** (`build_docker.sh`) - Updated to accept architecture-specific tags
5. **puppet-grq** (`build_docker.sh`) - Updated to accept architecture-specific tags
6. **puppet-cont_int** (`build_docker.sh`) - Updated to accept architecture-specific tags

### Script Invocation Pattern

CircleCI jobs pass architecture-specific tags to build scripts:
```bash
./build_docker.sh develop-amd64 hysds docker develop develop develop-amd64 develop
```

The scripts use standard Docker commands and the native architecture of the executor handles the build.

## Workflow Configuration

### Build Dependencies

The split build approach requires careful workflow orchestration:

1. **Base images first**: `build-hysds_base-{amd64,arm64}` run in parallel
2. **Manifest creation**: `build-hysds_base-manifest` waits for both architecture builds
3. **Dependent images**: Downstream images (dev, cuda-base, etc.) wait for the manifest
4. **Architecture-specific pulls**: Each arch job pulls only its architecture's base image

### Workflow Status

**Active in `build-deploy-develop` workflow:**
- ✅ All base images (base, dev, cuda-base, cuda-dev)
- ✅ PGE/Verdi images (verdi, pge-base, cuda-pge-base)
- ⚠️ Component images (mozart, metrics, grq, cont_int) - **Currently commented out in workflow**

**Active in `build-deploy-release` workflow:**
- ✅ All images configured with split builds for release tags

### Base Image Compatibility

All base images used in Dockerfiles support both amd64 and arm64:
- Ubuntu base images: ✅ Multi-arch support
- Python images: ✅ Multi-arch support
- CUDA images: ✅ NVIDIA provides multi-arch support
- Custom base images: ✅ Built using split build approach

## Support Assets

Support assets (registry, logstash, etc.) are also exported for both architectures:

- `export-support-assets-amd64` - Exports amd64 versions (no suffix for backwards compatibility)
- `export-support-assets-arm64` - Exports arm64 versions (with `-arm64` suffix)
- `deploy-support-assets` - Uploads both versions to GitHub releases

### Testing Recommendations

1. **Verify builds complete successfully** for both architectures
2. **Test resulting images** on both x86_64 and ARM64 hardware
3. **Check image sizes** - ARM64 images may differ in size
4. **Validate functionality** - Ensure no architecture-specific issues
5. **Monitor build times** - Native builds are much faster than emulated
6. **Verify manifests** - Use `docker manifest inspect <image>` to confirm multi-arch support

## Key Benefits

- **Single image tag** works on both x86_64 and ARM64 systems
- **Automatic platform selection** - Docker pulls the correct architecture
- **60% faster builds** - Native execution vs QEMU emulation
- **Lower costs** - Uses smaller resource classes (medium vs large)
- **True parallelism** - Both architectures build simultaneously
- **Future-proof** - Ready for ARM-based cloud instances (AWS Graviton, etc.)
- **Simplified deployment** - No need to manage separate tags per architecture

## Rollback Plan

If issues arise, the configuration can be rolled back by:
1. Reverting to single-job builds with buildx emulation
2. Removing architecture-specific job splits
3. Updating workflow dependencies to use single jobs
4. Removing `-amd64` and `-arm64` tag suffixes

## CircleCI Resource Considerations

- **ARM64 jobs** use `resource_class: arm.medium` (2 vCPUs, 4GB RAM)
- **AMD64 jobs** use default `medium` resource class (2 vCPUs, 4GB RAM)
- **Manifest jobs** use default `medium` resource class (minimal resources needed)
- **Overall faster** - Native parallel builds complete faster than emulated sequential builds
- **Cost effective** - Smaller resource classes reduce credit usage despite more jobs

## References
- [Docker Buildx Documentation](https://docs.docker.com/buildx/working-with-buildx/)
- [Multi-platform Images](https://docs.docker.com/build/building/multi-platform/)
- [CircleCI Docker Layer Caching](https://circleci.com/docs/docker-layer-caching/)
