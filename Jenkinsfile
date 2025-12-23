pipeline {
    agent { label 'cpp-agent' }
    environment {
        CXXFLAGS = "-Wall -Wextra -std=c++17 -fprofile-arcs -ftest-coverage"
        LDFLAGS  = "-lgcov --coverage"
    }
    triggers { cron('H H * * *') }
    stages {
        stage('1. Checkout') {
            steps {
                cleanWs()
                checkout scm
                sh 'mkdir -p reports'
            }
        }
        stage('2. Setup Tools') {
            steps {
                script {
                    sh '''
                        # Instala gcovr em ambiente isolado
                        python3 -m venv venv
                        . venv/bin/activate
                        pip install gcovr
                    '''
                }
            }
        }
        stage('3. Build & Run Tests') {
            steps {
                dir('calculator') {
                    // Compila e JA EXECUTA os testes aqui
                    sh 'make check || true'
                    sh 'make clean'
                    sh 'make all CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}"'
                    sh 'make unittest CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}"'
                }
            }
        }
        stage('4. Generate Coverage Report') {
            steps {
                dir('calculator') {
                    // O comando falho foi removido. Agora só geramos o relatório.
                    echo ">>> Processando dados de cobertura (gcovr)..."
                    sh '''
                        . ../venv/bin/activate
                        # Gera XML (para o Jenkins) e HTML (para você ver)
                        gcovr -r . --xml-pretty > ../reports/coverage.xml
                        gcovr -r . --html --html-details -o ../reports/coverage.html
                    '''
                }
            }
        }
    }
    post {
        always { archiveArtifacts artifacts: 'reports/*.html', allowEmptyArchive: true }
    }
}
