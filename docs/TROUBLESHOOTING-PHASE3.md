## Helm (Phase 3)

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