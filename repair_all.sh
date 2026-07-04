#!/usr/bin/env bash

GITHUB_USER="jonathan777888"
REPO_NAME="tax-calculator-final-project"
REPO_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"

ICR_REGION="us"
ICR_HOST="us.icr.io"
ICR_NAMESPACE="jonathan-tax-calculator"
IMAGE_NAME="tax-calculator"
IMAGE_TAG="${ICR_HOST}/${ICR_NAMESPACE}/${IMAGE_NAME}:latest"

echo "=== 1. Backup des anciens fichiers ==="
BACKUP_DIR=".backup-before-repair-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

for f in Dockerfile 02-dockerfile package.json index.html script.js style.css taxCalculator.js favicon.ico tasks.yaml pipeline.yaml run.yaml 01-jasmine-tests-passing 03-docker-build-output 04-docker-image 05-docker-icr-push 06-deployed-on-cloud; do
  if [ -e "$f" ]; then
    cp -a "$f" "$BACKUP_DIR/" 2>/dev/null
  fi
done

echo "Backup cree dans: $BACKUP_DIR"

echo "=== 2. Correction du remote GitHub ==="
git remote remove origin 2>/dev/null
git remote add origin "$REPO_URL"
git branch -M main
git remote -v

echo "=== 3. Creation de l'application Tax Calculator ==="

cat > package.json <<'EOF_PACKAGE'
{
  "name": "tax-calculator-final-project",
  "version": "1.0.0",
  "description": "Final project tax calculator with Jasmine, Docker and Tekton",
  "main": "taxCalculator.js",
  "scripts": {
    "test": "jasmine"
  },
  "devDependencies": {
    "jasmine": "^5.1.0"
  }
}
EOF_PACKAGE

cat > taxCalculator.js <<'EOF_TAX'
function calculateTax(income) {
  const amount = Number(income);

  if (Number.isNaN(amount)) {
    throw new Error("Income must be a number");
  }

  if (amount <= 0) {
    return 0;
  }

  if (amount <= 10000) {
    return amount * 0.10;
  }

  if (amount <= 50000) {
    return 1000 + (amount - 10000) * 0.20;
  }

  return 9000 + (amount - 50000) * 0.30;
}

function formatCurrency(value) {
  return "$" + Number(value).toFixed(2);
}

if (typeof module !== "undefined") {
  module.exports = {
    calculateTax,
    formatCurrency
  };
}

if (typeof window !== "undefined") {
  window.calculateTax = calculateTax;
  window.formatCurrency = formatCurrency;
}
EOF_TAX

cat > index.html <<'EOF_HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Tax Calculator</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <main class="container">
    <h1>Tax Calculator</h1>
    <p>Enter your income to calculate estimated tax.</p>

    <label for="income">Income</label>
    <input id="income" type="number" placeholder="Enter income">

    <button id="calculateBtn">Calculate Tax</button>

    <h2 id="result">Tax: $0.00</h2>
  </main>

  <script src="taxCalculator.js"></script>
  <script src="script.js"></script>
</body>
</html>
EOF_HTML

cat > script.js <<'EOF_SCRIPT'
document.addEventListener("DOMContentLoaded", function () {
  const incomeInput = document.getElementById("income");
  const button = document.getElementById("calculateBtn");
  const result = document.getElementById("result");

  button.addEventListener("click", function () {
    try {
      const tax = calculateTax(incomeInput.value);
      result.textContent = "Tax: " + formatCurrency(tax);
    } catch (error) {
      result.textContent = "Error: " + error.message;
    }
  });
});
EOF_SCRIPT

cat > style.css <<'EOF_STYLE'
body {
  font-family: Arial, sans-serif;
  background: #f5f5f5;
  margin: 0;
  padding: 40px;
}

.container {
  max-width: 500px;
  margin: auto;
  background: white;
  padding: 24px;
  border-radius: 12px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
}

input,
button {
  display: block;
  width: 100%;
  padding: 12px;
  margin-top: 12px;
  box-sizing: border-box;
}

