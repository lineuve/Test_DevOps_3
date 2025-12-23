pipeline {
    agent {
        // Obriga a rodar nos nós 'agent-01' ou 'agent-02' que o script criou
        label 'cpp-agent'
    }

    // Gatilho diário (Requisito da prova)
    triggers {
        cron('H H * * *')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Static Analysis') {
            steps {
                // Roda verificação de código (clang-tidy/format)
                sh 'make check'
            }
        }

        stage('Build') {
            steps {
                // Compila o projeto
                sh 'make all'
            }
        }

        stage('Unit Tests') {
            steps {
                // 1. Compila os testes
                sh 'make unittest'
                
                // 2. IMPORTANTE: Executa o binário para validar se funciona mesmo
                sh './bin/unittest'
            }
        }
    }

    post {
        always {
            // Guarda o artefato final
            archiveArtifacts artifacts: 'bin/calculator', allowEmptyArchive: true
            cleanWs()
        }
    }
}
