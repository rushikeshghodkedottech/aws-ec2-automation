#!/bin/bash

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

function terminate_instance(){
	
	read -p "Enter instance id: " instace_id

	echo "Terminating instace "$instance_id""
	
	TERMINATION_DATA=$(aws ec2 terminate-instances --instance-ids "$instace_id" --query "TerminatingInstances[0].InstanceId" --output text 2>&1)

	if [[ $? -ne 0 ]]; then
		echo "Some problem occured while terminating the EC2 instace."
		return 1
	fi

	echo "Instance Terminated"
}

if check_awscli_is_installed; then
        aws_configuration
        terminate_instance
else
        exit 1

fi

