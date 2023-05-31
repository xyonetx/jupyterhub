# Terraform plan for creating a Jupyterhub instance

**Assumptions:**

- AWS account with appropriate permissions and configured to work via your local terminal (e.g. `aws` cli works and credentials are in `~/.aws/`)
- Terraform is installed
- A domain to use (for setting up HTTPS certs)
- You have created a "static" IP via AWS Elastic IP and a DNS record to associate your domain to that IP.

Note that we use certbot to issue an HTTPS certificate.

**Configuration**
- Copy `terraform.tfvars.tmpl` to `terraform.tfvars` and fill in:
    - the allocation ID for your EIP.
    - the domain (the one ultimately pointing to the elastic IP address)
    - an admin email for certbot
- `terraform apply`

**Adding users**

Once the machine is up and provisioned, we can add users who may use the JupyterHub installation. Note that there is no anonymous usage allowed.

1. **Connect to the host machine.**

    The EC2 host can be connected to by using AWS systems manager. To connect, get the instance ID of the new EC2 instance and run:
    ```
    aws ssm start-session --target <INSTANCE ID>
    ```

    You may need to install the AWS SSM agent on your local machine for this to work.


2. **Create a user file**

    The script to automate adding users expects a comma-delimited text file which includes:

    - email address
    - a username (needs to be Unix valid!)
    - a plain text password

    Be careful not to put spaces in there, as it's a pretty brittle script. e.g. the file should look like:

    ```
    foo@email.com,foo-user,abc123
    bar@email.com,someone-else,def456
    ```
    Save this file somewhere memorable

3. **Run the script**

    Execute the script:
    ```
    cd /opt/jupyterhub
    ./add_users.sh <path to user file from step 2>
    ```





