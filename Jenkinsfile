pipeline {
    agent {
        node {
            label 'terraform-runner'
        }
    }

    stages {
        stage('Verify Environment') {
            steps {
                sh '''
                    echo "Running on Agent Hostname: $(hostname)"
                    echo "Agent IP: $(curl -s ifconfig.me)"
                    java -version
                    terraform --version
                    git --version

                    echo amit
                '''
            }
        }
    }
}