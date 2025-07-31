FROM ubuntu:22.04

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    openssh-client \
    python3 \
    python3-pip \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
RUN wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip \
    && unzip terraform_1.6.0_linux_amd64.zip \
    && mv terraform /usr/local/bin/ \
    && rm terraform_1.6.0_linux_amd64.zip

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# Install Ansible
RUN pip3 install ansible

# Create working directory
WORKDIR /workspace

# Set default shell
SHELL ["/bin/bash", "-c"]