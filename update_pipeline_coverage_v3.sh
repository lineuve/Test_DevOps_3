#!/bin/bash
set -e

# --- CONFIGURAÇÃO ---
LOCAL_REPO_PATH=$(pwd)
# URL detectada do seu log
GITHUB_URL="https://github.com/lineuve/Test_DevOps_3.git"

JENKINS_URL="http://localhost:8080"
USER_ID="villeneuve"
ADMIN_PASS="a"
CLI_JAR="jenkins-cli.jar"
JAVA_CMD="/usr/lib/jvm/java-17-openjdk-amd64/bin/java"

if [ ! -f "$JAVA_CMD" ]; then JAVA_CMD="java"; fi

function jcli() {
    if [ ! -f "$CLI_JAR" ]; then
        wget -q ${JENKINS_URL}/jnlpJars/jenkins-cli.jar -O $CLI_JAR || docker cp jenkins-server:/var/jenkins_home/war/WEB-INF/jenkins-cli.jar .
    fi
    $JAVA_CMD -jar $CLI_JAR -s $JENKINS_URL -auth $USER_ID:$ADMIN_PASS "$@"
}

echo "📊 [SETUP] Gerando Jenkinsfile com Cobertura..."

# 1. Cria o Jenkinsfile (Com Coverage)
cat <<EOF > Jenkinsfile
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
                    sh 'make all CXXFLAGS="\${CXXFLAGS}" LDFLAGS="\${LDFLAGS}"'
                    sh 'make unittest CXXFLAGS="\${CXXFLAGS}" LDFLAGS="\${LDFLAGS}"'
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
EOF

# 2. GIT: Adiciona TUDO (Correções C++ + Jenkinsfile)
echo "🔄 [GIT] Enviando correções C++ e Jenkinsfile para o GitHub..."
git add .
git commit -m "Fix: C++ Logic and Add Coverage Pipeline" || echo "Nada novo para commitar."
git push origin main || git push origin master

# 3. JENKINS: Cria o Job 'Calculator-Pipeline' (pois ele não existe)
echo "🔧 [JENKINS] Criando/Atualizando Job 'Calculator-Pipeline'..."

cat <<EOF > pipeline_config.xml
<flow-definition plugin="workflow-job">
  <description>Pipeline Oficial com Coverage (C++)</description>
  <keepDependencies>false</keepDependencies>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>$GITHUB_URL</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
        <hudson.plugins.git.BranchSpec>
          <name>*/master</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
</flow-definition>
EOF

if jcli get-job Calculator-Pipeline > /dev/null 2>&1; then
    jcli update-job Calculator-Pipeline < pipeline_config.xml
else
    echo ">>> Job não encontrado. Criando agora..."
    jcli create-job Calculator-Pipeline < pipeline_config.xml
fi

# 4. Dispara o Build
echo "🚀 [JENKINS] Disparando Build..."
jcli build Calculator-Pipeline -s -v
