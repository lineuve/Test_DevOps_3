**Test_DevOps_3**

This is the final deliverable. Below is the **Official Documentation (README.md)** structured for team handover. It covers everything from infrastructure architecture to the developer usage guide, consolidating all the work done to fix the code, agents, and the pipeline.

---

# 📘 Official Documentation: CI/CD Pipeline (C++ Calculator)

* **Project:** Calculator Core V3
* **Squad:** DevOps Phillips & Engineering Team
* **Stack:** C++17, Jenkins, Docker, Python (Gcovr), GoogleTest

## 1. Architecture Overview

This project implements a robust continuous integration pipeline for a C++ application. The goal is to ensure that all submitted code undergoes static verification, formatting, and unit testing, and generates visual code coverage metrics.

### Workflow

1. **Developer:** Submits code (Push/PR) to GitHub.
2. **Jenkins Controller:** Detects the change (Polling/Webhooks).
3. **Agent (Docker):** An ephemeral container (`cpp-agent`) is allocated.
4. **Build & Test:** Code is compiled with coverage flags and tested.
5. **Reports:** `gcovr` processes the binaries and generates HTML/XML.
6. **Feedback:** Status (Success/Failure) and artifacts are published.

## 2. Infrastructure (For DevOps Team)

The infrastructure is based on permanent or ephemeral Docker Agents connected via SSH.

### Agent Specification (`cpp-agent`)

The agent must be capable of compiling C++ and running Python scripts for reporting.

**Reference Dockerfile:**

```dockerfile
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# 1. C++ Toolchain and Utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git \
    clang-tidy clang-format \
    libgtest-dev \
    openjdk-17-jdk-headless openssh-server \
    python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

# 2. Google Test (GTest) Compilation
WORKDIR /usr/src/gtest
RUN cmake CMakeLists.txt && make && \
    cp lib/*.a /usr/lib && \
    cp -r /usr/src/gtest/include/gtest /usr/local/include/gtest

# 3. Jenkins User
RUN mkdir /var/run/sshd
RUN useradd -m -d /home/jenkins -s /bin/bash jenkins && \
    echo "jenkins:jenkins" | chpasswd

CMD ["/usr/sbin/sshd", "-D"]

```

**Jenkins Node Requirements:**

* **Label:** `cpp-agent`
* **Remote Root FS:** `/home/jenkins`
* **Launch Method:** SSH

## 3. Pipeline Details (Jenkinsfile)

The `Jenkinsfile` uses Declarative syntax and is divided into 4 main stages.

### Environment Variables

We define global flags to enable code instrumentation (required for coverage):

* `CXXFLAGS`: `-fprofile-arcs -ftest-coverage` (Injects counters into the binary).
* `LDFLAGS`: `-lgcov --coverage` (Links the gcov library).

### Journey Stages

| Stage | Technical Description | Key Command |
| --- | --- | --- |
| **1. Checkout** | Cleans the workspace and clones Git. | `checkout scm` |
| **2. Setup Tools** | Creates an isolated Python virtual environment (`venv`) and installs `gcovr`. This avoids OS conflicts and removes the need for `sudo`. | `pip install gcovr` |
| **3. Build & Run** | Runs Linter (`clang-tidy`), compiles the project, and executes unit tests. Execution generates `.gcda` files (raw coverage data). | `make check`, `make unittest` |
| **4. Reports** | `gcovr` reads the `.gcda` files generated in the previous stage and compiles a navigable HTML report. | `gcovr --html-details` |

## 4. Developer Guide (Development Team)

To ensure your code passes the pipeline, follow these rules before committing.

### Code Standards

1. **Initialization:** All variables must be initialized (Ex: `double x = 0.0;`). The Linter will block uninitialized variables.
2. **Formatting:** The code follows Google Style. Use `clang-format` if possible.
3. **Error Handling:** Division by zero or illegal operations must throw exceptions (`std::invalid_argument`) and not crash the program.

### Local Commands (Makefile)

You can simulate the pipeline on your machine if you have `g++` and `make` installed:

* **Check style and errors:**
```bash
make check

```


* **Compile and Run Tests:**
```bash
make unittest
./bin/unittest

```


* **Clean binaries:**
```bash
make clean

```



## 5. Troubleshooting (Common Errors)

**Error:** `Floating point exception`

* **Cause:** The code attempted to divide by zero without exception handling.
* **Solution:** Add verification `if (b == 0) throw ...` and use `EXPECT_THROW` in tests.

**Error:** `script returned exit code 127 (./bin/unittest not found)`

* **Cause:** Attempting to run the binary in the wrong directory or in a stage where it wasn't generated.
* **Correction:** The binary is generated in `tests/bin/`. In Jenkins, we trust the `make unittest` execution which runs the test automatically.

**Error:** `sudo: not found`

* **Cause:** The Pipeline attempted to use `sudo` to install packages.
* **Solution:** Never use `sudo` in the Pipeline. System dependencies must be in the Docker Image. Python dependencies must use `venv`.

