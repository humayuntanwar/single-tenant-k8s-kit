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
- A chart is a folder: `Chart.yaml` (name and version), `values.yaml` (defaults), and `templates/` (Kubernetes files with blanks).
- One chart serves every customer. Each customer has a tiny values file with only what's different (tenant name, API key, replica count). Helm merges it over the defaults, and the customer's file wins.
- Templates use `{{ .Values.x }}`. The leading dot matters. A typo in a values key doesn't raise an error; it just renders empty, so a whole feature (like the quota) can silently disappear.
- `_helpers.tpl` holds shared snippets (the labels) so every object is labelled the same way. `include` pulls them in, and `nindent` sets the indentation, which must match the line's depth.
- `values.schema.json` checks settings before install. It refused an empty tenant name and the tag `latest`.
- `helm template` shows the final YAML without installing. Piping it into `kubectl apply --dry-run=server` checks the whole chart against the cluster in one go.
- A release is one customer's installed copy (`customer-a`). Every upgrade is a new revision, and `helm rollback` goes back to any revision in one command.
- Chart version and app version are different things. The chart was 0.1.0 while the app was 0.1.1.
- Helm says "deployed" as soon as Kubernetes accepts the change, even if the pods never start. In production, use `--wait` and roll back automatically on failure.
- Changing only the replica count adds pods without restarting the running ones.

## Terraform and AWS
- Terraform describes infrastructure as code. `plan` shows exactly what will change before anything is touched, and `apply` builds only what the saved plan says. That's what a change board wants to review.
- A **module** is a reusable recipe (VPC + EKS). Each customer is a small folder that calls it with its own name and network range. Same idea as a Helm chart plus values files, for the cloud.
- **State** is Terraform's record of what it built. Here it stayed on my laptop and out of Git; in production it lives in encrypted, locked S3 storage, one per customer.
- Using well-known community modules (`terraform-aws-modules/vpc` and `/eks`) gave me 56 production-style resources from about 80 lines of my own code, including things I wouldn't have thought of: KMS encryption for secrets, audit logs, and locked-down default security groups.
- **Private by design:** the nodes sit only in private subnets with no public IPs, reaching out through a NAT gateway. The cluster API only accepts one admin IP.
- **On EKS, the AWS VPC CNI replaces Calico.** Pods get real VPC IP addresses, and the same NetworkPolicy files still apply.
- The Helm chart ran on EKS **unchanged**. The only difference was the image location (private ECR instead of `kind load`).
- When something hangs in the cloud, the real error is often one layer down. My node group "creating" for 12 minutes was really the Auto Scaling group failing to launch a blocked instance type.
- Always destroy and **verify**: Terraform's "56 destroyed", then empty lists for clusters and NAT gateways, and delete anything created outside Terraform (the ECR repository).
