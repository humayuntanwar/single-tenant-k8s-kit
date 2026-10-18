Isolation (Day 2)
18. Six spelling mistakes across three files

Command

bash
kubectl apply -f k8s/customer-a/ -f k8s/customer-b/

What happened

unknown field "metadata.namepsace"
unknown field "spec.template.spec.containers[0].envFrom[0].ConfigMapRef"
unknown field "...securityContext.allowPrivilegeEsclations"
unknown field "...securityContext.readOnlyRootFileSystem"
unknown field "...volumeMounts[1].mounthPath"
unknown field "spec.egress[0].ports[1].portocol"

Cause: typos, plus field names are case-sensitive (configMapRef, readOnlyRootFilesystem). customer-b had the same typos because it was copied from customer-a. Fix: corrected customer-a only, then re-copied: rm -rf k8s/customer-b && cp -r k8s/customer-a k8s/customer-b && sed -i '' 's/customer-a/customer-b/g' k8s/customer-b/*.yaml. Lesson: fix the source, then regenerate the copies. This is exactly the job Helm takes over.

19. Pods stuck in ContainerCreating

Command

bash
kubectl get pods -n customer-a

What happened

tenant-api-...   0/1   ContainerCreating   0   3m51s

Diagnosis

bash
kubectl describe pod -n customer-a <pod> | tail -15
Warning  FailedMount  kubelet  MountVolume.SetUp failed for volume "secrets" : secret "tenent-api" not found

Cause: typo in secretName (tenent-api). Fix: secretName: tenant-api, re-copied to customer-b, applied. A rolling update replaced the stuck pods. Lesson: for a pod stuck before Running, kubectl describe pod and read the Events at the bottom.

20. Test pod rejected after I'd fixed it

Command

bash
kubectl apply -n customer-b -f tests/curl-pod.yaml

What happened

unknown field "spec.containers[0].resources.request"

Cause: I'd fixed request → requests in the editor but hadn't saved. Fix: saved (Cmd+S) and applied again.

21. DNS drill timed out instead of failing fast

Command

bash
kubectl delete networkpolicy allow-dns -n customer-b
kubectl exec -n customer-b curl -- curl -sv -m 5 http://tenant-api

What happened

* Resolving timed out after 5000 milliseconds
command terminated with exit code 28

Cause: with DNS blocked, the pod's DNS request is silently dropped, so it waits until curl's 5-second limit runs out. (I first ran the cross-customer command by mistake. The -v output proved it was DNS.) Fix: restored with kubectl apply -f k8s/customer-b/networkpolicy.yaml. Lesson: a timeout doesn't always mean the server is down. It can be DNS.

22. Root pod: blocked by the quota, then allowed (security label typo)

Command

bash
kubectl run root-test -n customer-a --image=nginx

What happened (1)

pods "root-test" is forbidden: failed quota: tenant-api: must specify requests.cpu ... requests.memory

The quota blocked it first. So I gave it requests:

bash
kubectl run root-test -n customer-a --image=nginx --overrides='{"spec":{"containers":[{"name":"root-test","image":"nginx","resources":{"requests":{"cpu":"10m","memory":"16Mi"}}}]}}'

What happened (2)

pod/root-test created

It should have been refused. Diagnosis

bash
kubectl get namespace customer-a --show-labels
... pod-security.kubernates.io/enforce=restricted

Cause: kubernates instead of kubernetes in the namespace label. Kubernetes ignores labels it doesn't recognise, so Pod Security was silently off, with no error. Fix: corrected the label, applied (Kubernetes immediately warned that root-test violated "restricted"), removed the bad label with kubectl label namespace customer-a pod-security.kubernates.io/enforce-, deleted root-test and retried:

Error from server (Forbidden): pods "root-test" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile

Lesson: a one-letter typo switched off a security control and nothing warned me. Test your controls; don't assume them.

23. Out-of-memory drill

Command

bash
# memory limit set to 20Mi in deployment.yaml
kubectl apply -f k8s/customer-a/

What happened (1)

spec.template.spec.containers[0].resources.requests: Invalid value: "64Mi": must be less than or equal to memory limit of 20Mi

Cause: the request (what a pod reserves) can't be bigger than the limit (its ceiling). Fix: set the request to 16Mi and the limit to 20Mi for the drill.

What happened (2)

Last State: Terminated   Reason: OOMKilled   Exit Code: 137
Liveness probe failed: ... connect: connection refused

Result: the pod was killed for going over its memory limit and kept restarting, while the two old pods kept serving. Then I set the memory back to 64Mi / 128Mi. Lesson: the memory limit is a hard cap enforced by the kernel. It's what stops one app from starving the others on a node.