## 6. Results and Artifacts

After every successful build (Green 🟢), access the **"Artifacts"** tab in Jenkins to view:

* `coverage.html`: Detailed line-by-line report.
* `coverage.xml`: Machine-readable report (for plugins).

---

*Documentation automatically generated by the DevOps Phillips team.*

---

## The Pipeline Construction Process

Here is a detailed and technical description of the **Pipeline Construction Process**, ideal for including in technical documentation or presenting in an architecture review. This section explains the solution's evolution, from basic infrastructure to full automation with quality reports.

### 🚀 The Pipeline Construction Process (End-to-End)

The construction of this CI/CD pipeline for the **Calculator Core (C++)** project followed an incremental and layered approach, ensuring that infrastructure, code, and automation were decoupled and robust.

Below, we detail the 4 main phases of this process.

#### Phase 1: Immutable Infrastructure (Agents)

Before writing any automation scripts, we needed a consistent execution environment. The Jenkins server (Master) should not compile code; this is the responsibility of the **Agents**.

* **Challenge:** The project requires specific C++ tools (`clang-tidy`, `gtest`, `cmake`) and Python tools (`gcovr`) that do not exist natively on most servers.
* **Solution:** Creation of a custom Docker image (`cpp-agent`).
* **Technical Decision:** Instead of using `sudo apt-get install` inside the Pipeline (which is slow and insecure), we "baked" all dependencies into the Docker image.
* **Benefit:** Build time drops drastically, and the environment becomes reproducible.

#### Phase 2: Code Sanitation and Build System

Upon analyzing the initial repository, we identified that automation would fail due to errors in the source code and the `Makefile`.

* **Makefile Correction:** The `unittest` target compiled but did not execute the binary. We changed it to ensure immediate execution.
* **Quality Gate (Linter):** The code had uninitialized variables. We configured `clang-tidy` to block the build (`-warnings-as-errors`) if the code is not clean.
* **Critical Bug Fix:** The code crashed with a `Floating Point Exception` (division by zero). We implemented exception handling (`std::invalid_argument`) in C++ and updated the unit test to expect this behavior.

#### Phase 3: Pipeline Logic (Jenkinsfile)

We adopted the **Declarative Pipeline** model for readability and ease of maintenance. The pipeline was structured into logical stages:

1. **Checkout:** Downloads code from GitHub.
2. **Setup Tools:** Creates an isolated Python virtual environment (`venv`) to install `gcovr`. This avoids polluting the agent's system.
3. **Static Analysis:** Runs `make check` to ensure style and best practices before spending resources compiling.
4. **Build & Test:** Compiles the code injecting coverage flags (`-fprofile-arcs -ftest-coverage`) and executes the tests.
5. **Coverage Report:** Processes raw data generated by the tests and creates HTML/XML reports.

#### Phase 4: Observability and Metrics (Coverage)

A pipeline that only says "Passed/Failed" is insufficient. We needed to know **how much** of the code was tested.

* **Tool:** We chose `gcovr` (Python) for its ability to generate friendly HTML reports for C++ projects.
* **Integration:** We configured Jenkins to archive (`archiveArtifacts`) the generated HTMLs, allowing the developer to see, line by line, what was tested directly in the Jenkins interface.

### Summary of Technologies Involved

| Layer | Technology | Function |
| --- | --- | --- |
| **Orchestration** | **Jenkins** | Workflow management and triggers (Cron/Git). |
| **Agent** | **Docker** | Build environment isolation (Ubuntu 24.04). |
| **Language** | **C++17** | Application core. |
| **Build** | **Makefile** | Local compilation automation. |
| **Tests** | **GoogleTest** | Unit testing framework. |
| **Quality** | **Clang-Tidy** | Static analysis and Linter. |
| **Coverage** | **Gcovr (Python)** | Generation of visual coverage reports. |

### Lessons Learned (Troubleshooting) during the Process

During construction, we overcame three main obstacles that shaped the final version:

1. **Sudo Dependency:** We removed `sudo` commands from the Jenkinsfile and moved them to the Dockerfile to avoid permission errors.
2. **Binary Paths:** We adjusted test execution to trust `make` instead of calling binaries manually (`./bin/unittest`), avoiding the "File not found (127)" error.
3. **Python Environment:** Using `venv` inside the pipeline ensured we could use modern Python tools without conflicting with the container's operating system.

---

# 🏛️ Reference Architecture: CI/CD Pipeline for Modern C++

* **Project:** Calculator Core V3
* **Architecture Version:** 1.0.0
* **Status:** Production

## 1. Executive Summary

This architecture defines an automated Continuous Integration (CI) pipeline designed to ensure the quality, security, and traceability of applications developed in **C++17**.

The solution adopts a **Hybrid and Containerized** approach:

* **Core:** C++ (Performance and Logic).
* **Infrastructure:** Docker (Immutability and Isolation).
* **Auxiliary Tools:** Python (Reports and Coverage Orchestration).

## 2. High-Level Diagram

