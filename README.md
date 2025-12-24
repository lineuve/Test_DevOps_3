# Test_DevOps_3
Esta é a entrega final. Abaixo está a **Documentação Oficial (README.md)** estruturada para ser entregue aos times.

Ela cobre desde a arquitetura da infraestrutura até o guia de uso para desenvolvedores, consolidando todo o trabalho que fizemos para corrigir o código, os agentes e o pipeline.



# 📘 Documentação Oficial: Pipeline de CI/CD (C++ Calculator)

**Projeto:** Calculator Core V3
**Squad:** DevOps Phillips & Engineering Team
**Stack:** C++17, Jenkins, Docker, Python (Gcovr), GoogleTest



## 1. Visão Geral da Arquitetura

Este projeto implementa uma pipeline de integração contínua robusta para uma aplicação C++. O objetivo é garantir que todo código submetido passe por verificação estática, formatação, testes unitários e gere métricas visuais de cobertura de código.

### Fluxo de Trabalho

1. **Developer:** Submete código (Push/PR) para o GitHub.
2. **Jenkins Controller:** Detecta a mudança (Polling/Webhooks).
3. **Agent (Docker):** Um container efêmero (`cpp-agent`) é alocado.
4. **Build & Test:** O código é compilado com flags de cobertura e testado.
5. **Relatórios:** O `gcovr` processa os binários e gera HTML/XML.
6. **Feedback:** O status (Sucesso/Falha) e os artefatos são publicados.



## 2. Infraestrutura (Para Time DevOps)

A infraestrutura é baseada em Agentes Docker permanentes ou efêmeros conectados via SSH.

### Especificação do Agente (`cpp-agent`)

O agente deve ser capaz de compilar C++ e rodar scripts Python para relatórios.

**Dockerfile de Referência:**

```dockerfile
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# 1. Toolchain C++ e Utilitários
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git \
    clang-tidy clang-format \
    libgtest-dev \
    openjdk-17-jdk-headless openssh-server \
    python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

# 2. Compilação do Google Test (GTest)
WORKDIR /usr/src/gtest
RUN cmake CMakeLists.txt && make && \
    cp lib/*.a /usr/lib && \
    cp -r /usr/src/gtest/include/gtest /usr/local/include/gtest

# 3. Usuário Jenkins
RUN mkdir /var/run/sshd
RUN useradd -m -d /home/jenkins -s /bin/bash jenkins && \
    echo "jenkins:jenkins" | chpasswd

CMD ["/usr/sbin/sshd", "-D"]

```

**Requisitos do Nó Jenkins:**

* **Label:** `cpp-agent`
* **Remote Root FS:** `/home/jenkins`
* **Launch Method:** SSH

---

## 3. Detalhes da Pipeline (Jenkinsfile)

O `Jenkinsfile` utiliza a sintaxe Declarativa e está dividido em 4 estágios principais.

### Variáveis de Ambiente

Definimos flags globais para habilitar a instrumentação do código (necessário para o coverage):

* `CXXFLAGS`: `-fprofile-arcs -ftest-coverage` (Injeta contadores no binário).
* `LDFLAGS`: `-lgcov --coverage` (Linka a biblioteca gcov).

### Estágios da Jornada

| Estágio | Descrição Técnica | Comando Chave |
| --- | --- | --- |
| **1. Checkout** | Limpa o workspace e clona o Git. | `checkout scm` |
| **2. Setup Tools** | Cria um ambiente virtual Python isolado (`venv`) e instala o `gcovr`. Isso evita conflitos com o sistema operacional e dispensa uso de `sudo`. | `pip install gcovr` |
| **3. Build & Run** | Roda Linter (`clang-tidy`), compila o projeto e **executa** os testes unitários. A execução gera arquivos `.gcda` (dados brutos de cobertura). | `make check`, `make unittest` |
| **4. Reports** | O `gcovr` lê os arquivos `.gcda` gerados no estágio anterior e compila um relatório HTML navegável. | `gcovr --html-details` |

---

## 4. Guia para Desenvolvedores (Development Team)

Para garantir que seu código passe na pipeline, siga estas regras antes de fazer o commit.

### Padrões de Código

1. **Inicialização:** Todas as variáveis devem ser inicializadas (Ex: `double x = 0.0;`). O Linter bloqueará variáveis não inicializadas.
2. **Formatação:** O código segue o estilo Google. Use `clang-format` se possível.
3. **Tratamento de Erros:** Divisões por zero ou operações ilegais devem lançar exceções (`std::invalid_argument`) e não crashar o programa.

