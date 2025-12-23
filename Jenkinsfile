pipeline {
    agent {
        label 'cpp-agent'
    }

    environment {
        CXXFLAGS = "-Wall -Wextra -std=c++17 -fprofile-arcs -ftest-coverage"
        LDFLAGS  = "-lgcov --coverage"
    }

    triggers {
        cron('H H * * *')
    }

    stages {
        stage('1. Checkout & Clean') {
            steps {
                cleanWs()
                checkout scm
                sh 'mkdir -p reports'
            }
        }

        stage('2. Setup Tools (Python/Gcovr)') {
            steps {
                script {
                    echo ">>> Instalando gcovr..."
                    sh '''
                        sudo apt-get update -qq && sudo apt-get install -y python3-venv || true
                        python3 -m venv venv
                        . venv/bin/activate
                        pip install gcovr
                    '''
                }
            }
        }

        stage('3. Static Analysis') {
            steps {
                dir('calculator') {
                    sh 'make check || true' 
                }
            }
        }

        stage('4. Build (Instrumented)') {
            steps {
                dir('calculator') {
                    sh 'make clean'
                    sh 'make all CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}"'
                    sh 'make unittest CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}"'
                }
            }
        }

        stage('5. Unit Tests Execution') {
            steps {
                dir('calculator') {
                    sh './bin/unittest'
                }
            }
        }

        stage('6. Generate Coverage Report') {
            steps {
                dir('calculator') {
                    sh '''
                        . ../venv/bin/activate
                        gcovr -r . --xml-pretty > ../reports/coverage.xml
                        gcovr -r . --html --html-details -o ../reports/coverage.html
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'reports/*.html', allowEmptyArchive: true
        }
        success {
            echo "✅ Pipeline Finalizado!"
        }
    }
}
