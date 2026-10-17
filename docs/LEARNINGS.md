# What I learned

Notes on each technology

## Docker
- An image is a packaged app plus everything it needs. A container is a running copy of it.
- A two-stage build installs packages in one stage and copies only the result into the final
  image, so the image is smaller and has less to patch.
- Run as a normal user, not root. `docker run ... id` proves it.
- Never use `latest`. A version tag tells you exactly what's running. When I fixed a bug,
  I released 0.1.1 instead of overwriting 0.1.0.

## kind
- Runs a real Kubernetes cluster inside Docker on a laptop. Each "node" is a container.
- `kind load docker-image` copies a local image into the nodes. On AWS that job belongs
  to a private registry (ECR).

## Kubernetes
- Namespace = a folder for one customer's resources.
- Deployment = "keep N copies running". It replaces anything that dies.
- Service = one stable name and address in front of pods that come and go.
- Liveness decides "restart it?". Readiness decides "send it traffic?". I broke readiness
  on purpose: the pod stayed alive but got no traffic.
- A rolling update only removes old pods once the new ones are ready, so a bad image
  didn't cause an outage. Rollback is one command.
- Draining a node moves its pods elsewhere first. That's how servers get patched with no downtime.
- Changing things by hand makes the cluster drift from the files. The files should be the
  source of truth.

## Calico
- The cluster's network (CNI). Without it, nodes stay NotReady.
- It also enforces NetworkPolicy, the rules that keep customers apart. kind's default
  network doesn't, which is why I swapped it out.
- On EKS, the AWS VPC CNI does this job instead, and the same policy files work.

## Helm


## Terraform and AWS
