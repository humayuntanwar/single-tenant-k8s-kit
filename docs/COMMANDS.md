# Key commands

The commands I actually used to build this kit, grouped by tool, with what each one does.

---

## Check the tools

| Command | What it does |
|---|---|
| `kind version; kubectl version --client; helm version --short; terraform version; aws --version; docker version --format '{{.Client.Version}}'` | Prints every tool's version. If a line says "command not found", that tool isn't installed |
| `df -h /` | Shows free disk space |

## Python app (run locally)

| Command | What it does |
|---|---|
| `python3 -m venv .venv` | Creates a private Python environment for the project |
| `source .venv/bin/activate` | Switches into it. The prompt starts with `(.venv)` |
| `pip install -r app/requirements.txt` | Installs the exact package versions listed |
| `TENANT_NAME=local uvicorn main:app --port 8080` | Runs the app on port 8080, with the tenant name set |
| `curl localhost:8080/` | Calls the app and shows its reply |

## Docker

| Command | What it does |
|---|---|
| `docker build -t tenant-api:0.1.1 app/` | Builds the image from the `app/` folder, with a version tag |
| `docker run --rm tenant-api:0.1.1 id` | Runs the image just to show which user it runs as (should be uid 10001) |
| `docker run --rm -p 8080:8080 -e TENANT_NAME=docker tenant-api:0.1.1` | Runs the app in a container. `-p` connects the port, `-e` sets a setting |
| `docker ps` | Lists running containers (your kind nodes show up here too, so leave those alone) |
| `docker images tenant-api` | Lists your built images |
| `docker stop <container-id>` | Stops one container |
| `orb start` / `orb status` | Starts OrbStack (Docker) / checks it's running |

## Ports and processes (macOS)

| Command | What it does |
|---|---|
| `lsof -i :8080` | Shows which programs are using port 8080 |
| `kill <PID>` | Stops one exact process. Use the PID, not a pattern |

## kind (local cluster)

| Command | What it does |
|---|---|
| `kind create cluster --config kind/cluster.yaml` | Builds the 3-node cluster from the config file |
| `kind load docker-image tenant-api:0.1.1 --name kit` | Copies a local image into the cluster's nodes |
| `kind delete cluster --name kit` | Deletes the whole cluster |

## Calico (network)

| Command | What it does |
|---|---|
| `kubectl create -f .../v3_projectcalico_org.yaml` | Teaches Kubernetes Calico's object types (CRDs) |
| `kubectl create -f .../tigera-operator.yaml` | Installs the operator that manages Calico |
| `kubectl create -f .../custom-resources.yaml` | Tells the operator to install Calico |
| `kubectl get pods -n calico-system` | Checks Calico is running |

## kubectl: looking around

| Command | What it does |
|---|---|
| `kubectl get nodes` | Lists the servers and whether they're Ready |
| `kubectl get pods -n customer-a` | Lists pods in one namespace |
| `kubectl get pods -n customer-a -o wide` | Same, plus IP addresses and which node each pod is on |
| `kubectl get pods -n customer-a -w` | Keeps watching and prints every change (Ctrl+C to stop) |
| `kubectl get pods -A` | Pods in all namespaces |
| `kubectl describe pod -n customer-a <pod>` | Full details of one pod. The Events at the bottom explain why it's stuck |
| `kubectl get deploy tenant-api -n customer-a -o jsonpath='{.spec.template.spec.containers[0].image}'` | Shows exactly which image the cluster is trying to run |
| `kubectl get endpointslices -n customer-a -o yaml \| grep -E "addresses\|ready:" -A1` | Shows which pod IPs the Service sends traffic to (`ready: true`) |
| `kubectl get namespace customer-a --show-labels` | Shows a namespace's labels, such as Pod Security |
| `kubectl get secret,configmap -n customer-a` | Lists Secrets and ConfigMaps |

## kubectl: making changes

| Command | What it does |
|---|---|
| `kubectl apply -f k8s/customer-a/` | Makes the cluster match every file in the folder. Safe to re-run |
| `kubectl apply -f k8s/ --dry-run=server` | Checks files against the cluster without changing anything. Catches typos |
| `kubectl delete pod -n customer-a <pod>` | Deletes a pod. The Deployment makes a new one |
| `kubectl delete namespace customer-a` | Deletes the namespace and everything in it |
| `kubectl label namespace customer-a pod-security.kubernetes.io/enforce=restricted` | Adds a label |
| `kubectl label namespace customer-a <label-key>-` | Removes a label (note the `-` at the end) |

## kubectl: testing and drills

