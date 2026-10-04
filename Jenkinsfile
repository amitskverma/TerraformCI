pipeline {
    agent {
        node {
            label 'build-agent'
        }
    }

    stages {
        stage('Verify Environment') {
            steps {
                sh '''
                    echo "Running on Agent Hostname: $(hostname)"
                    echo "Agent IP: $(curl -s ifconfig.me)"
                    java -version
                    git --version
                    echo "Running on Agent Hostname: $(hostname)"
                    echo amit
                    echo "Running on Agent Hostname: $(hostname)"
                '''
            }
        }
    }
}