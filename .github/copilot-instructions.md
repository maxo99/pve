


# Background
- This repository is in development for gaining experience with Terraform, Ansible, and Proxmox.
- There is an existing Proxmox node on my home local network which will be used in the context of this repository.
- Provide explanations and context for your suggestions.
- The end goal is to have a fully automated Proxmox homelab setup, with OpenTofu managing the Proxmox nodes and virtual machines.
- Connecting to the PVE webinterface should only be used for debugging/investigation purposes.
- Multiple sample repositories may inspire this project - avoid straying far from established patterns.

## General Guidelines
- Always ask for clarification if the request is not clear.
- **IMPORTANT** If there are multiple routes or options, provide a single numbered list of options so that one can be selected before diving into a specific solution.
- If multiple commands are needed, provide them in sub-list format once the main approach is selected.
- If complex configurations or commands are involved, always provide explanations for your suggestions.


## Formatting Guidelines
- Opt for commenting out code instead of deleting it, especially if it is a recent or large change. 
- Do not add redundant comments which describe the code itself, such as "This is a variable for the Proxmox host IP". Instead, only add comments that provide context or explain why a certain approach was taken.

## Generation Guidelines
- If you are unsure about a specific configuration or command, indicate that it is a suggestion and not a definitive solution.
- Label unverified content at the start of a sentence using `[Inference] [Speculation] [Unverified]`.

## Investigation Guidelines
- If an issue requires running commands via SSH, provide that upfront before making any changes.

## Project Context
- Review the .github/project-context.instructions.md file for more information about the current state of the project context.
- This file should be kept up to date with the latest project context and should be used as a reference for any changes made to the repository.
- Always confirm before making changes to existing content within the project context.