### Comandos Locais (Makefile)

Você pode simular a pipeline na sua máquina se tiver `g++` e `make` instalados:

* **Verificar estilo e erros:**
```bash
make check

```

* **Compilar e Rodar Testes:**
```bash
make unittest
./bin/unittest

```

* **Limpar binários:**
```bash
make clean

```
---

## 5. Troubleshooting (Erros Comuns)

### Erro: `Floating point exception`

* **Causa:** O código tentou dividir por zero sem tratamento de exceção.
* **Solução:** Adicione verificação `if (b == 0) throw ...` e use `EXPECT_THROW` nos testes.

### Erro: `script returned exit code 127 (./bin/unittest not found)`

* **Causa:** Tentativa de rodar o binário em um diretório errado ou em um estágio onde ele não foi gerado.
* **Correção:** O binário é gerado em `tests/bin/`. No Jenkins, confiamos na execução do `make unittest` que já roda o teste automaticamente.

### Erro: `sudo: not found`

* **Causa:** O Pipeline tentou usar `sudo` para instalar pacotes.
* **Solução:** Jamais use sudo no Pipeline. Dependências de sistema devem estar na Imagem Docker. Dependências Python devem usar `venv`.

---

## 6. Resultados e Artefatos

Após cada build com sucesso (Verde 🟢), acesse a aba **"Artifacts"** no Jenkins para visualizar:

* `coverage.html`: Relatório detalhado linha a linha.
* `coverage.xml`: Relatório para leitura de máquina (plugins).

---

*Documentação gerada automaticamente pela equipe DevOps Phillips.*
Aqui está uma descrição detalhada e técnica sobre o **Processo de Construção da Pipeline**, ideal para compor a documentação técnica ou para apresentar em uma review de arquitetura.

Esta seção explica a evolução da solução, desde a infraestrutura básica até a automação completa com relatórios de qualidade.

---

# 🚀 O Processo de Construção da Pipeline (End-to-End)

A construção desta pipeline de CI/CD para o projeto **Calculator Core (C++)** seguiu uma abordagem incremental e baseada em camadas, garantindo que a infraestrutura, o código e a automação estivessem desacoplados e robustos.

Abaixo, detalhamos as 4 fases principais desse processo.

## Fase 1: Infraestrutura Imutável (Agents)

Antes de escrever qualquer script de automação, precisávamos de um ambiente de execução consistente. O servidor Jenkins (Master) não deve compilar código; essa responsabilidade é dos **Agentes**.

* **Desafio:** O projeto exige ferramentas específicas de C++ (`clang-tidy`, `gtest`, `cmake`) e Python (`gcovr`) que não existem nativamente na maioria dos servidores.
* **Solução:** Criação de uma imagem Docker personalizada (`cpp-agent`).
* **Decisão Técnica:** Em vez de usar `sudo apt-get install` dentro do Pipeline (o que é lento e inseguro), "assamos" todas as dependências na imagem Docker.
* *Benefício:* O tempo de build cai drasticamente e o ambiente se torna reprodutível.



## Fase 2: Saneamento do Código e Build System

Ao analisarmos o repositório inicial, identificamos que a automação falharia devido a erros no código-fonte e no `Makefile`.

* **Correção do Makefile:** O target `unittest` compilava mas não executava o binário. Alteramos para garantir a execução imediata.
* **Quality Gate (Linter):** O código tinha variáveis não inicializadas. Configuramos o `clang-tidy` para barrar o build (`-warnings-as-errors`) se o código não estiver limpo.
* **Correção de Bug Crítico:** O código crashava com `Floating Point Exception` (divisão por zero). Implementamos tratamento de exceção (`std::invalid_argument`) no C++ e atualizamos o teste unitário para esperar esse comportamento.

## Fase 3: A Lógica da Pipeline (Jenkinsfile)

Adotamos o modelo **Declarative Pipeline** pela legibilidade e facilidade de manutenção. A pipeline foi estruturada em estágios lógicos:

