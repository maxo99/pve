---
mode: agent
---
# Request for LXC conversion
- I would like to add an LXC to my PVE deployment through using tofu. 
- The LXC has a proxmox helper-scripts LXC install script which has been copied into the .tmp folder along with some of the other scripts that it sources. If any additional scripts should be pulled request those. 
- There are multiple LXCs already managed in this repo and those should be referenced for common configuration.
- The LXCs in this repo source use a templated hookscript and helpers.sh which will be used to maintatin common setup operations. 
- This should be kept simple for this inital request, bringing in necessary elements from the helper-scripts while conforming to the format present for the LXCs already in use.


## Operation Steps
1. Evaluate all the context provided.
2. Ask for clarification if any details are not clear or decisions are available prior before creating the plan.
3. Once details are agreed upon provide a brief plan of action. 
4. If plan is approved create initial draft with focus on simplicity over verbosity. 
5. If any additional considerations are possible share those to confirm whether they should be added before testing/documentation.
6. Once testing is approved only then should summary of tasks be created.

### Output Guidelines
- Don't add documentation or code comments unless requested.
- If any additional files will require changes confirm before proceeding. 

### Output Expectations
1. an entry in iac/tofu/config/meta.yml for the LXC entry
2. an entry in iac/tofu/config/lxcs/scripts for custom hookscript content
