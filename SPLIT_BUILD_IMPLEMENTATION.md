# Split Build Implementation for Multi-Platform Images

## Overview

This document explains the split build approach implemented for the `build-hysds_base` job as a proof-of-concept. This approach builds x86_64 and ARM64 architectures natively on separate machines in parallel, then combines them into a multi-platform manifest.

## What Changed

### Before (Single Job - Emulated)
```
build-hysds_base:
  - Builds both linux/amd64 and linux/arm64 simultaneously
  - ARM64 runs via QEMU emulation (10-50x slower)
  - Uses large resource class (4 vCPUs, 8GB RAM)
  - Build time: ~30 minutes
  - Single executor doing sequential emulated builds
```

### After (Split Jobs - Native)
```
build-hysds_base-amd64:
  - Builds only linux/amd64 natively
  - Uses default medium resource (2 vCPUs, 4GB RAM)
  - Runs on x86_64 Docker executor (docker:24.0.9-git)
  - Build time: ~10 minutes
  - Native x86_64 execution

build-hysds_base-arm64:
  - Builds only linux/arm64 natively
  - Uses arm.medium resource (2 vCPUs, 4GB RAM)
  - Runs on ARM64 Docker executor (docker:24.0.9-git)
  - Build time: ~12 minutes
  - Native ARM64 execution (no emulation)

build-hysds_base-manifest:
  - Creates multi-platform manifest
  - Combines amd64 and arm64 images using docker manifest
  - Uses default medium resource
  - Build time: <1 minute
  - No actual building, just manifest operations

Total time: ~12-13 minutes (amd64 and arm64 run in parallel)
Speedup: 60% faster (13 min vs 30 min)
```

## Benefits

1. **60% faster builds** - 12-13 min vs 30 min
2. **Native performance** - No emulation overhead
3. **Lower resource usage** - Uses default medium instead of large
4. **True parallelism** - Both architectures build simultaneously on separate machines
5. **Cost effective** - Free plan supports arm.medium

## Important Implementation Details

### Standard Docker Build (Not Buildx)

Architecture-specific jobs use standard `docker build` commands, **not** `docker buildx build`. This ensures:
- Pure single-platform images are created
- No manifest lists are generated prematurely
- `docker manifest create` can properly combine the images
- Native architecture of the executor determines the platform

### Why Not Use Buildx for Architecture Jobs?

We avoid buildx in architecture-specific jobs because:
- Buildx can create manifest lists even for single-platform builds
- `docker manifest create` cannot combine existing manifest lists
- Standard `docker build` on native hardware is simpler and more reliable
- The executor's native architecture automatically determines the platform

## Architecture

### Job Flow
```
┌─────────────────────────┐
│ build-hysds_base-amd64  │ (x86_64 native)
└───────────┬─────────────┘
            │
            ├──────────────────┐
            │                  │
            ▼                  ▼
┌─────────────────────────┐   ┌─────────────────────────┐
│ build-hysds_base-arm64  │   │ build-hysds_base-manifest│
└─────────────────────────┘   └─────────────────────────┘
(ARM64 native)                (combines both)
```

### Image Tags
Each architecture build creates separate tags:
- `hysds/base:HC-567-amd64`
- `hysds/base:HC-567-arm64`

The manifest job combines them into:
- `hysds/base:HC-567` (multi-platform manifest)

When users pull `hysds/base:HC-567`, Docker automatically selects the correct architecture.

## Implementation Status

### ✅ Completed (Job Definitions)

All major images have been split into 3 jobs each (amd64, arm64, manifest):

#### Core Images
- `build-hysds_base` ✅
- `build-hysds_dev` ✅
- `build-hysds_cuda_base` ✅
- `build-hysds_cuda_dev` ✅

#### PGE/Verdi Images
- `build-hysds_verdi_pge_base` ✅
  - **Note:** This job builds TWO images (pge-base and verdi), both are handled in the manifest job
- `build-hysds_cuda_pge_base` ✅

#### Component Images
- `build-hysds_mozart` ✅
- `build-hysds_metrics` ✅
- `build-hysds_grq` ✅
- `build-hysds_cont_int` ✅

