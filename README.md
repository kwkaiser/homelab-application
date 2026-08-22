### homelab-application

The application-side code of my local homelab. This is the sister repo of the corresponding `homelab-system` project, which handles the system-side (OS) installation.

### File structure

**`templates`**:
Contains `.yaml` template files for deploying applications, services, etc. 

**`config`**:
Contains config files mounted into the applications

**`values`**:
Contains value files for environmentally-dependent configs

**`secretspec.toml`**:
Declares every secret the chart needs, per environment profile (`default` = prod, `dev`). Real values are resolved from a kdbx vault (or, in CI, from already-set env vars) via [secretspec](https://github.com/cachix/secretspec) - see `task apply-secrets`.

### Deployments
This repo relies heavily on [taskfile.dev](https://taskfile.dev/) for most development / deployment operations