#!/bin/bash -x

function check_awscli_is_installed(){
	if aws --version &> /dev/null
	then echo 'Checked! AWS CLI is installed.'
	else 
		echo 'Installing AWS CLI...'
		choco install awscli
	fi
}

function aws_configuration(){
	read -p "Enter your access key: " access_key
	read -p "Enter your access secret: " access_secret
	read -p "Enter region: " region
	read -p "Enter output format: " output_format

	echo "Configuring account..."

	aws configure set aws_access_key_id "$access_key"
	aws configure set aws_secret_key_id "$access_secret"
	aws configure set region "$region"
	aws configure set output "$output_format"
	
	echo "AWS CLI has been configured!"
	aws configure list
}


function key_pair() {
    echo "Choose key pair option:"
    echo "1) Use existing key pair"
    echo "2) Create a new key pair"
    read -p "Enter choice (1 or 2): " key_choice

    if [ "$key_choice" == "1" ]; then
        read -p "Enter the name of the existing key pair: " existing_key_name
        echo "Using existing key pair: $existing_key_name"
	KEY_PAIR_NAME="$existing_key_name"

    elif [ "$key_choice" == "2" ]; then
        read -p "Enter a name for the new key pair: " new_key_name
        read -p "Enter the file path to save the private key (.pem): " pem_path

        echo "Creating new key pair '$new_key_name'..."
        aws ec2 create-key-pair --key-name "$new_key_name" --query 'KeyMaterial' --output text > "$pem_path"

        chmod 400 "$pem_path"

        echo "Key pair '$new_key_name' created and private key saved to: $pem_path"
	KEY_PAIR_NAME="$new_key_name"

    else
        echo "Invalid option. Exiting."
        exit 1
    fi
}

function security_group(){
	echo "Choose security group option:"
	echo "1) Use default security group"
	echo "2) Choose from existing security groups"
	echo "3) Create a new security group"
	read -p "Enter choice (1, 2, 3): " sg_choice

	if [ "$sg_choice" == "1" ]; then
		echo "Using default security group (omitting --security-group-ids)"
		SECURITY_GROUP_ARG=""

	elif [ "$sg_choice" == "2" ]; then
	        echo "Fetching existing security groups..."
        	aws ec2 describe-security-groups --query "SecurityGroups[*].[GroupName,GroupId]" --output table

        	read -p "Enter the name of the existing security group: " sg_name

        	sg_id=$(aws ec2 describe-security-groups \
            		--filters Name=group-name,Values="$sg_name" \
            		--query "SecurityGroups[0].GroupId" --output text)

        	if [ "$sg_id" == "None" ] || [ -z "$sg_id" ]; then
            		echo "Security group '$sg_name' not found. Exiting."
            		exit 1
       		fi

        	echo "Using security group '$sg_name' with ID: $sg_id"
        	SECURITY_GROUP_ARG="--security-group-ids $sg_id"

    	elif [ "$sg_choice" == "3" ]; then
        	read -p "Enter a name for the new security group: " new_sg_name
        	read -p "Enter a description for the new security group: " sg_description
        	read -p "Enter your VPC ID: " vpc_id

        	echo "Creating new security group..."
        	
		sg_id=$(aws ec2 create-security-group \
            		--group-name "$new_sg_name" \
            		--description "$sg_description" \
            		--vpc-id "$vpc_id" \
            		--query "GroupId" --output text)

        	echo "New security group '$new_sg_name' created with ID: $sg_id"

        	#SSH
        	aws ec2 authorize-security-group-ingress \
            		--group-id "$sg_id" \
            		--protocol tcp --port 22 --cidr 0.0.0.0/0

        	SECURITY_GROUP_ARG="--security-group-ids $sg_id"

    	else
        	echo "Invalid option. Exiting."
        	exit 1
    	fi
} 

function create_instance(){
	echo "Started Creation of an EC2 instance..."

	    local AMI_ID="ami-XXXX"
    	local INSTANCE_TYPE="t2.micro"
    	local SUBNET_ID="subnet-XXXX"

        INSTANCE_INFO=$(aws ec2 run-instances \
    	    --image-id "$AMI_ID" \
        	--count 1 \
	        --instance-type "$INSTANCE_TYPE" \
        	--key-name "$KEY_PAIR_NAME" \
	        $SECURITY_GROUP_ARG \
	        --subnet-id "$SUBNET_ID" \
	        --query 'Instances[0].InstanceId' \
	        --output text 2>&1)

	if [[ $? -ne 0 ]]; then
        	echo "Failed to create EC2 instance: $INSTANCE_INFO"
	        return 1
    	fi

	echo "EC2 instance created successfully. Instance ID: $INSTANCE_INFO"
}




if check_awscli_is_installed; then
	aws_configuration
	key_pair
	security_group
	echo $SECURITY_GROUP_ARG
	create_instance
else 
	exit 1

fi
