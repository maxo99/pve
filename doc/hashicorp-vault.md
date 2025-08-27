# HashiCorp Vault

## SSH
- Setup SSH <https://www.hashicorp.com/en/blog/managing-ssh-access-at-scale-with-hashicorp-vault>
- <https://medium.com/ankercloud-engineering/a-quick-guide-to-set-up-hashicorp-vaults-ssh-secrets-engine-dce3b916bfae>


## Installation setup
<!-- - Used installation steps from: [Raspberry Pi installation](https://techfrontier.me.uk/post/vault-on-a-pi/)
- Updated Systemd with steps from: [medium article](https://medium.com/ankercloud-engineering/a-quick-guide-to-set-up-hashicorp-vaults-ssh-secrets-engine-dce3b916bfae) -->
<!-- - Used installation steps from: [Raspberry Pi installation](https://techfrontier.me.uk/post/vault-on-a-pi/)

## SSH Setup
<!-- To set up SSH access using HashiCorp Vault, begin by enabling the SSH secrets engine and generating a Certificate Authority (CA) key pair. This is done by running vault secrets enable -path=ssh-client-signer ssh and then vault write ssh-client-signer/config/ca generate_signing_key=true to create the CA, which will output the public key needed for host configuration.
 The CA's public key must be placed on the target hosts in a file, such as /etc/ssh/trusted-user-ca-keys.pem, and the SSH daemon must be configured to trust this key by adding TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem to the /etc/ssh/sshd_config file.

Next, configure the SSH daemon to use certificate authentication by setting AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u in the sshd_config file, which allows the system to verify the principal names listed in the signed certificates.
 The AuthorizedPrincipalsFile is crucial because the principal in the signed SSH certificate must match a name listed in the file corresponding to the user's account.
 After updating the configuration, restart the SSH service with sudo service sshd restart to apply the changes.

Roles must be created in Vault to define the parameters for signing SSH client certificates. These roles specify allowed principals, user restrictions, and validity periods. For example, a role for a team can be created with vault write ssh/roles/team-a-role valid_principals=team-a.
 The user's SSH public key is then submitted to Vault for signing using a command like vault write -field=signed_key ssh-client-signer/sign/team-a-role public_key=@$HOME/.ssh/bob-key.pub valid_principals=team-a > ~/.ssh/bob-signed-key.pub.
 This command returns a signed certificate that includes the specified principal.

Finally, the user can connect to the target host using the signed certificate and their private key with the command ssh -i ~/.ssh/bob-signed-key.pub -i ~/.ssh/bob-key appadmin@server.
 The connection will succeed only if the principal in the certificate matches the one listed in the AuthorizedPrincipalsFile for the target user account.
 This process ensures that SSH access is managed securely and at scale, with access controlled by Vault policies and certificate validity -->