1. **Checkout:** Baixa o código do GitHub.
2. **Setup Tools:** Cria um ambiente virtual Python (`venv`) isolado para instalar o `gcovr`. Isso evita poluir o sistema do agente.
3. **Static Analysis:** Roda o `make check` para garantir estilo e boas práticas antes de gastar recursos compilando.
4. **Build & Test:** Compila o código injetando flags de cobertura (`-fprofile-arcs -ftest-coverage`) e executa os testes.
5. **Coverage Report:** Processa os dados brutos gerados pelos testes e cria relatórios HTML/XML.

## Fase 4: Observabilidade e Métricas (Coverage)

Uma pipeline que apenas diz "Passou/Falhou" é insuficiente. Precisávamos saber **quanto** do código foi testado.

* **Ferramenta:** Escolhemos o `gcovr` (Python) por sua capacidade de gerar relatórios HTML amigáveis para projetos C++.
* **Integração:** Configuramos o Jenkins para arquivar (`archiveArtifacts`) os HTMLs gerados, permitindo que o desenvolvedor veja, linha por linha, o que foi testado diretamente na interface do Jenkins.

---

## Resumo das Tecnologias Envolvidas

| Camada | Tecnologia | Função |
| --- | --- | --- |
| **Orquestração** | **Jenkins** | Gerenciamento do fluxo de trabalho e gatilhos (Cron/Git). |
| **Agente** | **Docker** | Isolamento do ambiente de build (Ubuntu 24.04). |
| **Linguagem** | **C++17** | Core da aplicação. |
| **Build** | **Makefile** | Automação local de compilação. |
| **Testes** | **GoogleTest** | Framework de testes unitários. |
| **Qualidade** | **Clang-Tidy** | Análise estática e Linter. |
| **Cobertura** | **Gcovr (Python)** | Geração de relatórios visuais de cobertura. |

---

### Lições Aprendidas (Troubleshooting) durante o Processo

Durante a construção, superamos três obstáculos principais que moldaram a versão final:

1. **Dependência de Sudo:** Removemos comandos `sudo` do Jenkinsfile e movemos para o Dockerfile para evitar erros de permissão.
2. **Caminhos de Binários:** Ajustamos a execução dos testes para confiar no `make` em vez de chamar binários manualmente (`./bin/unittest`), evitando o erro "File not found (127)".
3. **Ambiente Python:** O uso de `venv` dentro do pipeline garantiu que pudéssemos usar ferramentas Python modernas sem conflitar com o sistema operacional do container.


# 🏛️ Arquitetura de Referência: Pipeline de CI/CD para C++ Moderno

**Projeto:** Calculator Core V3
**Versão da Arquitetura:** 1.0.0
**Status:** Produção

## 1. Resumo Executivo

Esta arquitetura define um pipeline de Integração Contínua (CI) automatizado, projetado para garantir a qualidade, segurança e rastreabilidade de aplicações desenvolvidas em **C++17**.

A solução adota uma abordagem **Híbrida e Containerizada**:

* **Core:** C++ (Performance e Lógica).
* **Infraestrutura:** Docker (Imutabilidade e Isolamento).
* **Ferramentas Auxiliares:** Python (Relatórios e Orquestração de Cobertura).

---

## 2. Diagrama de Alto Nível

O fluxo de dados segue o padrão *Commit-to-Artifact*, onde cada submissão de código dispara uma cadeia de validações isolada em containers.

**Fluxo de Dados:**

1. **Source:** Desenvolvedor envia código para o GitHub.
2. **Trigger:** Webhook/Cron aciona o Jenkins Controller.
3. **Provision:** Jenkins aloca um nó `cpp-agent` (Container Docker).
4. **Execution:** O Agente executa linting, build, testes e gera métricas.
5. **Artifacts:** Relatórios HTML e Binários são armazenados no Jenkins.

---

## 3. Stack Tecnológico (BOM - Bill of Materials)

| Domínio | Tecnologia | Versão/Detalhe | Justificativa |
| --- | --- | --- | --- |
| **Linguagem** | C++ | Standard 17 (C++17) | Requisito do projeto para funcionalidades modernas. |
| **SCM** | GitHub | Git | Versionamento distribuído e gestão de branches. |
| **Orquestrador** | Jenkins | 2.x (LTS) | Flexibilidade com Pipelines Declarativas e suporte a Docker. |
| **Build System** | GNU Make | 4.x | Padrão de indústria para C++, fácil manutenção via Makefile. |
| **Testes** | GoogleTest | GTest/GMock | Framework robusto para testes unitários e mocking em C++. |
| **Qualidade** | Clang-Tidy | LLVM Project | Análise estática para garantir conformidade (CppCoreGuidelines). |
| **Cobertura** | Gcovr | Python-based | Gera relatórios HTML/XML mais ricos que o lcov padrão. |
| **Infraestrutura** | Docker | Ubuntu 24.04 Base | Garante ambiente efêmero, limpo e reproduzível. |