button {
  cursor: pointer;
}
EOF_STYLE

touch favicon.ico

mkdir -p spec/support

cat > spec/support/jasmine.mjs <<'EOF_JASMINE_CONFIG'
export default {
  spec_dir: "spec",
  spec_files: [
    "**/*[sS]pec.?(m)js"
  ],
  helpers: [
    "helpers/**/*.?(m)js"
  ],
  env: {
    stopSpecOnExpectationFailure: false,
    random: false,
    forbidDuplicateNames: true
  }
};
EOF_JASMINE_CONFIG

cat > spec/taxCalculatorSpec.js <<'EOF_SPEC'
const { calculateTax, formatCurrency } = require("../taxCalculator");

describe("Tax Calculator", function () {
  it("returns 0 tax for zero income", function () {
    expect(calculateTax(0)).toBe(0);
  });

  it("returns 0 tax for negative income", function () {
    expect(calculateTax(-100)).toBe(0);
  });

  it("calculates 10 percent tax for income up to 10000", function () {
    expect(calculateTax(10000)).toBe(1000);
  });

  it("calculates tax for the second bracket", function () {
    expect(calculateTax(20000)).toBe(3000);
  });

  it("calculates tax at the top of the second bracket", function () {
    expect(calculateTax(50000)).toBe(9000);
  });

  it("calculates tax for income above 50000", function () {
    expect(calculateTax(60000)).toBe(12000);
  });

  it("formats currency correctly", function () {
    expect(formatCurrency(12000)).toBe("$12000.00");
  });
});
EOF_SPEC

echo "=== 4. Creation Dockerfile et 02-dockerfile ==="

cat > Dockerfile <<'EOF_DOCKER'
FROM nginx
COPY favicon.ico /usr/share/nginx/html/favicon.ico
COPY index.html /usr/share/nginx/html/index.html
COPY script.js /usr/share/nginx/html/script.js
COPY style.css /usr/share/nginx/html/style.css
COPY taxCalculator.js /usr/share/nginx/html/taxCalculator.js
EOF_DOCKER

cp Dockerfile 02-dockerfile

echo "=== 5. Question 1: installation npm + tests Jasmine ==="

npm install

echo "npx jasmine" > 01-jasmine-tests-passing
npx jasmine 2>&1 | tee -a 01-jasmine-tests-passing

echo "=== 6. Question 3 et 4: Docker build + docker ps ==="

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo "docker build -t tax-calculator ." > 03-docker-build-output
  docker build -t tax-calculator . 2>&1 | tee -a 03-docker-build-output

  docker rm -f tax-calculator 2>/dev/null
  docker run -d -p 8080:80 --name tax-calculator tax-calculator

  echo "docker ps" > 04-docker-image
  docker ps 2>&1 | tee -a 04-docker-image
else
  echo "Docker n'est pas disponible dans cet environnement." > 03-docker-build-output
  echo "Docker n'est pas disponible dans cet environnement." > 04-docker-image
  echo "Docker non disponible. Fais Q3 et Q4 dans un environnement avec Docker."
fi

echo "=== 7. Creation tasks.yaml pour Question 7 ==="

cat > tasks.yaml <<'EOF_TASKS'
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: npm
spec:
  workspaces:
    - name: source
  steps:
    - name: npm-install
      image: node:18
      workingDir: $(workspaces.source.path)
      script: |
        npm install
---
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: jasmine
spec:
  workspaces:
    - name: source
  steps:
    - name: run-jasmine-tests
      image: node:18
      workingDir: $(workspaces.source.path)
      script: |
        npx jasmine
EOF_TASKS

echo "=== 8. Creation pipeline.yaml pour Question 8 ==="