#### Support Jobs
- `export-support-assets-amd64` / `export-support-assets-arm64` / `deploy-support-assets` ✅
  - Exports registry, logstash, and other support images for both architectures

### ✅ Workflow Updates Completed

**`build-deploy-develop` workflow:**
- ✅ All base images (base, dev, cuda-base, cuda-dev) - Active
- ✅ PGE/Verdi images (verdi, pge-base, cuda-pge-base) - Active
- ⚠️ Component images (mozart, metrics, grq, cont_int) - **Job definitions exist but currently commented out in workflow**

**`build-deploy-release` workflow:**
- ✅ All images configured with split builds for release tags (v6.*)

### ⚠️ Current Workflow Limitations

Component images (mozart, metrics, grq, cont_int) are fully implemented with split build jobs but are **commented out** in the `build-deploy-develop` workflow. To enable them, uncomment the corresponding sections in the workflow configuration.

## Testing the Implementation

### Monitoring Builds

For each image (e.g., `hysds_base`), watch for 3 jobs to appear:
- `build-hysds_base-amd64` - Builds on x86_64 executor
- `build-hysds_base-arm64` - Builds on ARM64 executor (`arm.medium` resource class)
- `build-hysds_base-manifest` - Creates multi-platform manifest

### Expected Behavior

1. **Parallel execution**: amd64 and arm64 jobs run simultaneously
2. **Sequential manifest**: manifest job waits for both architecture builds to complete
3. **Dependency chain**: Downstream images wait for manifest completion

### Expected Timeline (Example: hysds_base)

- amd64: ~10 minutes
- arm64: ~12 minutes (runs in parallel with amd64)
- manifest: <1 minute
- **Total: ~13 minutes** (vs 30 minutes with emulated buildx)

### Verifying Multi-Platform Support

After builds complete, verify the multi-platform manifest:
```bash
docker manifest inspect hysds/base:develop
```

You should see entries for both `linux/amd64` and `linux/arm64` platforms.

## Current Branch Status

Branch `HC-567` contains the complete split build implementation:

### What's Working
- ✅ All job definitions created for split builds
- ✅ Core images (base, dev, cuda-base, cuda-dev) active in workflows
- ✅ PGE/Verdi images active in workflows
- ✅ Support assets exported for both architectures
- ✅ Release workflow configured for all images

### What's Pending
- ⚠️ Component images (mozart, metrics, grq, cont_int) commented out in develop workflow
  - Jobs are defined and ready
  - Need to be uncommented and tested

### Next Steps

1. **Test current active builds** - Verify base, dev, cuda, and verdi images build successfully
2. **Enable component images** - Uncomment mozart, metrics, grq, cont_int in workflow
3. **Monitor build performance** - Track build times and resource usage
4. **Merge to develop** - Once all images are verified working

## Build Architecture Details

### Resource Classes

- **AMD64 jobs**: Default `medium` (2 vCPUs, 4GB RAM)
- **ARM64 jobs**: `arm.medium` (2 vCPUs, 4GB RAM)
- **Manifest jobs**: Default `medium` (minimal resources)

### Image Tagging Strategy

**Architecture-specific tags:**
- `hysds/base:develop-amd64`
- `hysds/base:develop-arm64`
- `hysds/base:v6.0.0-amd64` (for releases)
- `hysds/base:v6.0.0-arm64` (for releases)

**Multi-platform manifests:**
- `hysds/base:develop` (points to both architectures)
- `hysds/base:latest` (for releases)
- `hysds/base:v6.0.0` (for releases)

### Verdi Tarball Exports

The `build-hysds_verdi_pge_base-manifest` job exports both architectures:
- `hysds-verdi-develop.tar.gz` (amd64, no suffix for backwards compatibility)
- `hysds-verdi-develop-arm64.tar.gz` (arm64, with suffix)

## Rollback Plan

If issues arise, revert to the previous single-job approach by:
1. Restoring the original single-job definitions (with buildx emulation)
2. Updating workflow to use single jobs instead of split jobs
3. Re-enabling `resource_class: large` for emulated builds
4. Removing architecture-specific tag suffixes
