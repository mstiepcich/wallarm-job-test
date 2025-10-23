Run 
terraform plan -out wallarm-deploy
Some variable values will be prompted like
AWS region to use
key pair name already created in that aws region
Wallarm API Token
Wallarm API Host
Wallarm Mode

Then run terraform apply wallarm-deploy

To destroy run:
terraform destroy

the values will be prompted again. Is not very confortable but it is faster than asking for the creation of a .tfvars file with the data

