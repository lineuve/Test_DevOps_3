#!/bin/bash
set -e

# --- CONFIGURAÇÃO ---
# Detecta o diretório atual como o repo, ou ajuste manualmente se preferir
LOCAL_REPO_PATH=$(pwd) 

JENKINS_URL="http://localhost:8080"
USER_ID="villeneuve"
ADMIN_PASS="a"
CLI_JAR="jenkins-cli.jar"
JAVA_CMD="/usr/lib/jvm/java-17-openjdk-amd64/bin/java"

if [ ! -f "$JAVA_CMD" ]; then JAVA_CMD="java"; fi

function jcli() {
    # Tenta baixar o CLI se não existir
    if [ ! -f "$CLI_JAR" ]; then
        wget -q ${JENKINS_URL}/jnlpJars/jenkins-cli.jar -O $CLI_JAR || docker cp jenkins-server:/var/jenkins_home/war/WEB-INF/jenkins-cli.jar .
    fi
    $JAVA_CMD -jar $CLI_JAR -s $JENKINS_URL -auth $USER_ID:$ADMIN_PASS "$@"
}

echo "📊 [PIPELINE] Gerando Jenkinsfile com Cobertura em: $LOCAL_REPO_PATH"

# Criamos o Jenkinsfile DIRETO na pasta atual
cat <<EOF > Jenkinsfile
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
                    sh 'make all CXXFLAGS="\${CXXFLAGS}" LDFLAGS="\${LDFLAGS}"'
                    sh 'make unittest CXXFLAGS="\${CXXFLAGS}" LDFLAGS="\${LDFLAGS}"'
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
EOF

# Atualiza o Git (Assume que estamos na raiz do repo)
echo "🔄 [GIT] Comitando mudanças..."
git add Jenkinsfile
git commit -m "Feat: Add Coverage Reports" || true
git push origin main || git push origin master

echo "🚀 [JENKINS] Disparando Build..."
jcli build Calculator-Pipeline -s -v
