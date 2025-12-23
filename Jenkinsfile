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
                        sudo apt-get update -qq && sudo apt-get install -y python3-venv || true
                        python3 -m venv venv
                        . venv/bin/activate
                        pip install gcovr
                    '''
                }
            }
        }
        stage('3. Check & Build') {
            steps {
                dir('calculator') {
                    sh 'make check || true'
                    sh 'make clean'
                    sh 'make all CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}"'
                    sh 'make unittest CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}"'
                }
            }
        }
        stage('4. Test & Report') {
            steps {
                dir('calculator') {
                    sh './bin/unittest'
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
        always { archiveArtifacts artifacts: 'reports/*.html', allowEmptyArchive: true }
    }
}
