pipeline {
    agent any

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'production'],
            description: 'Target deployment environment'
        )
        choice(
            name: 'TF_ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Terraform action to perform'
        )
    }

    environment {
        TF_VAR_FILE        = "environments/${params.ENVIRONMENT}.tfvars"
        ARTIFACT_NAME      = "terraform-${params.ENVIRONMENT}-${BUILD_NUMBER}.zip"
        AWS_CREDENTIALS_ID = 'aws-credentials'
        NEXUS_CREDENTIALS  = credentials('nexus-credentials')
    }

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                    sh """
                        terraform init \
                          -backend-config="key=${params.ENVIRONMENT}/terraform.tfstate" \
                          -reconfigure
                    """
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                sh 'terraform validate'
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                    sh """
                        terraform plan \
                          -var-file="${TF_VAR_FILE}" \
                          -out=tfplan-${params.ENVIRONMENT}
                    """
                }
            }
        }

        stage('Package Artifacts') {
            steps {
                sh """
                    zip -r ${ARTIFACT_NAME} \
                        main.tf \
                        variables.tf \
                        outputs.tf \
                        modules/ \
                        environments/${params.ENVIRONMENT}.tfvars \
                        tfplan-${params.ENVIRONMENT}
                """
                archiveArtifacts artifacts: "${ARTIFACT_NAME}", fingerprint: true
            }
        }

        stage('Upload to Nexus') {
            steps {
                script {
                    // Read nexus_url and nexus_repo from the tfvars file
                    def tfvarsContent = readFile("environments/${params.ENVIRONMENT}.tfvars")
                    def nexusUrl  = (tfvarsContent =~ /nexus_url\s*=\s*"([^"]+)"/)[0][1]
                    def nexusRepo = (tfvarsContent =~ /nexus_repo\s*=\s*"([^"]+)"/)[0][1]

                    sh """
                        curl -u "${NEXUS_CREDENTIALS_USR}:${NEXUS_CREDENTIALS_PSW}" \
                             --upload-file ${ARTIFACT_NAME} \
                             "${nexusUrl}/repository/${nexusRepo}/${params.ENVIRONMENT}/${ARTIFACT_NAME}"
                    """
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.TF_ACTION == 'apply' }
            }
            input {
                message "Apply changes to ${params.ENVIRONMENT}?"
                ok "Yes, apply"
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                    sh "terraform apply -auto-approve tfplan-${params.ENVIRONMENT}"
                }
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.TF_ACTION == 'destroy' }
            }
            input {
                message "DESTROY ${params.ENVIRONMENT} environment?"
                ok "Yes, destroy"
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                    sh """
                        terraform destroy \
                          -var-file="${TF_VAR_FILE}" \
                          -auto-approve
                    """
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo "Pipeline completed successfully for ${params.ENVIRONMENT}"
        }
        failure {
            echo "Pipeline failed for ${params.ENVIRONMENT}"
        }
    }
}