The data flow follows the **Commit-to-Artifact** pattern, where each code submission triggers a validation chain isolated in containers.

**Data Flow:**

1. **Source:** Developer sends code to GitHub.
2. **Trigger:** Webhook/Cron triggers the Jenkins Controller.
3. **Provision:** Jenkins allocates a `cpp-agent` node (Docker Container).
4. **Execution:** The Agent executes linting, build, tests, and generates metrics.
5. **Artifacts:** HTML Reports and Binaries are stored in Jenkins.

## 3. Technology Stack (BOM - Bill of Materials)

| Domain | Technology | Version/Detail | Justification |
| --- | --- | --- | --- |
| **Language** | C++ | Standard 17 (C++17) | Project requirement for modern functionalities. |
| **SCM** | GitHub | Git | Distributed versioning and branch management. |
| **Orchestrator** | Jenkins | 2.x (LTS) | Flexibility with Declarative Pipelines and Docker support. |
| **Build System** | GNU Make | 4.x | Industry standard for C++, easy maintenance via Makefile. |
| **Tests** | GoogleTest | GTest/GMock | Robust framework for unit testing and mocking in C++. |
| **Quality** | Clang-Tidy | LLVM Project | Static analysis to ensure compliance (CppCoreGuidelines). |
| **Coverage** | Gcovr | Python-based | Generates richer HTML/XML reports than standard lcov. |
| **Infrastructure** | Docker | Ubuntu 24.04 Base | Ensures ephemeral, clean, and reproducible environment. |

## 4. Pipeline Strategy (Pipeline Design)

The pipeline was designed with the **"Fail Fast"** principle. The lightest and most critical steps run first.

### Pipeline Stages

1. **Checkout & SCM:**
* Source code retrieval.
* Workspace cleanup (`cleanWs()`) to avoid contamination from previous builds.


2. **Toolchain Setup (Python Venv):**
* **Problem Solved:** Python package conflicts in the container OS.
* **Solution:** Creation of a dynamic Virtual Environment (`venv`) to install `gcovr`.
* **Command:** `python3 -m venv venv && pip install gcovr`


3. **Static Analysis (Quality Gate 1):**
* Executes `clang-tidy` and `clang-format`.
* **Policy:** Warnings are treated as errors (`-warnings-as-errors`). The build fails if the code is "dirty" or poorly formatted.


4. **Build & Test (Quality Gate 2):**
* **Instrumentation:** Compilation with `-fprofile-arcs -ftest-coverage` flags to allow coverage reading.
* **Execution:** `make unittest` compiles and runs the test binary immediately.
* **Error Handling:** The C++ code was armored against `Floating Point Exceptions` (division by zero), ensuring failure tests are controlled (exception expectation).


5. **Coverage Reports:**
* The `gcovr` utility scans directories for `.gcda` files generated in the previous stage.
* Generates: `coverage.xml` (for machine/plugin reading) and `coverage.html` (for human reading).



## 5. Infrastructure Design (Agents)

The infrastructure follows the **Specialized Agents** model. The Jenkins Controller does not execute builds; it delegates to the `cpp-agent` node.

### The Agent (`cpp-agent`)

A custom Docker image based on Ubuntu 24.04.

**Image Layers:**

1. **Base:** Ubuntu 24.04 (Minimal).
2. **Compilers:** `build-essential`, `cmake`, `g++`.
3. **Quality:** `clang-tidy`, `clang-format`.
4. **Python Runtime:** `python3`, `python3-pip`, `python3-venv` (Essential for the coverage tool).
5. **Connectivity:** `openssh-server` and `jenkins` user configured for secure communication with the Controller.

> **Security Note:** The `jenkins` user inside the container **does not have root/sudo access**. All necessary tools are pre-installed during image build (Dockerfile), eliminating the need to elevate privileges during the pipeline.

## 6. Success Metrics and KPIs

To consider an execution successful, the pipeline validates the following KPIs:

* **Compilation:** 0 Errors.
* **Linting:** 0 Warnings (Strict mode).
* **Unit Tests:** 100% Pass rate (All scenarios, including edge cases like division by zero).
* **Artifacts:** Successful generation of the `coverage.html` report.

## 7. Maintenance Guide (Troubleshooting)

**Scenario: Error 127 (Command not found)**

* **Symptom:** Pipeline fails when trying to run `./bin/unittest`.
* **Cause:** The binary was generated in a subdirectory (`tests/bin`) or has already been cleaned.
* **Resolution:** The pipeline was adjusted to trust the `make unittest` command, which manages paths internally. Do not run binaries manually outside the Makefile context.

**Scenario: Permission Error (sudo)**

* **Symptom:** `sudo: command not found` in the Jenkins log.
* **Cause:** Attempting to install packages during job runtime.
* **Resolution:** Add the necessary package to the agent's `Dockerfile` and rebuild the image. **Do not** use sudo in the Jenkinsfile.

**Approved by:** DevOps Phillips Team
**Date:** December/2025