| Command | What it does |
|---|---|
| `kubectl port-forward -n customer-a svc/tenant-api 8080:80` | Temporary tunnel from my Mac to the Service, for testing only |
| `kubectl exec -n customer-b curl -- curl -s -m 5 http://tenant-api` | Runs curl from inside a pod. `-m 5` gives up after 5 seconds |
| `kubectl exec -n customer-b curl -- curl -sv -m 5 http://tenant-api` | Same with `-v`, which shows where it got stuck (DNS or connecting) |
| `kubectl set image -n customer-a deploy/tenant-api api=tenant-api:9.9.9` | Changes the image by hand (used to ship a bad version on purpose) |
| `kubectl rollout undo -n customer-a deploy/tenant-api` | Goes back to the previous version |
| `kubectl rollout restart deploy/tenant-api -n customer-a` | Restarts all pods one by one |
| `kubectl drain kit-worker --ignore-daemonsets --delete-emptydir-data` | Empties a node, as if taking it down for maintenance |
| `kubectl uncordon kit-worker` | Lets pods run on that node again |
| `kubectl run root-test -n customer-a --image=nginx --overrides='...'` | Tries to start a pod that runs as root, to test Pod Security |

## Files

| Command | What it does |
|---|---|
| `cp -r k8s/customer-a k8s/customer-b` | Copies a folder |
| `sed -i '' 's/customer-a/customer-b/g' k8s/customer-b/*.yaml` | Find and replace in every file (the `''` is a macOS quirk) |
| `rm -rf k8s/customer-b` | Deletes a folder (careful) |

## Git

| Command | What it does |
|---|---|
| `git status` | Shows what's changed |
| `git add <files>` | Picks changes for the next commit |
| `git diff --staged` | Shows exactly what will be committed |
| `git commit -m "message"` | Saves a snapshot |
| `git push` | Sends commits to GitHub |
| `git tag day-1` / `git push --tags` | Marks a commit with a name, and sends tags to GitHub |
| `git tag -f day-1` / `git push origin day-1 --force` | Moves an existing tag to the latest commit |
| `git log --oneline --decorate -3` | The last 3 commits, with their tags |
| `git show day-1:k8s/deployment.yaml` | Shows a file as it was at a tag |

## Helm

| Command | What it does |
|---|---|
| `helm lint helm/tenant-api -f helm/tenant-api/values-customer-a.yaml` | Checks the chart for mistakes |
| `helm template customer-a helm/tenant-api -f ... \| kubectl apply --dry-run=server -n customer-a -f -` | Renders the chart and has the cluster check every object, without installing |
| `helm install customer-a helm/tenant-api -n customer-a -f helm/tenant-api/values-customer-a.yaml` | Installs one customer |
| `helm upgrade customer-a helm/tenant-api -n customer-a -f ... --set image.tag=9.9.9` | Changes a release (used to ship a bad version on purpose) |
| `helm history customer-a -n customer-a` | Every revision of a release |
| `helm rollback customer-a 1 -n customer-a` | Goes back to revision 1 |
| `helm list -A` | All releases in all namespaces |
| `helm uninstall customer-a -n customer-a` | Removes a release |

## Terraform

| Command | What it does |
|---|---|
| `terraform init` | Downloads the AWS provider and modules (into `.terraform/`, ignored by Git) |
| `terraform fmt -recursive` | Tidies the formatting |
| `terraform validate` | Checks the code without contacting AWS |
| `terraform plan -var "admin_cidr=$(curl -s ifconfig.me)/32" -out tfplan` | Works out what would change and saves the exact plan |
| `terraform apply tfplan` | Builds exactly what the saved plan says |
| `terraform destroy -var "admin_cidr=$(curl -s ifconfig.me)/32"` | Deletes everything Terraform built |

## AWS

| Command | What it does |
|---|---|
| `aws sts get-caller-identity` | Which account and user I'm logged in as |
| `aws freetier get-account-plan-state --region us-east-1` | Free or Paid plan, and the credit left |
| `aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true` | Instance types the Free plan allows |
| `aws eks describe-cluster-versions --region eu-west-2` | Supported EKS versions |
| `aws eks update-kubeconfig --region eu-west-2 --name customer-a-eks` | Points kubectl at the EKS cluster |
| `kubectl config use-context kind-kit` | Points kubectl back at the local cluster |
| `aws eks describe-nodegroup ... --query 'nodegroup.{status:status,health:health.issues}'` | Node group status and any health problems |
| `aws autoscaling describe-scaling-activities --auto-scaling-group-name <asg>` | Why servers did or didn't launch (found the Free-plan block here) |
| `aws ecr create-repository --repository-name tenant-api` | Creates a private image registry |
| `aws ecr get-login-password \| docker login --username AWS --password-stdin $REGISTRY` | Logs Docker in to ECR |
| `docker tag ... $REGISTRY/tenant-api:0.1.1` / `docker push ...` | Uploads the image to ECR |
| `aws eks list-clusters` / `aws ec2 describe-nat-gateways ...` | Teardown checks: both must be empty |
| `aws ecr delete-repository --repository-name tenant-api --force` | Deletes the registry and its images |
| `export AWS_PAGER=""` | Stops the AWS CLI opening output in a pager |

## zsh tip

| Command | What it does |
|---|---|
| `echo 'setopt interactivecomments' >> ~/.zshrc && source ~/.zshrc` | Makes `#` comments work when pasted into the terminal |