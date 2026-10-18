# Tests conducted

Every test I ran on purpose to prove the kit behaves the way I claim. All passed unless noted.

## Day 1: one customer on Kubernetes

| # | Test | Command | Expected | Result |
|---|---|---|---|---|
| 1 | Container runs as non-root | `docker run --rm tenant-api:0.1.0 id` | uid 10001 | ✅ uid=10001(appuser) |
| 2 | App answers through Kubernetes | `kubectl port-forward ... 8080:80` + `curl localhost:8080/` | tenant customer-a | ✅ |
| 3 | Delete a pod | `kubectl delete pod -n customer-a <pod>` | New pod, new name | ✅ |
| 4 | Crash the process | `kubectl exec ... /crash` | Same pod, RESTARTS 0 → 1 | ✅ exit 137, restarted in place |
| 5 | Ship a bad image | `kubectl set image ... api=tenant-api:9.9.9` | One pod stuck pulling, old pods serve | ✅ ImagePullBackOff, no outage |
| 6 | Roll back | `kubectl rollout undo -n customer-a deploy/tenant-api` | Bad pod gone | ✅ |
| 7 | Break readiness | Readiness path `/nope`, apply | Pod Running 0/1, gets no traffic | ✅ EndpointSlice showed `ready: false` |
| 8 | Lose a node | `kubectl drain kit-worker ...` | Pods move to the other worker | ✅ then `uncordon` |
| 9 | Release a fix with no downtime | Built 0.1.1 (POST /crash fix), applied | Rolling update, no outage | ✅ |

## Day 2: two isolated customers

| # | Test | Command | Expected | Result |
|---|---|---|---|---|
| 10 | Same customer can talk | From customer-b: `curl http://tenant-api` | tenant customer-b | ✅ |
| 11 | **Cross customer blocked** | From customer-b: `curl http://tenant-api.customer-a.svc.cluster.local` | Times out | ✅ exit 28 |
| 12 | DNS blocked without its rule | Delete `allow-dns`, curl again | Name can't resolve | ✅ "Resolving timed out", then restored |
| 13 | Pod without resources refused | `kubectl run root-test --image=nginx` | Refused by the quota | ✅ "must specify requests.cpu" |
| 14 | **Root pod refused** | Same pod, with requests | Refused by Pod Security | ⚠️ First **allowed**: a typo (`kubernates`) in the label had switched it off. ✅ After the fix: forbidden, with all 4 violations listed |
| 15 | Memory limit enforced | Limit 20Mi | Pod killed, others keep serving | ✅ OOMKilled, exit 137 |

## Day 3: one Helm chart for every customer

| # | Test | Command | Expected | Result |
|---|---|---|---|---|
| 16 | Whole chart valid | `helm template ... \| kubectl apply --dry-run=server -f -` | All objects accepted | ✅ 8 objects |
| 17 | Two customers from one chart | `helm install customer-a ...` / `customer-b ...` | Both deployed | ✅ |
| 18 | Isolation still holds | Cross-customer curl from customer-b | Times out | ✅ exit 28 |
| 19 | Broken release | `helm upgrade ... --set image.tag=9.9.9` | One pod stuck, old pods serve | ✅ (Helm still said "deployed") |
| 20 | Roll back | `helm rollback customer-a 1 -n customer-a` | Back to working pods | ✅ |
| 21 | Missing tenant name refused | `helm install test helm/tenant-api -n default` | Refused by the schema | ✅ "minLength: got 0, want 1" |
| 22 | `latest` tag refused | `... --set image.tag=latest` | Refused by the schema | ✅ "'not' failed" |
| 23 | Scale one customer only | `replicas: 3` for customer-b, upgrade | customer-b 3, customer-a 2 | ✅ one pod added, none restarted |

## What I'd add next
- Automated versions of tests 11, 14 and 21, run in CI on every change.
- Upgrades with `--wait`, so test 19 is reported as a failure instead of "deployed".