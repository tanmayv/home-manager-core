# Release Management

This document outlines the process for managing releases and tags in the Minimal Cloudtop Home Manager configuration.

## Versioning Strategy

We use Semantic Versioning (SemVer) with annotated Git tags for specific releases (e.g., `v0.1.0`, `v1.2.3`).

In addition to version-specific tags, we maintain a rolling `stable` tag that always points to the latest recommended release. This provides a simple, predictable URL for users to clone the configuration without needing to know the exact version number.

## Creating a New Release

When the `main` branch is ready for a new release, follow these steps:

### 1. Tag the Specific Version

Create an annotated tag for the new version and push it to Gerrit:

```bash
git checkout main
git pull --rebase
git tag -a v0.2.0 -m "Release version 0.2.0"
git push origin v0.2.0
```

### 2. Move the `stable` Tag

Update the `stable` tag to point to the new release commit. Because `stable` is a moving tag, you must delete the old one and force-push the new one.

```bash
# Delete the local stable tag
git tag -d stable

# Recreate the stable tag at the current HEAD
git tag -a stable -m "Stable release v0.2.0"

# Force-push the updated stable tag to Gerrit
git push origin stable --force
```

*Note: Ensure your Gerrit access controls allow "Push Annotated Tag" and "Delete Reference" for tags.*

## User Instructions

Users should be instructed to clone the `stable` branch to get the latest reliable configuration:

```bash
git clone -b stable --single-branch sso://user/tanmayvijay/home-manager-minimal-ai ~/.config/minimal-cloudtop
```

## Hotfixes (Cherry-Picking)

If a critical bug is found in a released version (e.g., `v0.1.0`) while development has continued on `main`:

1.  **Create a Release Branch**: Create a branch from the affected tag.
    ```bash
    git checkout -b release-0.1 v0.1.0
    ```
2.  **Fix in Main**: Fix the bug on `main` and submit the CL through the standard review process.
3.  **Cherry-Pick**: Cherry-pick the fix commit from `main` to the `release-0.1` branch. You can do this via the Gerrit UI (clicking "Cherry Pick") or locally.
    ```bash
    git cherry-pick <commit-hash>
    git push origin HEAD:refs/for/release-0.1
    ```
4.  **Tag the Hotfix**: Once the cherry-pick is merged, tag the new release on the `release-0.1` branch (e.g., `v0.1.1`).
    ```bash
    git checkout release-0.1
    git pull --rebase
    git tag -a v0.1.1 -m "Hotfix release v0.1.1"
    git push origin v0.1.1
    ```
5.  **Update Stable**: If `v0.1.1` is now the latest stable version, move the `stable` tag to it following the instructions in Step 2.
