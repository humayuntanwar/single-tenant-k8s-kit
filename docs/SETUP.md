# Setup

Tested on a MacBook Air M1 (Apple Silicon), macOS 14.

## Tools and the versions I used

| Tool | Version | What it's for |
|---|---|---|
| Docker (via OrbStack) | 29.8.2 | Builds and runs containers |
| kind | 0.33.0 | Runs a Kubernetes cluster inside Docker |
| kubectl | 1.37.1 | Talks to the cluster |
| Helm | 4.3.0 | Packages the app for each customer |
| Terraform | 1.16.6 | Builds the AWS network and cluster |
| AWS CLI | 2.38.1 | Talks to AWS |
| Python | 3.12 | The app |

## Install

kind and Helm:

    brew install kind helm

Docker: install OrbStack from https://orbstack.dev, open it once, pick Docker.

kubectl, the AWS CLI and Terraform: Homebrew no longer has ready-made packages for macOS 14
and tries to compile them (slow, and it filled my disk), so I used the official downloads:

    # kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/darwin/arm64/kubectl"
    chmod +x kubectl && sudo mv kubectl /usr/local/bin/

    # AWS CLI
    curl -o AWSCLIV2.pkg "https://awscli.amazonaws.com/AWSCLIV2.pkg"
    sudo installer -pkg AWSCLIV2.pkg -target /

    # Terraform
    brew install hashicorp/tap/terraform

On a newer macOS, `brew install kubectl awscli` works fine.

Check everything:

    kind version; kubectl version --client; helm version --short
    terraform version; aws --version; docker version --format '{{.Client.Version}}'

## AWS account (only needed for the EKS part)

1. Turn on MFA for the root user, and never use root again.
2. Create an IAM user for yourself with an access key.
3. Set a $20 budget alert.
4. Run `aws configure` with region `eu-west-2` (London), then check with `aws sts get-caller-identity`.
5. **On the AWS Free plan, only some instance types are allowed.** Check with
   `aws ec2 describe-instance-types --region eu-west-2 --filters Name=free-tier-eligible,Values=true`.
   This kit uses `t4g.small` (ARM) for that reason.
6. Check a supported EKS version before applying:
   `aws eks describe-cluster-versions --region eu-west-2`.
7. Cost: about $1–2 if you destroy in the same session. Always finish with `terraform destroy`
   and check that `aws eks list-clusters` and the NAT gateway list are empty.

## Local cluster

    kind create cluster --config kind/cluster.yaml
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/v3_projectcalico_org.yaml
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/tigera-operator.yaml
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/custom-resources.yaml
    kubectl get pods -n calico-system -w     # wait for 1/1 Running (2-5 minutes), then Ctrl+C
    kubectl get nodes                        # all Ready

The Calico CRD file above is for Kubernetes 1.36 and later (kind 0.33 runs 1.37).
