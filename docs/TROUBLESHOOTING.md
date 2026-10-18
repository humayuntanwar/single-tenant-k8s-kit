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

---

## Isolation (Day 2)

### 18. Six spelling mistakes across three files

**Command**
```bash
kubectl apply -f k8s/customer-a/ -f k8s/customer-b/
```
**What happened**
```
unknown field "metadata.namepsace"
unknown field "spec.template.spec.containers[0].envFrom[0].ConfigMapRef"
unknown field "...securityContext.allowPrivilegeEsclations"
unknown field "...securityContext.readOnlyRootFileSystem"
unknown field "...volumeMounts[1].mounthPath"
unknown field "spec.egress[0].ports[1].portocol"
```
**Cause:** typos, plus field names are case-sensitive (`configMapRef`, `readOnlyRootFilesystem`). customer-b had the same typos because it was copied from customer-a.
**Fix:** corrected customer-a only, then re-copied: `rm -rf k8s/customer-b && cp -r k8s/customer-a k8s/customer-b && sed -i '' 's/customer-a/customer-b/g' k8s/customer-b/*.yaml`.
**Lesson:** fix the source, then regenerate the copies. This is exactly the job Helm takes over.

### 19. Pods stuck in ContainerCreating

**Command**
```bash
kubectl get pods -n customer-a
```
**What happened**
```
tenant-api-...   0/1   ContainerCreating   0   3m51s
```
**Diagnosis**
```bash
kubectl describe pod -n customer-a <pod> | tail -15
Warning  FailedMount  kubelet  MountVolume.SetUp failed for volume "secrets" : secret "tenent-api" not found
```
**Cause:** typo in `secretName` (`tenent-api`).
**Fix:** `secretName: tenant-api`, re-copied to customer-b, applied. A rolling update replaced the stuck pods.
**Lesson:** for a pod stuck before Running, `kubectl describe pod` and read the Events at the bottom.

### 20. Test pod rejected after I'd fixed it

**Command**
```bash
kubectl apply -n customer-b -f tests/curl-pod.yaml
```
**What happened**
```
unknown field "spec.containers[0].resources.request"
```
**Cause:** I'd fixed `request` → `requests` in the editor but hadn't saved.
**Fix:** saved (Cmd+S) and applied again.

### 21. DNS drill timed out instead of failing fast

**Command**
```bash
kubectl delete networkpolicy allow-dns -n customer-b
kubectl exec -n customer-b curl -- curl -sv -m 5 http://tenant-api
```
**What happened**
```
* Resolving timed out after 5000 milliseconds
command terminated with exit code 28
```
**Cause:** with DNS blocked, the pod's DNS request is silently dropped, so it waits until curl's 5-second limit runs out. (I first ran the cross-customer command by mistake. The `-v` output proved it was DNS.)
**Fix:** restored with `kubectl apply -f k8s/customer-b/networkpolicy.yaml`.
**Lesson:** a timeout doesn't always mean the server is down. It can be DNS.

### 22. Root pod: blocked by the quota, then allowed (security label typo)

**Command**
```bash
kubectl run root-test -n customer-a --image=nginx
```
**What happened (1)**
```
pods "root-test" is forbidden: failed quota: tenant-api: must specify requests.cpu ... requests.memory
```
The quota blocked it first. So I gave it requests:
```bash
kubectl run root-test -n customer-a --image=nginx --overrides='{"spec":{"containers":[{"name":"root-test","image":"nginx","resources":{"requests":{"cpu":"10m","memory":"16Mi"}}}]}}'
```
**What happened (2)**
```
pod/root-test created
```
It should have been refused.
**Diagnosis**
```bash
kubectl get namespace customer-a --show-labels
... pod-security.kubernates.io/enforce=restricted
```
**Cause:** `kubernates` instead of `kubernetes` in the namespace label. Kubernetes ignores labels it doesn't recognise, so Pod Security was silently off, with no error.
**Fix:** corrected the label, applied (Kubernetes immediately warned that `root-test` violated "restricted"), removed the bad label with `kubectl label namespace customer-a pod-security.kubernates.io/enforce-`, deleted `root-test` and retried:
```
Error from server (Forbidden): pods "root-test" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
```
**Lesson:** a one-letter typo switched off a security control and nothing warned me. Test your controls; don't assume them.

### 23. Out-of-memory drill

**Command**
```bash
# memory limit set to 20Mi in deployment.yaml
kubectl apply -f k8s/customer-a/
```
**What happened (1)**
```
spec.template.spec.containers[0].resources.requests: Invalid value: "64Mi": must be less than or equal to memory limit of 20Mi
```
**Cause:** the request (what a pod reserves) can't be bigger than the limit (its ceiling).
**Fix:** set the request to 16Mi and the limit to 20Mi for the drill.