cat > pipeline.yaml <<'EOF_PIPELINE'
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: tax-calculator-pipeline
spec:
  params:
    - name: repo-url
      type: string
      description: The GitHub repository URL
    - name: revision
      type: string
      description: The Git revision to build
      default: main
    - name: image-reference
      type: string
      description: The image registry path

  workspaces:
    - name: shared-workspace

  tasks:
    - name: clone
      taskRef:
        name: git-clone
        kind: ClusterTask
      workspaces:
        - name: output
          workspace: shared-workspace
      params:
        - name: url
          value: $(params.repo-url)
        - name: revision
          value: $(params.revision)

    - name: npminstall
      runAfter:
        - clone
      taskRef:
        name: npm
      workspaces:
        - name: source
          workspace: shared-workspace

    - name: tests
      runAfter:
        - npminstall
      taskRef:
        name: jasmine
      workspaces:
        - name: source
          workspace: shared-workspace

    - name: build
      runAfter:
        - tests
      taskRef:
        name: buildah
        kind: ClusterTask
      workspaces:
        - name: source
          workspace: shared-workspace
      params:
        - name: IMAGE
          value: $(params.image-reference)
EOF_PIPELINE

echo "=== 9. Creation run.yaml pour Question 9 ==="

cat > run.yaml <<EOF_RUN
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: tax-calculator-pipeline-run
spec:
  pipelineRef:
    name: tax-calculator-pipeline

  params:
    - name: repo-url
      value: https://github.com/${GITHUB_USER}/${REPO_NAME}.git
    - name: revision
      value: main
    - name: image-reference
      value: ${IMAGE_TAG}

  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
EOF_RUN

echo "=== 10. Git add, commit, push ==="

git add .

if git diff --cached --quiet; then
  echo "Aucun changement a committer."
else
  git commit -m "Repair final project files"
fi

git push -u origin main

echo "=== 11. Résumé des réponses à soumettre ==="
echo ""
echo "Q1: copie-colle le contenu de:"
echo "cat 01-jasmine-tests-passing"
echo ""
echo "Q2: copie-colle le contenu de:"
echo "cat 02-dockerfile"
echo ""
echo "Q3: copie-colle le contenu de:"
echo "cat 03-docker-build-output"
echo ""
echo "Q4: copie-colle le contenu de:"
echo "cat 04-docker-image"
echo ""
echo "Q7:"
echo "https://github.com/${GITHUB_USER}/${REPO_NAME}/blob/main/tasks.yaml"
echo ""
echo "Q8:"
echo "https://github.com/${GITHUB_USER}/${REPO_NAME}/blob/main/pipeline.yaml"
echo ""
echo "Q9:"
echo "https://github.com/${GITHUB_USER}/${REPO_NAME}/blob/main/run.yaml"
echo ""
echo "Pour Q5 et Q6, il faut ta connexion IBM Cloud. Lance ensuite:"
echo "ibmcloud login --sso"
echo "ibmcloud target -r us-south"
echo "ibmcloud cr login"
echo "ibmcloud cr namespace-add ${ICR_NAMESPACE}"
echo "docker tag tax-calculator ${IMAGE_TAG}"
echo "echo \"docker push ${IMAGE_TAG}\" > 05-docker-icr-push"
echo "docker push ${IMAGE_TAG} 2>&1 | tee -a 05-docker-icr-push"
echo ""
echo "Puis pour Q6:"
echo "ibmcloud plugin install code-engine"
echo "ibmcloud ce project create --name tax-calculator-project"
echo "ibmcloud ce project select --name tax-calculator-project"
echo "echo \"ibmcloud ce application create --name tax-calculator --image ${IMAGE_TAG} --port 80\" > 06-deployed-on-cloud"
echo "ibmcloud ce application create --name tax-calculator --image ${IMAGE_TAG} --port 80 2>&1 | tee -a 06-deployed-on-cloud"
echo "echo \"ibmcloud ce application get --name tax-calculator\" >> 06-deployed-on-cloud"
echo "ibmcloud ce application get --name tax-calculator 2>&1 | tee -a 06-deployed-on-cloud"
echo ""
echo "Q10: ouvre l'URL de Code Engine et prends une capture nommee 10-final-output.png"
echo ""
echo "=== Fin ==="
