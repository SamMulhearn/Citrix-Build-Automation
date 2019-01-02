**Citrix Build Automation**
This script performs the following:

- Remotely installs the Delivery Controller, StoreFront, License Server, Studio and Director on nominated machines.
- Remotely installs WEM infrastructure component on nominated machines.
- Remotely installs the VDA, FSLogix, BIS-F, WEM agent, WorkSpace App and Optimises the OS using Citrix Optimizer on nominated machines.
- Imports template GPO's into Active Directory.

The script should be run on a machine in the same AD forest as the target machines, and should be run in the context of a domain user with Administrative permissions on the target machines and the local machine from which the script us run.

The script is designed to be repeated in the event of failures. If errors occur, examine the logs (C:\Cetus\Logs), correct the fault, and re-run the script.

The Script expects a 'Software' directory in the same directory as the script.
The Script searches for the following components:

**Citrix Optimiser** -`\Software\CitrixOptimizer.zip`
**Citrix Virtual Apps & Desktops**- `\Software\Citrix*.iso`
**FSLogix** - `\Software\\\*FSLogix*.zip`
**Workspace Environment Manager** - `\Software\Workspace-Environment-Management*.zip`
**Base Image Script Framework**- `\Software\setup-BIS-F*.exe.zip `

To export a template GPO, use the following PowerShell command:
`Backup-GPO -Name GPO_NAME -Path SCRIPTPATH\GPO`
Where GPO_NAME is the named of the GPO and SCRIPTPATH is the directory containing this script.
