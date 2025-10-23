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

The script that runs the attack tests has the IP of my private lab hardcoded. You will have to replace it if you want to use that.