**What happened (2)**
```
Last State: Terminated   Reason: OOMKilled   Exit Code: 137
Liveness probe failed: ... connect: connection refused
```
**Result:** the pod was killed for going over its memory limit and kept restarting, while the two old pods kept serving. Then I set the memory back to 64Mi / 128Mi.
**Lesson:** the memory limit is a hard cap enforced by the kernel. It's what stops one app from starving the others on a node.

---

## Helm (Day 3)

### 24. Schema rejected the values: missing image tag

**Command**
```bash
helm lint helm/tenant-api -f helm/tenant-api/values-customer-a.yaml
```
**What happened**
```
[ERROR] values.yaml: - at '/image': missing property 'tag'
```
**Cause:** `tag` wasn't nested under `image:` in `values.yaml` (an indentation or spelling slip).
**Fix:** `repository` and `tag` both indented two spaces under `image:`.
**Lesson:** the values schema caught a bad setting before anything was installed. That's exactly its job.

### 25. "qouta" and "qoute": one loud error, one silent one

**Command**
```bash
helm lint helm/tenant-api -f helm/tenant-api/values-customer-a.yaml
```
**What happened**
```
[ERROR] templates/: parse error at (tenant-api/templates/resourceqouta.yaml:10): function "qoute" not defined
```
**Cause:** I'd swapped the letters throughout the file: `qoute` instead of `quote` (loud, because Helm doesn't know that function) and `.Values.qouta` instead of `.Values.quota` (silent). Because `qouta` didn't exist in my values, `if .Values.qouta.enabled` was always false, so **the quota would never have been created**, with no error.
**Fix:** corrected every occurrence, renamed the file to `resourcequota.yaml`, and confirmed the quota really renders:
```bash
helm template customer-a helm/tenant-api -f helm/tenant-api/values-customer-a.yaml | grep -A6 "kind: ResourceQuota"
```
**Lesson:** a typo in a values key fails silently in a template. Check the rendered output, not just that lint passes. (Same trap as the `kubernates` label on Day 2.)

### 26. Missing dot before Values

**What happened**
```
[ERROR] templates/: parse error at (tenant-api/templates/networkpolicy.yaml:1): function "Values" not defined
```
**Cause:** `{{- if Values.networkPolicy.enabled }}` had no leading dot.
**Fix:** `{{- if .Values.networkPolicy.enabled }}`.
**Lesson:** in Helm, `.` is everything passed to the template. Without it, Helm thinks `Values` is a function.

### 27. Nil pointer in the helper file

**What happened**
```
executing "tenant-api.labels" at <.Value.image.tag>: nil pointer evaluating interface {}.image
```
**Cause:** `.Value` instead of `.Values` in `_helper.tpl`. The error surfaced in `service.yaml`, because that's where the helper was first used.
**Fix:** `.Values.image.tag`.
**Lesson:** read Helm errors from the bottom. The real problem is the last file and line in the chain.

### 28. Quota section missing from values.yaml

**What happened**
```
executing "tenant-api/templates/resourcequota.yaml" at <.Values.quota.enabled>: nil pointer evaluating interface {}.enabled
```
**Cause:** once the template was fixed, it showed my `values.yaml` had no `quota:` section (it was misspelled there too).
**Fix:** added `quota:` (with `enabled`, `cpu`, `memory`) to `values.yaml`. Searched for leftovers with `grep -rn "qouta\|qoute\|\.Value\." helm/`.

### 29. Install failed: four problems at once

**Command**
```bash
helm install customer-a helm/tenant-api -n customer-a -f helm/tenant-api/values-customer-a.yaml
```
**What happened**
```
Kind=Secret: error decoding from json: illegal base64 data at input byte 4
.spec.template.metadata.app.kubernetes.io/instance: field not declared in schema
...securityContext.allowPrivilegeEsclation: field not declared in schema
.spec.template.volumes: field not declared in schema
```
**Cause**
- The Secret used `data:`, which must be base64-encoded, instead of `stringData:`, which takes plain text.
- `nindent 6` instead of `nindent 8` under `template.metadata.labels`, so the labels landed directly under `metadata`.
- A typo: `allowPrivilegeEsclation`.
- `volumes:` indented 4 spaces instead of 6, so it fell outside the pod `spec`.
- Also `imagePullPolicy: {{ .Values.image.pullPolicy }}`, a value that doesn't exist (it rendered blank).

**Fix:** `stringData:`, `nindent 8`, the spelling, `volumes:` lined up with `containers:`, and `imagePullPolicy: IfNotPresent`. Cleared the failed release with `helm uninstall customer-a -n customer-a`.
**Lesson:** each `nindent` number must match how deeply that line sits: 4 under `metadata.labels`, 6 under `selector.matchLabels`, 8 under `template.metadata.labels`, 12 under `resources`.

### 30. Helper name didn't match

