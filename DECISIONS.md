# Decisions

## App

0. The app is deliberately small. The point of this kit is how one app gets deployed
   separately for each customer, not the app itself. A tiny FastAPI service with health
   checks and settings from environment variables is enough to test everything that matters:
   rollouts, restarts, isolation between customers and per-customer config. Any real app
   would slot into the same chart and Terraform without changing them.


1. One image for all customers. Each customer's settings come from environment variables.
   I didn't want a separate build per customer, because then you can't say every customer
   runs the same tested code.

2. Two health checks. /healthz tells Kubernetes the app is alive (if not, restart it).
   /readyz tells it the app can take traffic (if not, stop sending requests but don't kill it).

3. /crash is only there so I can practise failures. It's off unless ALLOW_CRASH is set,
   so it can't be used by accident.

4. Exact package versions in requirements.txt, so the build gives the same result every time.



## Container

5. The container runs as a normal user (uid 10001), not root. If someone breaks in, they can't do much. A bank's security review checks this first.

6. Two-stage build: one stage installs packages, the final image only gets the result.
      Smaller image, fewer things to patch.

7. Images get a version tag (0.1.0), never "latest". You always know exactly
      which build is running for each customer.


## Local cluster

8. kind for the local cluster. It runs real Kubernetes inside Docker on my laptop, for free.
   What works here works the same on EKS, because the Kubernetes API is the same.

9. Three nodes: one control plane and two workers. With two workers I can see pods spread
   across machines, and test what happens when one node has a problem.

10. Calico instead of kind's default network. The default one ignores NetworkPolicy, so the
    rules that keep one customer away from another would do nothing. Calico enforces them.
    On EKS the AWS network add-on does the same job, and the same policy files work there.


## Kubernetes basics

11. One namespace per customer. Each customer's things live in their own folder in the cluster,
    so rules and limits can be set per customer.

12. Two copies of the app (replicas: 2). If one pod or node dies, the other keeps serving.

13. The Service is internal only (ClusterIP). Nothing is reachable from outside unless I
    deliberately expose it, which is what a bank expects.
    
14. Separate liveness and readiness checks, tested by breaking readiness on purpose:
       the broken pod stayed alive but got no traffic, and the old pods kept serving.

## Isolation

15. Namespace per customer is the first step, not the whole answer. On its own it
    doesn't stop network traffic or bad pods, so I added three layers on top.

16. Default-deny network rules, then allow only same-customer traffic and DNS.
    Tested: customer-b timed out trying to reach customer-a.

17. Pod Security set to "restricted" on every customer namespace. Tested: a root nginx
    pod was refused. A one-letter typo in the label had silently switched it off,
    which I only caught by testing.

18. A quota per customer and a memory limit per pod. Tested: a pod over its limit was
    OOMKilled and restarted, while the other pods kept serving.

19. Secrets mounted as files, not environment variables, so they don't leak into logs.


## Helm

20. One chart for every customer, with a small values file each. Customers differ only in
    settings, never in code. Scaling customer-b to 3 pods didn't touch customer-a.

21. A values schema checks settings before anything is installed. Tested: an empty tenant
    name and the "latest" tag were both refused.

22. Helm keeps a history of every release, so rollback is one command. Tested: a broken
    image went out as revision 2, and I rolled back to revision 1.

23. Helm reports "deployed" even if the pods never start. In production I'd use --wait so
    a failed rollout is reported as a failure, and roll back automatically.

## AWS

24. One VPC and one EKS cluster per customer, from one Terraform module. A new customer is a new
    small folder, not new code.

25. Nodes only in private subnets, with no public IPs. Verified: EXTERNAL-IP was <none> on both nodes.

26. Cluster API only reachable from one admin IP. A bank would go further and use a private-only endpoint.

27. Graviton (ARM) nodes: cheaper, and they match the image built on my M1 Mac. t4g.small, because
    the AWS Free plan blocks t4g.medium.

28. Images in a private registry (ECR). Nodes can pull but not push.

29. One NAT gateway to save cost. Production would use one per zone, so losing a zone doesn't cut
    outbound traffic.

30. Destroy after every test, and verify it: 56 resources destroyed, then empty cluster and NAT lists.
