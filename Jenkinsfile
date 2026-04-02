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
            choices: ['plan'],
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
                    sh "terraform init -input=false -reconfigure"
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                sh "terraform validate"
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                    sh """
                        terraform plan \
                          -input=false \
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
                        tfplan-${params.ENVIRONMENT} \
                        .terraform.lock.hcl \
                        .terraform/ \
                        *.tf \
                        modules/
                """
                archiveArtifacts artifacts: "${ARTIFACT_NAME}", fingerprint: true
            }
        }

        stage('Upload to Nexus') {
            steps {
                script {
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

    }

    post {
        always {
            script {
                try {
                    cleanWs()
                } catch (Exception e) {
                    echo "Workspace cleanup skipped: ${e.message}"
                }
            }
        }
        success {
            echo "Pipeline completed successfully for ${params.ENVIRONMENT}"
        }
        failure {
            echo "Pipeline failed for ${params.ENVIRONMENT}"
        }
    }
}