---

## 4. Estratégia de Pipeline (Pipeline Design)

A pipeline foi desenhada com o princípio de **"Fail Fast"** (Falhar Rápido). As etapas mais leves e críticas rodam primeiro.

### Estágios do Pipeline

1. **Checkout & SCM:**
* Recuperação do código-fonte.
* Limpeza do Workspace (`cleanWs()`) para evitar contaminação de builds anteriores.


2. **Toolchain Setup (Python Venv):**
* **Problema Resolvido:** Conflitos de pacotes Python no sistema operacional do container.
* **Solução:** Criação de um `Virtual Environment (venv)` dinâmico para instalar o `gcovr`.
* *Comando:* `python3 -m venv venv && pip install gcovr`


3. **Static Analysis (Quality Gate 1):**
* Executa `clang-tidy` e `clang-format`.
* **Política:** Warnings são tratados como erros (`-warnings-as-errors`). O build falha se o código estiver "sujo" ou mal formatado.


4. **Build & Test (Quality Gate 2):**
* **Instrumentação:** Compilação com flags `-fprofile-arcs -ftest-coverage` para permitir a leitura de cobertura.
* **Execução:** O `make unittest` compila e executa o binário de teste imediatamente.
* **Tratamento de Erros:** O código C++ foi blindado contra `Floating Point Exceptions` (divisão por zero), garantindo que testes de falha sejam controlados (expectativa de exceção).


5. **Coverage Reports:**
* O utilitário `gcovr` varre os diretórios em busca de arquivos `.gcda` gerados no estágio anterior.
* Gera: `coverage.xml` (para leitura de máquina/plugins) e `coverage.html` (para leitura humana).



---

## 5. Design de Infraestrutura (Agentes)

A infraestrutura segue o modelo de **Agentes Especializados**. O Jenkins Controller não executa builds; ele delega para o nó `cpp-agent`.

### O Agente (`cpp-agent`)

Uma imagem Docker customizada baseada em Ubuntu 24.04.

**Camadas da Imagem:**

1. **Base:** Ubuntu 24.04 (Minimal).
2. **Compiladores:** `build-essential`, `cmake`, `g++`.
3. **Qualidade:** `clang-tidy`, `clang-format`.
4. **Runtime Python:** `python3`, `python3-pip`, `python3-venv` (Essencial para a ferramenta de cobertura).
5. **Conectividade:** `openssh-server` e usuário `jenkins` configurado para comunicação segura com o Controller.

> **Nota de Segurança:** O usuário `jenkins` dentro do container **não possui acesso root/sudo**. Todas as ferramentas necessárias são pré-instaladas na construção da imagem (Dockerfile), eliminando a necessidade de elevar privilégios durante a pipeline.

---

## 6. Métricas e KPIs de Sucesso

Para considerar uma execução bem-sucedida, a pipeline valida os seguintes KPIs:

* **Compilação:** 0 Erros.
* **Linting:** 0 Warnings (Strict mode).
* **Testes Unitários:** 100% de Pass rate (Todos os cenários, incluindo casos de borda como divisão por zero).
* **Artefatos:** Geração bem-sucedida do relatório `coverage.html`.

---

## 7. Guia de Manutenção (Troubleshooting)

### Cenário: Erro 127 (Command not found)

* **Sintoma:** Pipeline falha ao tentar rodar `./bin/unittest`.
* **Causa:** O binário foi gerado em um subdiretório (`tests/bin`) ou já foi limpo.
* **Resolução:** A pipeline foi ajustada para confiar no comando `make unittest`, que gerencia os caminhos internamente. Não execute binários manualmente fora do contexto do Makefile.

### Cenário: Erro de Permissão (sudo)

* **Sintoma:** `sudo: command not found` no log do Jenkins.
* **Causa:** Tentativa de instalar pacotes durante o runtime do job.
* **Resolução:** Adicione o pacote necessário no `Dockerfile` do agente e reconstrua a imagem. **Não** use sudo no Jenkinsfile.

---

**Aprovado por:** DevOps Phillips Team
**Data:** Dezembro/2025