**What happened**
```
template: no template "tenant-api.selectorLabels" associated with template "gotpl"
```
**Cause:** the helper was defined as `selectorsLabels` but called as `selectorLabels`.
**Fix:** made the `define` name and the `include` name identical. Checked with `grep -n "define" helm/tenant-api/templates/_helper*.tpl`.

### 31. Label command cut off

**Command**
```bash
kubectl label namespace customer-a pod-
```
**What happened**
```
label "pod" not found.
```
**Cause:** the line wrapped when pasting, so only `pod-` arrived. A trailing `-` means "remove this label".
**Fix:** ran the full command on one line: `kubectl label namespace customer-a pod-security.kubernetes.io/enforce=restricted`.

### The trick that ended the guessing

Render the chart and let the cluster check it, without installing anything:
```bash
helm template customer-a helm/tenant-api -f helm/tenant-api/values-customer-a.yaml | kubectl apply --dry-run=server -n customer-a -f -
```
Every object came back `created (server dry run)`, and then the real install worked first time.

---

## Terraform and AWS (Day 4)

### 32. Terraform didn't recognise a block

**Command**
```bash
terraform init
```
**What happened**
```
Error: Unsupported argument
  on ../../modules/customer-env/main.tf line 1:
   1: data = "aws_availability_zones" "available"{
An argument named "data" is not expected here.
```
**Cause:** I'd written an `=` after `data`. In Terraform, blocks (`data`, `module`, `variable`, `output`) take no `=`; only the arguments inside a block do.
**Fix:** `data "aws_availability_zones" "available" {`.

### 33. Plan failed: wrong AMI name and no subnets for the cluster

**Command**
```bash
terraform plan -var "admin_cidr=$(curl -s ifconfig.me)/32"
```
**What happened**
```
Call to function "coalescelist" failed: no non-null arguments.   (subnet_ids is empty)
var.ami_type is "ALS2023_ARM_64_STANDARD"
The given key does not identify an element in this collection value.
```
**Cause:** two slips. `ALS2023` had an extra S (it should be `AL2023`), and the VPC module's private subnets weren't being created, so the cluster received an empty subnet list.
**Fix:** corrected the AMI type and the `module "vpc"` subnet lines. The plan then showed `56 to add, 0 to change, 0 to destroy`.
**Lesson:** `plan` catches these before anything touches AWS, so read it to the end.

### 34. EKS nodes never appeared (account plan blocked the instance type)

**Command**
```bash
terraform apply tfplan
```
**What happened:** the node group sat at `Still creating...` for 12+ minutes. `describe-nodegroup` showed `status: CREATING` with no health issues, and no EC2 instances existed at all.
**Diagnosis:** the real reason was in the Auto Scaling group's activity log, not in Terraform's output:
```bash
aws autoscaling describe-scaling-activities --auto-scaling-group-name <asg> --region eu-west-2
Failed | Could not launch On-Demand Instances. InvalidParameterCombination -
The specified instance type is not eligible for Free Tier.
```
`aws freetier get-account-plan-state` confirmed the account was on the **Free plan**.
**Fix:** listed the allowed types (`aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true`) and switched from `t4g.medium` to `t4g.small`, still ARM and Graviton, so no image rebuild. One Ctrl+C stopped the apply cleanly; the failed node group was marked tainted, and the next apply replaced it in under 2 minutes (`3 added, 1 destroyed`).
**Lesson:** when a cloud resource hangs, look one layer down (here, the Auto Scaling group) for the actual error.

### 35. Pods on EKS stuck in ImagePullBackOff

**Command**
```bash
helm install customer-a helm/tenant-api -n customer-a -f helm/tenant-api/values-customer-a.yaml --set image.respository=#REGISTRY/tenant-api
```
**What happened:** both pods went `ImagePullBackOff`, even though Helm said `deployed`.
**Cause:** two typos. `respository` instead of `repository` (Helm silently ignores unknown keys, so the default local image name was kept) and `#REGISTRY` instead of `$REGISTRY` (zsh treated the rest of the line as a comment). EKS tried to pull `tenant-api` from the public internet.
**Fix:** `helm upgrade ... --set image.repository=$REGISTRY/tenant-api`. Both pods were `1/1 Running`, one per node, within seconds.
**Lesson:** the same as Day 1: for `ImagePullBackOff`, check which image the cluster is actually pulling.

### 36. Small AWS gotchas

- **AWS CLI output stopped at `:`.** That's a pager, not an error. Press `q`, or `export AWS_PAGER=""`.
- **"An AWS account with that sign-in information does not exist".** Wrong sign-in door: root uses the email; IAM users use the account ID plus username. Use a private window if old cookies interfere.
- **EKS version.** The module defaulted to Kubernetes 1.33, which by now is past standard support (extended support costs more per hour). Check current versions with `aws eks describe-cluster-versions` before applying.
