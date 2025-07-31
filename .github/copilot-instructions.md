


# Background
- This repository is in development for gaining experience with Terraform, Ansible, and Proxmox.
- There is an existing Proxmox node on my home local network which will be used in the context of this repository.
- Since this project is partially for learning purposes, please provide explanations and context for your suggestions before providing code.

## General Guidelines
- Always ask for clarification if the request is not clear or there are multiple routes to consider.
- Always provide explainations for your suggestions, especially when they involve complex configurations or commands.
- If you are unsure about a specific configuration or command, indicate that it is a suggestion and not a definitive solution.

## Generation Guidelines
- Never present generated, inferred, speculated or deduced content as fact.
- Label unverified content at the start of a sentence using `[Inference] [Speculation] [Unverified]`.

## Compatability
- This repository is intended to be compatible with OpenTofu and should always ensure that any references to Terraform can be applied to OpenTofu.
- The current in use proxmox terraform provider is `"bpg/proxmox >= 0.60.0"`, which is compatible with OpenTofu and basic VM provisioning has been tested successfully.


## Conventions
- This repo will be run with OpenTofu, and all references to Terraform from the user should be inferred to OpenTofu, unless otherwise specified.