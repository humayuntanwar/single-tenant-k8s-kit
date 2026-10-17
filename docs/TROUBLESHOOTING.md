# Troubleshooting log

Real problems I hit while building this kit, what caused them, and how I fixed them.

## Setup

**Homebrew tried to compile Kubernetes from source and filled my disk.**
Cause: Homebrew no longer ships ready-made packages for macOS 14, so it builds from source.
Fix: installed kubectl, the AWS CLI and Terraform from their official downloads instead.
Lesson: when a package manager doesn't support your platform, go to the official binaries.

**Killed Docker by accident while freeing a port.**
Cause: `lsof` combines filters with OR, not AND, so my kill command matched OrbStack as well
as Python. Also, zsh doesn't treat `#` as a comment when typed, so the comment became arguments.
Fix: restarted OrbStack with `orb start`. Now I kill by exact PID.
Lesson: check what a command will match before running kill.

## Docker

**curl kept answering from my laptop, not the container.**
Cause: the local Python server and Docker were both on port 8080, and localhost reached Python first.
Fix: stopped the local server.
Lesson: `lsof -i :8080` shows who owns a port.

## Kubernetes

**Calico took about 5 minutes and the nodes stayed NotReady.**
Cause: normal. Each node downloads several Calico images and runs 4 setup steps.
Lesson: nodes are NotReady until a network plugin (CNI) is running.

**Deployment rejected: selector does not match template labels.**
Cause: wrong indentation. `template` sat inside `selector`, and `labels` wasn't under `metadata`.
Fix: fixed the indentation so selector and template are siblings under spec.
Lesson: in YAML, two spaces means "inside". Most Kubernetes errors are indentation.

**Pods stuck in ErrImagePull, then ImagePullBackOff.**
Cause: an editor autocomplete changed the image to `localhost:5000/tenant-api`, a registry that doesn't exist.
Fix: set the image back to `tenant-api:0.1.0`, the one loaded into kind.
Lesson: `kubectl get deploy -o jsonpath=...image` shows exactly what the cluster is trying to pull.

**"unknown field redinessProbe".**
Cause: a typo. Kubernetes rejects fields it doesn't know.
Fix: corrected the spelling.
Lesson: `kubectl apply --dry-run=server` checks files before applying anything.

**Crash drill returned 405 Method Not Allowed.**
Cause: my /crash route accepted GET instead of POST.
Fix: changed it to POST and released it as version 0.1.1, a new tag rather than overwriting 0.1.0.
It went out as a rolling update with no downtime.
Lesson: actions that change things should never be GET, and a fix gets a new version.

**Warning after rollout undo about last-applied-configuration.**
Cause: I changed the cluster by hand, so it could drift from my files.
Lesson: files in Git should be the source of truth. This is the problem GitOps (Argo CD) solves.

**EndpointSlice listed the broken pod's IP.**
Cause: EndpointSlices list every pod and mark each one ready or not.
Fix: checked with `-o yaml`. The broken pod showed `ready: false`, so it got no traffic.

## Drills (all passed)

| Drill | What happened |
|---|---|
| Delete a pod | New pod, new name, within seconds |
| Crash the process | Same pod, RESTARTS 0 → 1 |
| Ship a bad image (9.9.9) | One pod stuck pulling; old pods kept serving |
| Roll back | Bad pod gone, back to 0.1.1 |
| Break readiness | Pod Running but 0/1; got no traffic; old pods kept serving |
| Drain a node | Pods moved to the other worker; node brought back with uncordon |